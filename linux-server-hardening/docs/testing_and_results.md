# Testing and Results

## Commands to Test

- Connectivity:
```bash
ansible -i inventory.ini all -m ping
```

- Dry run (no changes):
```bash
ansible-playbook -i inventory.ini site.yml --check -K
```

- Apply changes:
```bash
ansible-playbook -i inventory.ini site.yml -K
```

## Expected Results

- SSH: root login disabled, password auth disabled if configured
- Password policy enforced via `pwquality`
- Insecure services removed and masked
- Firewall enabled with only required ports open
- Automatic updates configured
- Auditd running; journald persistent; logrotate entries present
- Lynis audit report saved

## Example Output Snippets

- `ufw status` (Ubuntu):
```
Status: active
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
```

- `firewall-cmd --list-ports` (SUSE):
```
22/tcp
```

- `systemctl status ansible-zypper-update.timer` (SUSE):
```
Active: active (waiting)
Triggers: ansible-zypper-update.service
```
