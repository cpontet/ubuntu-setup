#!/usr/bin/env bash
#
# spoof-ubuntu.sh — Temporarily make ZorinOS identify as Ubuntu 24.04 LTS
#
# Usage:
#   sudo ./spoof-ubuntu.sh spoof     # Back up originals and impersonate Ubuntu 24.04
#   sudo ./spoof-ubuntu.sh restore   # Restore the original Zorin identification
#   sudo ./spoof-ubuntu.sh status    # Show current state
#
# Why: Some vendor installers (Microsoft Intune Portal, ESET EPI, etc.) refuse
# to run on Zorin even though Zorin 17/18 is built on Ubuntu 22.04/24.04 and is
# fully ABI-compatible. This script swaps /etc/os-release and /etc/lsb-release
# so those installers see "Ubuntu 24.04". Revert afterwards so system tools
# (updates, PPAs, Zorin-specific utilities) continue to work correctly.

set -euo pipefail

BACKUP_DIR="/var/backups/distro-spoof"
OS_RELEASE="/etc/os-release"
LSB_RELEASE="/etc/lsb-release"
ISSUE="/etc/issue"
ISSUE_NET="/etc/issue.net"
MARKER="${BACKUP_DIR}/.spoofed"

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: this script must be run as root (use sudo)." >&2
        exit 1
    fi
}

backup_file() {
    local src="$1"
    if [[ -e "$src" && ! -e "${BACKUP_DIR}/$(basename "$src").orig" ]]; then
        cp -a "$src" "${BACKUP_DIR}/$(basename "$src").orig"
    fi
}

restore_file() {
    local src="$1"
    local backup="${BACKUP_DIR}/$(basename "$src").orig"
    if [[ -e "$backup" ]]; then
        cp -a "$backup" "$src"
        rm -f "$backup"
    fi
}

do_spoof() {
    require_root

    if [[ -e "$MARKER" ]]; then
        echo "Already spoofed (marker: $MARKER). Run '$0 restore' first if you want to re-spoof."
        exit 0
    fi

    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"

    echo ">> Backing up original distro identification files to $BACKUP_DIR"
    backup_file "$OS_RELEASE"
    backup_file "$LSB_RELEASE"
    backup_file "$ISSUE"
    backup_file "$ISSUE_NET"

    echo ">> Writing Ubuntu 24.04 LTS identity to $OS_RELEASE"
    cat > "$OS_RELEASE" <<'EOF'
PRETTY_NAME="Ubuntu 24.04.1 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.1 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo
EOF

    echo ">> Writing Ubuntu 24.04 LTS identity to $LSB_RELEASE"
    cat > "$LSB_RELEASE" <<'EOF'
DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=24.04
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="Ubuntu 24.04.1 LTS"
EOF

    # /etc/issue is less commonly checked, but some installers grep it.
    echo ">> Updating $ISSUE and $ISSUE_NET"
    echo 'Ubuntu 24.04.1 LTS \n \l' > "$ISSUE"
    echo 'Ubuntu 24.04.1 LTS'       > "$ISSUE_NET"

    # Record what we did and when.
    date -Iseconds > "$MARKER"

    echo
    echo "Done. System now identifies as Ubuntu 24.04 LTS."
    echo "Run your installer now, then revert with:  sudo $0 restore"
    echo
    echo "Sanity check:"
    lsb_release -a 2>/dev/null || true
}

do_restore() {
    require_root

    if [[ ! -e "$MARKER" ]]; then
        echo "No spoof marker found at $MARKER."
        echo "Either the system was never spoofed with this script, or restore already ran."
        # Still try a best-effort restore if backups exist.
    fi

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "Error: backup directory $BACKUP_DIR does not exist. Cannot restore." >&2
        exit 1
    fi

    echo ">> Restoring original distro identification files from $BACKUP_DIR"
    restore_file "$OS_RELEASE"
    restore_file "$LSB_RELEASE"
    restore_file "$ISSUE"
    restore_file "$ISSUE_NET"

    rm -f "$MARKER"
    # Leave the empty backup dir in place; harmless, and useful as an audit trail.

    echo
    echo "Restore complete. System now reports its real identity again."
    echo
    echo "Sanity check:"
    lsb_release -a 2>/dev/null || true
}

do_status() {
    echo "Spoof marker: $([[ -e "$MARKER" ]] && cat "$MARKER" || echo "not present (not spoofed)")"
    echo
    echo "---- /etc/os-release ----"
    grep -E '^(NAME|PRETTY_NAME|VERSION_ID|ID)=' "$OS_RELEASE" 2>/dev/null || echo "(missing)"
    echo
    echo "---- /etc/lsb-release ----"
    cat "$LSB_RELEASE" 2>/dev/null || echo "(missing)"
    echo
    echo "---- lsb_release -a ----"
    lsb_release -a 2>/dev/null || echo "(lsb_release not installed)"
}

usage() {
    sed -n '2,12p' "$0"
    exit 1
}

case "${1:-}" in
    spoof)   do_spoof ;;
    restore) do_restore ;;
    status)  do_status ;;
    *)       usage ;;
esac
