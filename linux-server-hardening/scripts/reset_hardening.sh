#!/usr/bin/env bash
set -euo pipefail

# This script attempts to revert/disable common changes applied by the hardening playbook on Ubuntu/SUSE.
# Run as root.

OS_FAMILY="unknown"
if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "${ID_LIKE:-$ID}" in
    *debian*|*ubuntu*) OS_FAMILY="Debian" ;;
    *suse*) OS_FAMILY="Suse" ;;
  esac
fi

echo "Detected OS family: $OS_FAMILY"

# 1) SSH: relax settings (enable password auth, allow root login via password optional)
if [ -f /etc/ssh/sshd_config ]; then
  sed -i -E \
    -e 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' \
    -e 's/^#?PermitRootLogin .*/PermitRootLogin prohibit-password/' \
    -e 's/^#?PermitEmptyPasswords .*/PermitEmptyPasswords no/' \
    -e 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' \
    -e 's/^#?MaxAuthTries .*/MaxAuthTries 6/' \
    -e 's/^#?LoginGraceTime .*/LoginGraceTime 60/' \
    -e 's/^#?ClientAliveInterval .*/ClientAliveInterval 0/' \
    -e 's/^#?ClientAliveCountMax .*/ClientAliveCountMax 3/' \
    -e 's/^#?UsePAM .*/UsePAM yes/' \
    -e 's/^#?X11Forwarding .*/X11Forwarding yes/' \
    -e 's/^#?AllowTcpForwarding .*/AllowTcpForwarding yes/' \
    /etc/ssh/sshd_config || true
  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
fi

# 2) Unlock root account if it was locked
if command -v passwd >/dev/null 2>&1; then
  passwd -u root || true
fi

# 3) Remove sudoers hardening drop-in
rm -f /etc/sudoers.d/99-hardening || true

# 4) Firewall: disable UFW or set firewalld to allow all
if [ "$OS_FAMILY" = "Debian" ]; then
  if command -v ufw >/dev/null 2>&1; then
    ufw disable || true
  fi
elif [ "$OS_FAMILY" = "Suse" ]; then
  if command -v firewall-cmd >/dev/null 2>&1; then
    # open all (not recommended for production, but serves as a reset)
    firewall-cmd --permanent --set-default-zone=trusted || true
    firewall-cmd --reload || true
  fi
fi

# 5) Disable unattended upgrades (Ubuntu) and SUSE zypper timer
if [ "$OS_FAMILY" = "Debian" ]; then
  systemctl disable --now unattended-upgrades.service 2>/dev/null || true
  # Best effort revert of apt periodic
  if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    sed -i -E 's/\"1\"/"0"/g' /etc/apt/apt.conf.d/20auto-upgrades || true
  fi
else
  systemctl disable --now ansible-zypper-update.timer 2>/dev/null || true
  systemctl disable --now ansible-zypper-update.service 2>/dev/null || true
  rm -f /etc/systemd/system/ansible-zypper-update.timer /etc/systemd/system/ansible-zypper-update.service || true
  systemctl daemon-reload || true
fi

# 6) Logging/audit: relax journald and stop auditd
if [ -f /etc/systemd/journald.conf ]; then
  sed -i -E -e 's/^Storage=.*/#Storage=auto/' -e 's/^SystemMaxUse=.*/#SystemMaxUse=/' /etc/systemd/journald.conf || true
  systemctl restart systemd-journald || true
fi
systemctl disable --now auditd 2>/dev/null || true

# 7) Fail2Ban: disable
systemctl disable --now fail2ban 2>/dev/null || true

# 8) AppArmor: disable service (not recommended for prod)
systemctl disable --now apparmor 2>/dev/null || true

# 9) AIDE: disable timer and remove DB (optional cleanup)
systemctl disable --now aide-check.timer 2>/dev/null || true
rm -f /var/lib/aide/aide.db* 2>/dev/null || true

# 10) Compliance output cleanup (optional)
rm -f /var/log/compliance/lynis_last.txt /var/log/compliance/openscap_* 2>/dev/null || true

# 11) Re-enable previously masked services (best effort)
for svc in telnet rsh rlogin tftp xinetd avahi-daemon cups vsftpd; do
  systemctl unmask "$svc" 2>/dev/null || true
  systemctl disable "$svc" 2>/dev/null || true
  systemctl stop "$svc" 2>/dev/null || true
done

echo "Reset complete (best effort). Some changes may require manual review."
