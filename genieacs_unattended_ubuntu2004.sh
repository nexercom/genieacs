
#!/bin/bash

set -e

# Variables personalizables
GENIEACS_ADMIN_USER="admin"
GENIEACS_ADMIN_PASS="admin123"
GENIEACS_PORT=3000
UI_JWT_SECRET=$(openssl rand -hex 32)

echo "🔧 Actualizando sistema..."
apt update && apt upgrade -y

echo "📦 Instalando dependencias..."
apt install -y curl gnupg build-essential git libssl1.1

echo "🔧 Instalando Node.js v14..."
curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
apt install -y nodejs

echo "🧰 Instalando MongoDB 4.4..."
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" \
    | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
apt update
apt install -y mongodb-org

echo "🟢 Iniciando MongoDB..."
systemctl enable mongod
systemctl start mongod

echo "📥 Clonando GenieACS..."
cd /opt
git clone https://github.com/genieacs/genieacs.git
cd genieacs
npm install

echo "🛠️ Configurando archivo environment..."
cat > .env <<EOF
GENIEACS_ADMIN_USER=${GENIEACS_ADMIN_USER}
GENIEACS_ADMIN_PASSWORD=${GENIEACS_ADMIN_PASS}
UI_JWT_SECRET=${UI_JWT_SECRET}
EOF

echo "⚙️ Creando archivo de servicio systemd..."
cat > /etc/systemd/system/genieacs.service <<EOF
[Unit]
Description=GenieACS Unified Service
After=network.target mongod.service

[Service]
WorkingDirectory=/opt/genieacs
ExecStart=/usr/bin/npm run start
Restart=always
Environment=NODE_ENV=production
EnvironmentFile=/opt/genieacs/.env
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=genieacs
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "🚀 Iniciando servicio GenieACS..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable genieacs
systemctl start genieacs

echo "✅ Instalación completada!"
echo "🌐 Accede a la interfaz: http://<tu_ip>:${GENIEACS_PORT}"
echo "🔐 Usuario: ${GENIEACS_ADMIN_USER}"
echo "🔐 Contraseña: ${GENIEACS_ADMIN_PASS}"
