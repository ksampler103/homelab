#!/bin/bash
# Oracle VM provisioning script - run as root on first boot
# Usage: sudo bash provision.sh
set -e

MUSE_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF4vlTv0xPzNLxo+jMM0+TZf9IZYTSVyeD6VbJ5csSyf muse@prestonhunter.space"
# Add Preston's keys below (one per line)
PHUNTER_KEYS="
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwIVtw02gyO/yguGEmOZIatj9faUxBf6ro1DaLmrdrA/Qc8iUjDC4/bpvkg6/d6VSXJ8WQVKfcZ3mLzU7erI0Rl37lKPhBU8e6zIiKySYj9nZTjAHV9dFhgBieuT2pW8SjT2Uqc3VMaNnk4dXDqxLxjiIvLDFYNvxDDTTGTa4J/64d16YVahqkHcAHatydbhoKeUR/Cm+6FGTrUT5Wa+PZnmURCfH9ZfrucuB9uILrxByb8hmitdknADob0bil3S5vm9toiZCYQJNMAMFnnqK4nuztAeArSyGEqg+LHmMEZpwvIbPItWFz9O60BwmcRXfMvk2n3qyTh58PVzOzxQV/ imported-openssh-key
"

echo "=== Updating system ==="
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

echo "=== Installing essentials ==="
apt-get install -y -qq btop fail2ban unattended-upgrades curl wget git ca-certificates gnupg lsb-release

echo "=== Installing Docker ==="
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker

echo "=== Creating muse user ==="
id muse &>/dev/null || useradd -m -s /bin/bash -G docker,sudo muse
mkdir -p /home/muse/.ssh
echo "$MUSE_KEY" > /home/muse/.ssh/authorized_keys
chmod 700 /home/muse/.ssh
chmod 600 /home/muse/.ssh/authorized_keys
chown -R muse:muse /home/muse/.ssh
# Passwordless sudo (key-only SSH, matches existing fleet)
echo "muse ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/muse
chmod 440 /etc/sudoers.d/muse

echo "=== Creating phunter user ==="
id phunter &>/dev/null || useradd -m -s /bin/bash -G docker,sudo phunter
mkdir -p /home/phunter/.ssh
echo "$PHUNTER_KEYS" | grep -v "PASTE_PHUNTER" > /home/phunter/.ssh/authorized_keys
chmod 700 /home/phunter/.ssh
chmod 600 /home/phunter/.ssh/authorized_keys
chown -R phunter:phunter /home/phunter/.ssh
echo "phunter ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/phunter
chmod 440 /etc/sudoers.d/phunter

echo "=== Hardening SSH ==="
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
# Ensure PasswordAuthentication is set even if not present
grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
systemctl restart sshd

echo "=== Locking ubuntu user ==="
# Lock password and expire account (safer than delete, preserves file ownership)
passwd -l ubuntu 2>/dev/null || true
usermod --expiredate 1 ubuntu 2>/dev/null || true
# Remove from sudo
deluser ubuntu sudo 2>/dev/null || true

echo "=== Configuring auto security updates ==="
cat > /etc/apt/apt.conf.d/50unattended-upgrades-custom << 'EOF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
EOF
systemctl enable --now unattended-upgrades

echo "=== Configuring fail2ban ==="
systemctl enable --now fail2ban

echo "=== Done ==="
echo "Users: muse, phunter (both with docker+sudo, key-only SSH)"
echo "Docker: $(docker --version)"
echo "Ubuntu user locked. Password auth disabled."
