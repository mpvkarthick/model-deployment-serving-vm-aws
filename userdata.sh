#!/bin/bash
################################################################################
# Intent Classifier Application - EC2 User Data Script
################################################################################
#
# PURPOSE:
#   This script initializes a new AWS EC2 instance with all dependencies and
#   configuration required to deploy the Intent Classifier ML model as a web
#   service. It automates the entire setup process from bare OS to running
#   application.
#
# USAGE:
#   - Provide this script as the user data when launching an EC2 instance
#   - Ensure the EC2 instance has appropriate IAM roles/permissions for GitHub
#   - Monitor /var/log/cloud-init-output.log for execution logs
#
# PREREQUISITES:
#   - Ubuntu-based EC2 instance (tested on Ubuntu 20.04+)
#   - Git SSH access configured (or use HTTPS with credentials)
#   - Internet connectivity for package downloads
#
# COMPONENTS SET UP:
#   1. System dependencies (Python, Git, Nginx)
#   2. Python virtual environment with required packages
#   3. ML model training
#   4. Gunicorn WSGI application server
#   5. Nginx reverse proxy
#   6. Systemd services for process management
#
# APPLICATION ENDPOINTS:
#   - HTTP: http://<instance-ip>/predict (proxied to Gunicorn on port 6000)
#   - Internal: http://127.0.0.1:6000 (Gunicorn application server)
#
# ERROR HANDLING:
#   - Script exits on any command failure (set -e)
#   - Review cloud-init logs if script fails
#
################################################################################

set -e

# ============================================================================
# SECTION 1: ENVIRONMENT SETUP AND DIRECTORY INITIALIZATION
# ============================================================================

export APP_DIRECTORY="/opt/intent-hw-app"
mkdir -p $APP_DIRECTORY
cd $APP_DIRECTORY

# ============================================================================
# SECTION 2: SYSTEM PACKAGE INSTALLATION
# ============================================================================
# Install core dependencies: version control, Python runtime, web server

apt-get update -y
apt install -y git python3 python3-pip nginx python3-venv

# ============================================================================
# SECTION 3: CLONE APPLICATION SOURCE CODE
# ============================================================================
# Clone the Intent Classifier application repository into the app directory

git clone git@github.com:mpvkarthick/model-deployment-serving-vm-aws.git .

# ============================================================================
# SECTION 4: PYTHON VIRTUAL ENVIRONMENT AND DEPENDENCIES
# ============================================================================
# Create isolated Python environment and install application requirements

python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn

# ============================================================================
# SECTION 5: MODEL TRAINING
# ============================================================================
# Train the Intent Classifier ML model using the training script

python3 model/train.py

# ============================================================================
# SECTION 6: GUNICORN SYSTEMD SERVICE CONFIGURATION
# ============================================================================
# Configure Gunicorn as a systemd service for automatic startup and process
# management. This service runs the Python WSGI application on port 6000
# with 3 worker processes.
#
# Service Details:
#   - Name: intent_gunicorn
#   - Port: 6000 (localhost only, exposed via Nginx)
#   - Workers: 3
#   - User: ubuntu
#   - Auto-restart: enabled
#   - Auto-start on boot: enabled
cat >/etc/systemd/system/intent_gunicorn.service <<'EOF'
[Unit]
Description=Gunicorn instance for Intent Classifier
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/intent-hw-app
Environment="PATH=/opt/intent-hw-app/venv/bin"
ExecStart=/opt/intent-hw-app/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:6000 wsgi:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ============================================================================
# SECTION 7: NGINX REVERSE PROXY CONFIGURATION
# ============================================================================
# Configure Nginx as a reverse proxy to forward HTTP traffic to the Gunicorn
# application server. This provides SSL termination capability and load
# balancing support.
#
# Proxy Details:
#   - Listen: port 80 (HTTP)
#   - Forward to: http://127.0.0.1:6000/predict
#   - Headers: Preserve client IP and hostname
#   - Timeouts: 60s connect, 120s read
cat >/etc/nginx/conf.d/intent_app.conf <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:6000/predict;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_read_timeout 120s;
    }
}
EOF

# ============================================================================
# SECTION 8: CLEANUP - REMOVE CONFLICTING NGINX CONFIGURATION
# ============================================================================
# Remove the default Nginx configuration to avoid port conflict with our
# custom configuration on the same port (80).

if [ -L /etc/nginx/sites-enabled/default ] || [ -f /etc/nginx/sites-enabled/default ]; then
  rm -f /etc/nginx/sites-enabled/default || true
fi

# ============================================================================
# SECTION 9: START AND ENABLE SERVICES
# ============================================================================
# Reload systemd configuration and start/enable both services for immediate
# operation and automatic startup on system reboot.

systemctl daemon-reload
systemctl enable intent_gunicorn
systemctl start intent_gunicorn
systemctl enable nginx
systemctl restart nginx

################################################################################
# END OF USER DATA SCRIPT
################################################################################
# 
# VERIFICATION CHECKLIST after script completion:
# 
#   1. Check service status:
#      sudo systemctl status intent_gunicorn
#      sudo systemctl status nginx
# 
#   2. View application logs:
#      sudo journalctl -u intent_gunicorn -f
# 
#   3. Test the application:
#      curl http://localhost/predict
# 
#   4. Monitor cloud-init logs:
#      tail -f /var/log/cloud-init-output.log
# 
# TROUBLESHOOTING:
# 
#   - Service fails to start: Check logs with 'journalctl' command above
#   - Port conflicts: Verify ports 80 and 6000 are available
#   - Git clone fails: Ensure SSH keys are configured for EC2 instance
#   - Model training fails: Check Python dependencies in requirements.txt
#
################################################################################
