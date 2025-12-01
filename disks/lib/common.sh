#!/bin/bash
# ----------------------------------------------------------------------
# Library: common.sh
# Purpose: Shared functions and configuration for POS disk forensics
# how to use in scripts:  source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# ----------------------------------------------------------------------

# Exit immediately on error, undefined vars, and pipe failures
# Any script that imports this will also have this set.
set -euo pipefail

# Configuration (override via environment variables)
: "${POS_IMG_DIR:=/media/neuro/data/POS-IMAGES}"
: "${POS_MNT_BASE:=/mnt/pos-images}"
: "${POS_STATE_DIR:=/run/pos-images}"
: "${POS_TEMP_DIR:=/tmp/pos-temp}"

# Logging functions
# This just makes life easier to get the same style of messages
log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_ok()    { echo "[OK]    $*"; }

# Just go and die and error.
die() {
    log_error "$*"
    exit 1
}

# Validation helpers
require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        die "Please run as root, e.g.: sudo $0 $*"
    fi
}

# Make sure that thsi command is available
require_command() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "$cmd not found (usually in $pkg)"
    fi
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Make sure this file is there.
require_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        die "File not found: $path"
    fi
}

require_block_device() {
    local dev="$1"
    if [[ ! -b "$dev" ]]; then
        die "$dev is not a block device"
    fi
}

# Cleanup handling
# Usage: register_cleanup "command to run"
# Multiple calls append to cleanup list
CLEANUP_COMMANDS=()

_run_cleanup() {
    local i
    for ((i=${#CLEANUP_COMMANDS[@]}-1; i>=0; i--)); do
        eval "${CLEANUP_COMMANDS[i]}" || true
    done
}

register_cleanup() {
    CLEANUP_COMMANDS+=("$1")
    trap _run_cleanup EXIT INT TERM
}

# Ensure directories exist
ensure_dirs() {
    mkdir -p "$POS_IMG_DIR" "$POS_MNT_BASE" "$POS_STATE_DIR" "$POS_TEMP_DIR"
}
