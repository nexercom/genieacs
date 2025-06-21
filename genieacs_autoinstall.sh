#!/bin/bash

# Instalador desatendido de GenieACS para Ubuntu 22.04

# Variables por defecto
ADMIN_USER="admin"
ADMIN_PASS="admin123"
UI_PORT=3000
API_PORT=7557
NBI_PORT=7559
FS_PORT=7567
JWT_SECRET="genieacs_secret_key"

set -e

echo "🔧 Actualizando sistema..."
sudo apt update && sudo apt upgrade -y

echo "📦 Instalando dependencias..."
sudo apt install -y git curl gnupg2 build-essential redis-server

echo "📦 Instalando MongoDB desde el repositorio oficial..."
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl enable mongod
sudo systemctl start mongod

echo "📦 Instalando Node.js LTS (18)..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

echo "📂 Clonando GenieACS..."
cd /opt
sudo git clone https://github.com/genieacs/genieacs.git
cd genieacs
sudo npm install

echo "🛠️ Configurando entorno..."
sudo tee .env > /dev/null <<EOF
GENIEACS_UI_JWT_SECRET=$JWT_SECRET
GENIEACS_UI_USERNAME=$ADMIN_USER
GENIEACS_UI_PASSWORD=$ADMIN_PASS
GENIEACS_UI_PORT=$UI_PORT
GENIEACS_CWMP_HTTP_PORT=$API_PORT
GENIEACS_NBI_HTTP_PORT=$NBI_PORT
GENIEACS_FS_HTTP_PORT=$FS_PORT
EOF

echo "🧱 Creando archivo de servicio systemd..."
sudo tee /etc/systemd/system/genieacs.service > /dev/null <<EOF
[Unit]
Description=GenieACS Unified Service
After=network.target mongod.service redis-server.service

[Service]
Type=simple
WorkingDirectory=/opt/genieacs
ExecStart=/usr/bin/npm start
Restart=on-failure
User=root
EnvironmentFile=/opt/genieacs/.env

[Install]
WantedBy=multi-user.target
EOF

echo "🚀 Iniciando servicio GenieACS..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable genieacs
sudo systemctl start genieacs

echo "✅ Instalación completa"
echo "🌐 Accede a la UI: http://<tu_ip>:$UI_PORT"
echo "🔐 Usuario: $ADMIN_USER | Contraseña: $ADMIN_PASS"
