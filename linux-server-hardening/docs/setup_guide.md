# Setup Guide

## Prerequisites
- Control node with Python 3.9+
- Ansible 2.15+
- SSH access to target hosts with sudo privileges

## Install Ansible
```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

## Configure Inventory
Edit `inventory.ini`:
```ini
[ubuntu]
ubuntu-host ansible_host=192.0.2.10 ansible_user=ansible

[opensuse]
suse-host ansible_host=192.0.2.20 ansible_user=ansible
```

Optional: set `ansible_ssh_private_key_file` in `[all:vars]`.

## Run the Playbook
```bash
ansible-playbook -i inventory.ini site.yml -K
```

- `-K` prompts for sudo password if needed.
- Limit to a group: `-l ubuntu`.

## Variables
- `allowed_ssh_ports` (list): defaults to `[22]`
- `extra_allowed_ports` (list): additional allowed ports
- `disable_password_authentication` (bool): defaults to `true`
- `lock_root_account` (bool): defaults to `true`

## Testing Locally with VMs
- Create two VMs (Ubuntu 22.04, openSUSE Leap)
- Ensure network reachability and SSH keys
- Add to `inventory.ini`
- Run `ansible -m ping all -i inventory.ini`

## Verification Steps
- SSH hardening: `grep -E 'PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config`
- Firewall:
  - Ubuntu: `sudo ufw status verbose`
  - SUSE: `sudo firewall-cmd --list-all`
- Updates: Ubuntu logs in `/var/log/unattended-upgrades/`
- Auditd: `sudo auditctl -s`
- Lynis report: `/var/log/compliance/lynis_last.txt`
