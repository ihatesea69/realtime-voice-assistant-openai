#!/bin/bash
set -e

# Log output
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting setup at $(date)"

# Update system
apt-get update
# apt-get upgrade -y

# Install Docker, Nginx, CoTURN
apt-get install -y docker.io docker-compose git nginx coturn curl
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# --- CoTURN Setup (Self-Hosted TURN) ---
echo "Configuring CoTURN..."
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Enable CoTURN daemon
sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/g' /etc/default/coturn

# Configure turnserver.conf
cat > /etc/turnserver.conf << EOF
listening-port=3478
external-ip=$PUBLIC_IP
fingerprint
lt-cred-mech
user=hieunghi:voiceagent
realm=voiceagent
min-port=49152
max-port=65535
log-file=/var/log/turnserver.log
verbose
EOF

systemctl restart coturn
echo "CoTURN configured with IP: $PUBLIC_IP"

# --- Repository Setup ---
cd /home/ubuntu
git clone ${github_repo} voice-agent
cd voice-agent

# Create .env file for Backend
# Note: TURN_HOST is now the EC2 Public IP (or CloudFront if using specific routing, but TURN needs IP)
# Backend will use internal TURN config or we pass this env.
cat > .env << EOF
OPENAI_API_KEY=${openai_api_key}
TURN_USERNAME=hieunghi
TURN_CREDENTIAL=voiceagent
TURN_HOST=$PUBLIC_IP
TURN_PORT=3478
EOF

# --- Nginx Setup (HTTP Only - CloudFront handles SSL) ---
echo "Configuring Nginx..."

cat > /etc/nginx/sites-available/voice-agent << EOF
server {
    listen 80;
    server_name _; # Catch all (CloudFront requests)

    # Allow large bodies if needed
    client_max_body_size 10M;

    # Frontend Proxy
    location / {
        proxy_pass http://localhost:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    # Backend API Proxy
    location /offer {
        proxy_pass http://127.0.0.1:7860;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # WebSocket Proxy
    location /ws {
        proxy_pass http://127.0.0.1:7860;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/voice-agent /etc/nginx/sites-enabled/
systemctl restart nginx

# --- Docker Compose Setup ---
cat > docker-compose.prod.yml << 'EOF'
services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: hieunghi-voice-backend
    network_mode: "host"
    env_file: .env
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
