# Linux Server Hardening with Ansible

Harden Ubuntu 22.04 and openSUSE Leap servers using Ansible playbooks aligned with CIS/NIST/STIG-inspired best practices. This project configures SSH, password policies, removes insecure services, enables firewalls, automates updates, and configures auditing and logging.

## Features

- SSH hardening and root login disabled
- Password complexity via `pwquality`
- Remove/disable insecure legacy services
- Host firewall (UFW on Ubuntu, firewalld on SUSE)
- Automatic updates (unattended-upgrades / zypper timer)
- Logging: auditd, journald persistence, logrotate
- Compliance check with Lynis

## Quick Start

- Install Ansible on the control node:
  ```bash
  python3 -m venv .venv && . .venv/bin/activate
  pip install -r requirements.txt
  ```
- Define your hosts in `inventory.ini`.
- Run the playbook:
  ```bash
  ansible-playbook -i inventory.ini site.yml -K -e skip_aide_init=true
  ```

> Tip: Use `-l ubuntu` or `-l opensuse` to target a group.

## Verification

- SSH root login: `sshd_config` shows `PermitRootLogin no`
- Password policy: `/etc/security/pwquality.conf` values set
- Firewall:
  - Ubuntu: `sudo ufw status`
  - SUSE: `sudo firewall-cmd --list-ports`
- Updates:
  - Ubuntu: check `/var/log/unattended-upgrades/unattended-upgrades.log`
  - SUSE: `systemctl status ansible-zypper-update.timer`
- Audit: `sudo auditctl -s`, logs in `/var/log/audit/`
- Compliance: report at `/var/log/compliance/lynis_last.txt`

## Educational Notes

- Config aims to be safe defaults; further tuning recommended per environment and benchmark level.
- Review handlers and `when` conditions for distro-specific behavior.

## Project Structure

```
linux-server-hardening/
├── ansible.cfg
├── inventory.ini
├── site.yml
├── roles/
│   ├── user_access/
│   │   ├── tasks/main.yml
│   │   └── handlers/main.yml
│   ├── services/
│   │   └── tasks/main.yml
│   ├── firewall/
│   │   └── tasks/main.yml
│   ├── updates/
│   │   └── tasks/main.yml
│   ├── logging/
│   │   ├── tasks/main.yml
│   │   └── handlers/main.yml
│   └── compliance/
│       └── tasks/main.yml
├── README.md
└── docs/
    ├── project_overview.md
    ├── setup_guide.md
    └── testing_and_results.md
```

## Requirements

- Controller: Linux with Python 3.9+
- Ansible: `ansible>=9`, `ansible-core>=2.16` (see `requirements.txt`)
- SSH access to targets with sudo privileges

## Compatibility

- Ubuntu 22.04 LTS (Jammy)
- openSUSE Leap (15.x)

## Setup (Controller)

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

If you see a locale error, set UTF-8:
```bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
```

## Inventory Examples

Edit `inventory.ini` and add your hosts:

```ini
[ubuntu]
ubuntu-host ansible_host=192.0.2.10 ansible_user=ansible

[opensuse]
suse-host ansible_host=192.0.2.20 ansible_user=ansible

[all:vars]
ansible_python_interpreter=auto_silent
# ansible_ssh_private_key_file=~/.ssh/id_rsa
```

Validate:
```bash
ansible-inventory -i inventory.ini --list --yaml
ansible -i inventory.ini all -m ping
```

## Run Modes

- Localhost (quick demo, no SSH needed):
  ```bash
  ansible -i 'localhost,' localhost -c local -m ping
  ansible-playbook -i 'localhost,' -c local site.yml --check   # dry run
  ansible-playbook -i 'localhost,' -c local site.yml -e skip_aide_init=true   # apply (skip AIDE init)
  ```

  Note: Skipping AIDE initialization can significantly speed up the run time, but it may not provide the full security benefits.

- Remote hosts (recommended):
  ```bash
  ansible -i inventory.ini all -m ping
  ansible-playbook -i inventory.ini site.yml --check -K
  ansible-playbook -i inventory.ini site.yml -K -e skip_aide_init=true
  ```
  If there is no `ansible` user on targets, use your user: `-u <user>` and supply sudo with `-K`.

## Variables

