#!/bin/bash

set -e

# Variables configurables
GENIEACS_USER="admin"
GENIEACS_PASS="admin123"
GENIEACS_PORT="3000"
UI_JWT_SECRET="$(openssl rand -hex 32)"

echo "🔧 Actualizando sistema..."
apt update -y && apt upgrade -y

echo "📦 Instalando dependencias básicas..."
apt install -y curl gnupg build-essential git

echo "📦 Instalando Node.js v14..."
curl -sL https://deb.nodesource.com/setup_14.x -o nodesource_setup.sh
bash nodesource_setup.sh
apt install -y nodejs

echo "📦 Instalando libssl1.1 (desde impish)..."
echo "deb http://security.ubuntu.com/ubuntu impish-security main" > /etc/apt/sources.list.d/impish-security.list
apt update
apt install -y libssl1.1

echo "📦 Instalando MongoDB 4.4..."
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-4.4.list
apt update
apt install -y mongodb-org
systemctl start mongod
systemctl enable mongod

echo "✅ Verificando MongoDB..."
mongo --eval 'db.runCommand({ connectionStatus: 1 })'

echo "📥 Clonando GenieACS..."
cd /opt
git clone https://github.com/genieacs/genieacs.git
cd genieacs
npm install

echo "🔧 Creando archivo de entorno..."
cat <<EOF > .env
UI_JWT_SECRET=${UI_JWT_SECRET}
GENIEACS_ADMIN_USERNAME=${GENIEACS_USER}
GENIEACS_ADMIN_PASSWORD=${GENIEACS_PASS}
EOF

echo "🔧 Agregando script de inicio al package.json..."
sed -i '/"scripts": {/a \ \ \ \ "start": "genieacs-cwmp & genieacs-nbi & genieacs-fs & genieacs-ui",' package.json

echo "🔧 Creando servicio systemd..."
cat <<EOF > /etc/systemd/system/genieacs.service
[Unit]
Description=GenieACS Unified Service
After=network.target mongod.target

[Service]
WorkingDirectory=/opt/genieacs
ExecStart=/usr/bin/npm start
Restart=always
Environment=UI_JWT_SECRET=${UI_JWT_SECRET}
Environment=GENIEACS_ADMIN_USERNAME=${GENIEACS_USER}
Environment=GENIEACS_ADMIN_PASSWORD=${GENIEACS_PASS}
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=genieacs

[Install]
WantedBy=multi-user.target
EOF

echo "📛 Habilitando y arrancando servicio..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable genieacs
systemctl start genieacs

echo "✅ Instalación completada"
echo "🌐 Accede a la interfaz: http://<tu_ip>:${GENIEACS_PORT}"
echo "👤 Usuario: ${GENIEACS_USER} | 🔐 Contraseña: ${GENIEACS_PASS}"
