#!/bin/bash
set -e

# Log output
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting setup at $(date)"

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
apt-get install -y docker.io docker-compose git
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Clone repository
cd /home/ubuntu
git clone ${github_repo} voice-agent
cd voice-agent

# Create .env file
cat > .env << EOF
OPENAI_API_KEY=${openai_api_key}
EOF

# Create production docker-compose
cat > docker-compose.prod.yml << 'EOF'
services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: hieunghi-voice-backend
    network_mode: "host"
    environment:
      - OPENAI_API_KEY=$${OPENAI_API_KEY}
      - HOST=0.0.0.0
      - PORT=7860
    restart: always

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: hieunghi-voice-frontend
    network_mode: "host"
    depends_on:
      - backend
    restart: always
EOF

# Set permissions
chown -R ubuntu:ubuntu /home/ubuntu/voice-agent

# Build and run
cd /home/ubuntu/voice-agent
docker-compose -f docker-compose.prod.yml up -d --build

echo "Setup completed at $(date)"
