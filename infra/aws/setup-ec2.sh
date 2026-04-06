#!/bin/bash
# FitnessAI — EC2 instance setup script
# Run on a fresh Ubuntu 24.04 LTS EC2 instance (t3.small recommended)
#
# Usage: curl -sSL https://raw.githubusercontent.com/.../setup-ec2.sh | bash
# Or:    scp setup-ec2.sh ubuntu@<IP>:~ && ssh ubuntu@<IP> ./setup-ec2.sh

set -euo pipefail

echo "=== FitnessAI EC2 Setup ==="

# 1. System updates
echo "[1/7] Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# 2. Install Docker
echo "[2/7] Installing Docker..."
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
sudo systemctl enable docker
sudo systemctl start docker

# 3. Install Docker Compose plugin
echo "[3/7] Installing Docker Compose..."
sudo apt-get install -y docker-compose-plugin

# 4. Install AWS CLI (for S3 backups)
echo "[4/7] Installing AWS CLI..."
sudo apt-get install -y awscli

# 5. Create application directory
echo "[5/7] Creating application directory..."
sudo mkdir -p /opt/fitnessai
sudo chown ubuntu:ubuntu /opt/fitnessai

# 6. Configure swap (t3.small has 2GB RAM)
echo "[6/7] Configuring swap (2GB)..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# 7. Configure firewall
echo "[7/7] Configuring firewall..."
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP (redirect to HTTPS)
sudo ufw allow 443/tcp  # HTTPS
sudo ufw --force enable

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Clone the repository to /opt/fitnessai"
echo "  2. Copy .env with production values"
echo "  3. Run: cd /opt/fitnessai && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d"
echo "  4. Setup backup cron: sudo cp infra/aws/backup-db.sh /etc/cron.daily/"
echo "  5. Configure CloudWatch agent (optional)"