- `allowed_ssh_ports`: list, default `[22]`
- `extra_allowed_ports`: list of extra open ports, default `[]`
- `disable_password_authentication`: bool, default `true`
- `lock_root_account`: bool, default `true`

Override at runtime, for example:
```bash
ansible-playbook -i inventory.ini site.yml -K -e 'extra_allowed_ports=[80,443]'
```

## Role Details

- **user_access**
  - Install OpenSSH, harden `/etc/ssh/sshd_config` (`PermitRootLogin no`, `PasswordAuthentication no` by default)
  - Enforce password policy in `/etc/security/pwquality.conf`
  - Lock root account (password) and harden sudoers with logging

- **services**
  - Remove insecure packages (telnet, rsh, tftp, xinetd, ftp, etc.)
  - Stop/disable/mask legacy services if present

- **firewall**
  - Ubuntu: `ufw` enabled, allow 22 and `extra_allowed_ports`, deny incoming by default
  - openSUSE: `firewalld` with required ports, default zone set to drop

- **updates**
  - Ubuntu: unattended-upgrades and periodic APT
  - openSUSE: systemd timer to run `zypper patch` daily

- **logging**
  - Ensure `auditd` is installed and configured; `journald` persistent storage; `logrotate` rules

- **compliance**
  - Install and run Lynis, save report to `/var/log/compliance/lynis_last.txt`

## Safety & Notes

- Firewall: avoid lockouts. If you need HTTP/HTTPS, set `extra_allowed_ports=[80,443]` before applying.
- Check mode: some tasks (service restarts, Lynis) are skipped during `--check` to prevent false failures.
- Idempotent: re-running will not produce unintended changes.

## Testing & Verification

Connectivity:
```bash
ansible -i inventory.ini all -m ping
```

Dry run and apply:
```bash
ansible-playbook -i inventory.ini site.yml --check -K
ansible-playbook -i inventory.ini site.yml -K
```

Post-apply checks:
- SSH: `grep -E '^(PermitRootLogin|PasswordAuthentication|Port)' /etc/ssh/sshd_config`
- Ubuntu firewall: `sudo ufw status verbose`
- SUSE firewall: `sudo firewall-cmd --list-ports`
- Updates: Ubuntu log at `/var/log/unattended-upgrades/`; SUSE timer `systemctl status ansible-zypper-update.timer`
- Auditd: `sudo auditctl -s`
- Compliance: `sudo sed -n '1,80p' /var/log/compliance/lynis_last.txt`

## Troubleshooting

- Locale error (UTF-8 required):
  ```bash
  export LC_ALL=C.UTF-8; export LANG=C.UTF-8
  ```
- Empty inventory warning: add hosts to `inventory.ini` or use `-i 'localhost,' -c local`.
- Sudo prompt: add `-K` when running as non-root; omit `-K` when running as root.
- Service not found during `--check`: expected; services start only in real apply.

## Expected Results

- Root SSH login disabled, password auth disabled (configurable)
- Password policy enforced via `pwquality`
- Insecure services removed/masked
- Firewall enabled with only required ports open
- Automatic updates configured
- `auditd` running, `journald` persistent, logrotate in place
- Lynis report saved for review

## Commands used in this session

- Connectivity attempt with inventory file:
  ```bash
  ansible -i inventory.ini all -m ping
  ```

- Localhost test (no SSH):
  ```bash
  ansible -i 'localhost,' all -c local -m ping
  ```

- Dry runs of the playbook on localhost:
  ```bash
  ansible-playbook -i 'localhost,' -c local site.yml --check -K
  ansible-playbook -i 'localhost,' -c local site.yml --check
  ```

- Verification commands after applying hardening:
  ```bash
  grep -E '^(PermitRootLogin|PasswordAuthentication|Port)' /etc/ssh/sshd_config
  systemctl status ssh --no-pager
  ufw status verbose
  tail -n 50 /var/log/unattended-upgrades/unattended-upgrades.log
  auditctl -s
  sed -n '1,80p' /var/log/compliance/lynis_last.txt
  ```

## Future Scope

- Add OpenSCAP scanning and tailoring
- CI/CD with GitHub Actions (ansible-lint, molecule)
- Centralized logging dashboards (ELK/OpenSearch/Graylog)
- Secrets management (Ansible Vault, HashiCorp Vault)

## License

MIT
