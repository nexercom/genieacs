#!/bin/bash

set -e

# -----------------------------
# GenieACS Unattended Installer for Ubuntu 20.04 (Stable)
# -----------------------------

# Update system
apt update && apt upgrade -y

# Install prerequisites
apt install -y curl gnupg gcc g++ make git

# Add Node.js 14.x
curl -sL https://deb.nodesource.com/setup_14.x | bash -
apt install -y nodejs

# Install libssl1.1 for MongoDB
echo "deb http://security.ubuntu.com/ubuntu impish-security main" > /etc/apt/sources.list.d/impish-security.list
apt update
apt install -y libssl1.1

# Install MongoDB 4.4
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-4.4.list
apt update
apt install -y mongodb-org
systemctl enable --now mongod

# Create genieacs user
useradd --system --no-create-home --user-group genieacs

# Install GenieACS via NPM
npm install -g genieacs@1.2.13

# Setup directory and permissions
mkdir -p /opt/genieacs/ext
chown -R genieacs:genieacs /opt/genieacs

# Setup environment config
cat <<EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
EOF

# Generate JWT Secret
echo "GENIEACS_UI_JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(128).toString('hex'))")" >> /opt/genieacs/genieacs.env
chown genieacs:genieacs /opt/genieacs/genieacs.env
chmod 600 /opt/genieacs/genieacs.env

# Create log directory
mkdir -p /var/log/genieacs
chown genieacs:genieacs /var/log/genieacs

# Create systemd services
for svc in cwmp nbi fs ui; do
cat <<EOF > /etc/systemd/system/genieacs-$svc.service
[Unit]
Description=GenieACS ${svc^^}
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$svc
Restart=always

[Install]
WantedBy=multi-user.target
EOF
done

# Log rotation
cat <<EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
    missingok
    notifempty
    copytruncate
}
EOF

# Reload and start services
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now genieacs-{cwmp,nbi,fs,ui}

echo "✅ Instalación completa"
echo "🔗 Accede vía: http://<tu_ip>:3000"
echo "👤 Usuario: admin"
echo "🔐 Contraseña: admin123"
