#!/bin/bash
# Script:  triage_image.sh
# Purpose: Generate quick triage report for disk images
# Usage:   ./triage_image.sh image1.img [image2.img ...]
# Output:  Creates .triage.txt file alongside each image

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Usage
usage() {
    echo "Usage: $0 image1.img [image2.img ...]" >&2
    echo >&2
    echo "Generates a triage report for each disk image containing:" >&2
    echo "  - Basic file info (size, type, partitions)" >&2
    echo "  - Hex samples from various offsets" >&2
    echo "  - String samples" >&2
    echo "  - Filesystem signature detection" >&2
    echo "  - Entropy analysis (if 'ent' is installed)" >&2
    exit 1
}

# Check optional tools
HAVE_ENT=false
HAVE_BLKID=false
HAVE_FDISK=false

check_optional_tools() {
    check_command ent && HAVE_ENT=true
    check_command blkid && HAVE_BLKID=true
    check_command fdisk && HAVE_FDISK=true
}

# Triage one image
triage_one() {
    local img="$1"
    local base triage

    base=$(basename "$img")
    triage="${img%.img}.triage.txt"

    {
        echo "============================================================"
        echo " Triage report for: $img"
        echo " Generated: $(date -Iseconds)"
        echo "============================================================"
        echo

        # Section 1: Basic info
        echo "## 1. Basic info"
        echo
        echo "Path:    $img"
        echo "Size:    $(stat -c '%s bytes (%h hardlinks)' "$img" 2>/dev/null || stat -f '%z bytes' "$img")"
        echo

        echo "### 1.1 file(1)"
        file "$img" || echo "(file command failed)"
        echo

        echo "### 1.2 blkid"
        if $HAVE_BLKID; then
            sudo blkid "$img" 2>/dev/null || echo "(no filesystem info)"
        else
            echo "(blkid not installed)"
        fi
        echo

        echo "### 1.3 fdisk -l"
        if $HAVE_FDISK; then
            sudo fdisk -l "$img" 2>/dev/null || echo "(fdisk failed)"
        else
            echo "(fdisk not installed)"
        fi
        echo

        # Section 2: Hex samples
        echo "## 2. Hex samples"
        echo

        echo "### 2.1 Sector 0 (first 512 bytes)"
        hexdump -C -n 512 "$img" | head
        echo

        echo "### 2.2 1 MiB in"
        dd if="$img" bs=1M skip=1 count=1 2>/dev/null | hexdump -C | head
        echo

        echo "### 2.3 1 GiB in (if available)"
        dd if="$img" bs=1M skip=1024 count=1 2>/dev/null | hexdump -C | head || \
            echo "(offset beyond EOF)"
        echo

        # Section 3: Strings
        echo "## 3. Strings (quick sample)"
        echo
        echo "### 3.1 strings from first 16 MiB"
        dd if="$img" bs=1M count=16 2>/dev/null | strings | head -n 40 || \
            echo "(strings extraction failed)"
        echo

        # Section 4: Filesystem signatures
        echo "## 4. Filesystem signatures (first 2 GiB)"
        echo

        echo "### 4.1 NTFS signature"
        dd if="$img" bs=1M count=2048 2>/dev/null | \
            grep -aob "NTFS    " | head -n 10 || \
            echo "No NTFS signature found."
        echo

        echo "### 4.2 FAT32 signature"
        dd if="$img" bs=1M count=2048 2>/dev/null | \
            grep -aob "FAT32   " | head -n 10 || \
            echo "No FAT32 signature found."
        echo

        echo "### 4.3 ext signature"
        dd if="$img" bs=1M count=2048 2>/dev/null | \
            grep -aob $'\x53\xef' | head -n 10 || \
            echo "No ext2/3/4 signature found."
        echo

        # Section 5: Entropy
        echo "## 5. Entropy (optional)"
        echo
        if $HAVE_ENT; then
            echo "### 5.1 First 1 MiB"
            dd if="$img" bs=1M count=1 2>/dev/null | ent || echo "(ent failed)"
            echo
            echo "### 5.2 Sample at 1 GiB (if available)"
            dd if="$img" bs=1M skip=1024 count=1 2>/dev/null | ent || echo "(beyond EOF or ent failed)"
        else
            echo "(ent not installed; skipping entropy analysis)"
        fi
        echo

        # Section 6: Manual notes
        echo "## 6. Notes / classification (fill manually) and add to obsidian"
        echo
        echo "- Observations:"
        echo "  -"
        echo "- Likely class:"
        echo "    A = Normal filesystem"
        echo "    B = Broken partition table"
        echo "    C = Wiped/encrypted (high entropy)"
        echo "    D = Physically damaged"
        echo "  -"
        echo

    } | tee "$triage"

    log_ok "Wrote triage report: $triage"
}

main() {
    [[ $# -lt 1 ]] && usage

    # the second element is the package that has the
    # tool
    require_command hexdump "bsdmainutils or util-linux"

    check_optional_tools

    local img
    for img in "$@"; do
        if [[ ! -f "$img" ]]; then
            log_warn "Skipping $img (not a file)"
            continue
        fi
        triage_one "$img"
    done
}

main "$@"
