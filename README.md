# Homelab

Infrastructure scripts and configs for the homelab.

## Oracle Cloud

- `provision-oracle-vm.sh` — First-boot provisioning for Oracle VMs (Ubuntu). Creates `muse` and `phunter` users with SSH keys, hardens SSH (key-only), locks the default `ubuntu` user, installs Docker, btop, fail2ban, and enables automatic security updates.

  Usage: `sudo bash provision-oracle-vm.sh`

## Network

- Site-to-site IPSec VPN between home (10.0.0.0/16) and Oracle (10.10.0.0/16)
- Docker Swarm across Oracle ARM + x86 nodes
