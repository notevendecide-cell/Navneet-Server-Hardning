# Project Overview

## What is Server Hardening?
Server hardening reduces a system's attack surface by disabling unnecessary components, enforcing least privilege, and applying secure configuration baselines (CIS/NIST/STIG).

## How Ansible Automates Hardening
- Declarative YAML tasks define the desired state.
- Idempotent: safe to re-run without unintended changes.
- Distro-aware via facts and `when` conditions.

## Scope
- SSH and account policy hardening
- Service removal and lockdown
- Firewall enablement
- Automated updates
- Logging and auditing
- Basic compliance scan with Lynis

## Compatibility
- Ubuntu 22.04 LTS (Jammy)
- openSUSE Leap (15.x)

## Architecture
- `site.yml` orchestrates roles
- Roles split by domain: `user_access`, `services`, `firewall`, `updates`, `logging`, `compliance`

## Future Scope
- Integrate OpenSCAP scanning and tailoring
- CI/CD: GitHub Actions to lint and test playbooks (ansible-lint, molecule)
- Centralized logging (ELK/OpenSearch, Graylog)
- Dashboarding of audit and compliance scores
- Secrets management (Ansible Vault, HashiCorp Vault)
