#!/bin/bash
# Script:  image_and_hash.sh
# Purpose: Create disk image with ddrescue and generate hashes
# Usage:   sudo ./image_and_hash.sh /dev/sdX DRV-XX
# Notes:   Uses software write-blocking  blockdev --setro
#          TODO: add hardware write blocker for better integrity IE THERE IS NO WAY I CAN WRITE.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Usage
usage() {
    echo "Usage: $0 /dev/sdX DRV-XX" >&2
    echo >&2
    echo "Arguments:" >&2
    echo "  /dev/sdX   Block device to image" >&2
    echo "  DRV-XX     Name for the output image (e.g., DRV-01)" >&2
    echo >&2
    echo "Environment variables:" >&2
    echo "  POS_IMG_DIR   Destination directory (default: /media/neuro/data/POS-IMAGES)" >&2
    echo "  POS_TEMP_DIR  Temp directory for imaging (default: /tmp/pos-temp)" >&2
    exit 1
}

# Main
main() {
    local device="${1:-}"
    local name="${2:-}"

    [[ $# -ne 2 ]] && usage

    require_root "$device $name"
    require_block_device "$device"
    require_command ddrescue gddrescue
    require_command pv pv

    ensure_dirs

    local temp_img="$POS_TEMP_DIR/$name.img"
    local temp_log="$POS_TEMP_DIR/$name.log"
    local dest_img="$POS_IMG_DIR/$name.img"
    local dest_sha="$POS_IMG_DIR/$name.img.sha256"
    local dest_md5="$POS_IMG_DIR/$name.img.md5"
    local dest_log="$POS_IMG_DIR/$name.log"

    # rm all the tmp files on exit
    register_cleanup "rm -f '$temp_img, $temp_log'"

    # Software write-blocking
    log_info "Setting $device read-only"
    blockdev --setro "$device"

    # Image the device
    log_info "Imaging $device -> $temp_img"
    ddrescue -n "$device" "$temp_img" "$temp_log"

    # Optional: retry pass for bad sectors
    # ddrescue -r3 "$device" "$temp_img" "$temp_log"

    # Copy to destination while computing hashes
    log_info "Copying to $POS_IMG_DIR and computing hashes..."
    pv "$temp_img" | tee \
        >(sha256sum | sed "s| -$|  $name.img|" > "$dest_sha") \
        >(md5sum    | sed "s| -$|  $name.img|" > "$dest_md5") \
        > "$dest_img"

    # Verify the hashes
    log_info "Verifying SHA256..."
    (cd "$POS_IMG_DIR" && sha256sum -c "$name.img.sha256")

    # Move log file
    log_info "Moving ddrescue log..."
    mv "$temp_log" "$dest_log"

    # Cleanup temp image
    log_info "Cleaning up temp image..."
    rm -f "$temp_img"

    log_ok "Completed: $name"
    echo
    echo "Hashes:"
    cat "$dest_sha"
    cat "$dest_md5"
}

main "$@"
