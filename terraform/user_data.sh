#!/bin/bash
set -e

# Log output
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting setup at $(date)"

# Update system
apt-get update
# Skipping full upgrade to save time, install only necessities
# apt-get upgrade -y

# Install Docker, Nginx, Certbot
apt-get install -y docker.io docker-compose git nginx certbot python3-certbot-nginx
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Clone repository
cd /home/ubuntu
git clone ${github_repo} voice-agent
cd voice-agent

# Create .env file with Credentials
cat > .env << EOF
OPENAI_API_KEY=${openai_api_key}
TURN_USERNAME=${turn_username}
TURN_CREDENTIAL=${turn_credential}
EOF

# Nginx Configuration
if [ ! -z "${domain_name}" ]; then
    echo "Configuring Nginx for domain: ${domain_name}"
    
    cat > /etc/nginx/sites-available/voice-agent << EOF
server {
    server_name ${domain_name};

    # Frontend Proxy (Vite port 5173)
    location / {
        proxy_pass http://localhost:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    # Backend API Proxy (Pipecat port 7860)
    location /offer {
        proxy_pass http://127.0.0.1:7860;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Backend WebSocket Proxy (Pipecat port 7860)
    location /ws {
        proxy_pass http://127.0.0.1:7860;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    # Listen on HTTP (Certbot will upgrade to HTTPS later)
    listen 80;
}
EOF

    # Enable Site
    rm -f /etc/nginx/sites-enabled/default
    ln -s /etc/nginx/sites-available/voice-agent /etc/nginx/sites-enabled/
    systemctl restart nginx

    # Create SSL setup script for manual execution (Certbot often requires interaction or DNS verification)
    echo "#!/bin/bash" > /home/ubuntu/setup_ssl.sh
    echo "certbot --nginx -d ${domain_name} --non-interactive --agree-tos -m admin@${domain_name} --redirect" >> /home/ubuntu/setup_ssl.sh
    chmod +x /home/ubuntu/setup_ssl.sh
    
    # Try to verify ownership (optional, might fail if DNS isn't propagated)
    # /home/ubuntu/setup_ssl.sh || echo "SSL setup failed (likely DNS), run manually later."
fi

# Create production docker-compose
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
