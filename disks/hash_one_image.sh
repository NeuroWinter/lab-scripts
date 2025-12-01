#!/bin/bash
# ----------------------------------------------------------------------
# Script:  hash_one_image.sh
# Purpose: Generate SHA256 and MD5 hashes for an existing disk image
# Usage:   ./hash_one_image.sh /path/to/image.img [--force]
# ----------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Usage
usage() {
    echo "Usage: $0 /path/to/image.img [--force]" >&2
    echo >&2
    echo "Arguments:" >&2
    echo "  /path/to/image.img   Path to disk image file" >&2
    echo >&2
    echo "Options:" >&2
    echo "  --force, -f          Regenerate hashes even if they exist" >&2
    exit 1
}

main() {
    local img=""
    local force=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                force=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                if [[ -z "$img" ]]; then
                    img="$1"
                else
                    die "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done

    [[ -z "$img" ]] && usage

    require_file "$img"
    require_command pv pv

    local dir base name sha_file md5_file
    dir=$(dirname "$img")
    base=$(basename "$img")
    name=${base%.img}

    sha_file="$dir/$name.img.sha256"
    md5_file="$dir/$name.img.md5"

    # Skip if hashes already exist (unless forced)
    if [[ "$force" != true && -f "$sha_file" && -f "$md5_file" ]]; then
        log_info "Skipping $base (hashes already exist, use --force to regenerate)"
        exit 0
    fi

    if [[ "$force" == true && -f "$sha_file" ]]; then
        log_info "Regenerating hashes for $base..."
    else
        log_info "Hashing $base..."
    fi

    pv "$img" | tee \
        >(sha256sum | sed "s| -$|  $base|" > "$sha_file") \
        >(md5sum    | sed "s| -$|  $base|" > "$md5_file") \
        > /dev/null

    log_ok "Completed: $base"
    echo
    echo "Hashes:"
    cat "$sha_file"
    cat "$md5_file"
}

main "$@"
