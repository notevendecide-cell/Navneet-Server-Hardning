#!/usr/bin/env bash
set -euo pipefail

# Verify Ansible connectivity (pre-apply) and hardening results (post-apply)
# Defaults to localhost; use -i to verify remote hosts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Locate project root by finding site.yml in current dir or parents
ROOT="$SCRIPT_DIR"
if [[ ! -f "$ROOT/site.yml" ]]; then
  PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  if [[ -f "$PARENT_DIR/site.yml" ]]; then
    ROOT="$PARENT_DIR"
  else
    GRANDP_DIR="$(cd "$PARENT_DIR/.." && pwd)"
    if [[ -f "$GRANDP_DIR/site.yml" ]]; then
      ROOT="$GRANDP_DIR"
    fi
  fi
fi
if [[ ! -f "$ROOT/site.yml" ]]; then
  echo "Error: Could not locate site.yml. Tried: $SCRIPT_DIR and its parents." >&2
  exit 1
fi
INV="$ROOT/inventory.ini"

LOCAL=true
PRE=true
POST=true
ASK_SUDO=false
BECOME=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -i, --inventory <path>   Inventory file (switches to remote mode)
  --local                  Verify localhost [default]
  --pre-only               Only run pre-apply verification
  --post-only              Only run post-apply verification
  -b, --become             Use privilege escalation for remote/local checks
  -K                       Ask for become password (implies --become)
  -h, --help               Show this help

Examples:
  $(basename "$0")                    # localhost pre + post checks
  $(basename "$0") --pre-only         # only pre-apply checks (ping, syntax, dry-run)
  $(basename "$0") -i ../inventory.ini -K   # remote checks with sudo prompt
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--inventory) INV="$2"; LOCAL=false; shift 2;;
    --local) LOCAL=true; shift;;
    --pre-only) PRE=true; POST=false; shift;;
    --post-only) PRE=false; POST=true; shift;;
    -b|--become) BECOME=true; shift;;
    -K) ASK_SUDO=true; BECOME=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 2;;
  esac
done

# Build common Ansible args
ANS_ARGS=()
if $LOCAL; then
  ANS_ARGS+=( -i localhost, -c local )
else
  ANS_ARGS+=( -i "$INV" )
fi
$BECOME && ANS_ARGS+=( -b ) || true
$ASK_SUDO && ANS_ARGS+=( -K ) || true

# Helper to run an ansible ad-hoc shell command
arun() {
  local cmd="$1"
  ansible "${ANS_ARGS[@]}" all -m shell -a "$cmd" || true
}

sep() { echo "============================================================"; }

# Basic prereq checks
if ! command -v ansible >/dev/null 2>&1; then
  echo "Error: ansible not found in PATH" >&2; exit 1; fi
if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook not found in PATH" >&2; exit 1; fi

if $PRE; then
  sep; echo "[PRE] Connectivity check (ansible ping)"; sep
  ansible "${ANS_ARGS[@]}" all -m ping

  sep; echo "[PRE] Playbook syntax check"; sep
  ansible-playbook "${ANS_ARGS[@]}" --syntax-check "$ROOT/site.yml"

  sep; echo "[PRE] Dry run (no changes) with AIDE skipped"; sep
  ansible-playbook "${ANS_ARGS[@]}" --check -e skip_aide_init=true "$ROOT/site.yml" || true
fi

if $POST; then
  sep; echo "[POST] SSH hardening"; sep
  arun "grep -E '^(PermitRootLogin|PasswordAuthentication|Port)' /etc/ssh/sshd_config"
  arun "systemctl is-active ssh || systemctl is-active sshd"

  sep; echo "[POST] Firewall"; sep
  arun "ufw status verbose 2>/dev/null | head -n 50 || true"
  arun "firewall-cmd --state 2>/dev/null || true"
  arun "firewall-cmd --list-ports 2>/dev/null || true"

  sep; echo "[POST] Updates"; sep
  arun "systemctl is-enabled unattended-upgrades 2>/dev/null || true"
  arun "systemctl status unattended-upgrades --no-pager 2>/dev/null || true"
  arun "systemctl status ansible-zypper-update.timer --no-pager 2>/dev/null || true"

  sep; echo "[POST] Auditing and logs"; sep
  arun "auditctl -s 2>/dev/null || true"
  arun "grep -E '^(Storage|SystemMaxUse)=' /etc/systemd/journald.conf 2>/dev/null || true"

  sep; echo "[POST] Intrusion prevention (Fail2Ban)"; sep
  arun "systemctl is-active fail2ban 2>/dev/null || true"
  arun "fail2ban-client status sshd 2>/dev/null || true"

  sep; echo "[POST] AppArmor"; sep
  arun "systemctl is-enabled apparmor 2>/dev/null || true"
  arun "aa-status 2>/dev/null || true"

  sep; echo "[POST] Compliance"; sep
  arun "sed -n '1,80p' /var/log/compliance/lynis_last.txt 2>/dev/null || true"
  arun "ls -l /var/log/compliance/openscap_report.html /var/log/compliance/openscap_arf.xml 2>/dev/null || true"

  sep; echo "[POST] File integrity (AIDE)"; sep
  arun "systemctl status aide-check.timer --no-pager 2>/dev/null || true"
  arun "ls -lh /var/lib/aide/aide.db* 2>/dev/null || true"
fi

echo "Verification completed. Review outputs above for any FAILED/unknown states."
