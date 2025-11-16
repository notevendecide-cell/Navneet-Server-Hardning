#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Locate project root: directory that contains site.yml (check current dir and parents)
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
CHECK=false
ASK_SUDO=false
SKIP_AIDE=true
EXTRA_PORTS=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -i, --inventory <path>   Inventory file (switches to remote mode)
  --local                  Run on localhost (no SSH) [default]
  --check                  Dry run (no changes)
  -K                       Ask for sudo/become password
  --include-aide           Do NOT skip AIDE initialization (may take long)
  --extra-ports "80,443"   Comma-separated extra ports to allow in firewall
  -h, --help               Show this help

Examples:
  $(basename "$0")                                # apply on localhost, skip AIDE (default)
  $(basename "$0") -i inventory.ini -K            # apply on inventory hosts with sudo, skip AIDE
  $(basename "$0") --local --check               # dry run on localhost
  $(basename "$0") --local --extra-ports "80,443"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--inventory) INV="$2"; LOCAL=false; shift 2;;
    --local) LOCAL=true; shift;;
    --check) CHECK=true; shift;;
    -K) ASK_SUDO=true; shift;;
    --include-aide) SKIP_AIDE=false; shift;;
    --extra-ports) EXTRA_PORTS="$2"; shift 2;;
    --extra-ports=*) EXTRA_PORTS="${1#*=}"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 2;;
  esac
done

EXTRA_ARGS=()
if $LOCAL; then
  EXTRA_ARGS+=( -i localhost, -c local )
else
  EXTRA_ARGS+=( -i "$INV" )
fi

$CHECK && EXTRA_ARGS+=( --check ) || true
$ASK_SUDO && EXTRA_ARGS+=( -K ) || true

if $SKIP_AIDE; then
  EXTRA_ARGS+=( -e skip_aide_init=true )
fi

if [[ -n "$EXTRA_PORTS" ]]; then
  # Convert e.g. "80,443" to [80,443]
  ports_list="[$EXTRA_PORTS]"
  EXTRA_ARGS+=( -e "extra_allowed_ports=${ports_list}" )
fi

cmd=( ansible-playbook "${EXTRA_ARGS[@]}" "$ROOT/site.yml" )
echo "Running: ${cmd[*]}"
"${cmd[@]}"
