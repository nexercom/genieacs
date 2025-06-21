#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# GenieACS Unattended Installer with Interactive Parameters for Ubuntu 20.04
# ─────────────────────────────────────────────────────────────────────────────

# Preguntar datos de configuración
read -p "🟢 Usuario para acceder al UI: " UI_USER
read -s -p "🔒 Contraseña para el UI: " UI_PASS
echo
read -p "🌐 Puerto CWMP para conexión de CPEs [default: 7547]: " CPE_PORT
CPE_PORT=${CPE_PORT:-7547}
read -p "🆔 Usuario TR-069 para CPEs [default: acsuser]: " TR069_USER
TR069_USER=${TR069_USER:-acsuser}
read -s -p "🔑 Contraseña TR-069 para CPEs: " TR069_PASS
echo

# Actualización del sistema
echo "🔧 Actualizando sistema..."
apt update && apt upgrade -y

# Instalar dependencias
echo "📦 Instalando dependencias..."
apt install -y curl sudo gnupg build-essential

# Instalar Node.js
echo "📥 Instalando Node.js..."
curl -sL https://deb.nodesource.com/setup_14.x | bash -
apt install -y nodejs

# Instalar MongoDB (con libssl1.1 temporal)
echo "🧩 Instalando MongoDB y libssl1.1..."
echo "deb http://security.ubuntu.com/ubuntu impish-security main" > /etc/apt/sources.list.d/impish-security.list
apt update
apt install -y libssl1.1
rm /etc/apt/sources.list.d/impish-security.list
apt update

curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
apt update
apt install -y mongodb-org
systemctl start mongod
systemctl enable mongod

# Instalar GenieACS desde NPM
echo "🚀 Instalando GenieACS..."
npm install -g genieacs@1.2.13

# Crear usuario y carpetas
useradd --system --no-create-home --user-group genieacs
mkdir -p /opt/genieacs/ext
chown genieacs:genieacs /opt/genieacs/ext

# Crear archivo de entorno
mkdir -p /var/log/genieacs
chown genieacs:genieacs /var/log/genieacs

cat <<EOF > /opt/genieacs/genieacs.env
GENIEACS_UI_USERNAME=$UI_USER
GENIEACS_UI_PASSWORD=$UI_PASS
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(128).toString('hex'))")
EOF

chown genieacs:genieacs /opt/genieacs/genieacs.env
chmod 600 /opt/genieacs/genieacs.env

# Crear servicios systemd
for svc in cwmp nbi fs ui; do
cat <<EOF > /etc/systemd/system/genieacs-$svc.service
[Unit]
Description=GenieACS $svc
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$svc
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
done

# Rotación de logs
cat <<EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF

# Iniciar servicios
for svc in cwmp nbi fs ui; do
    systemctl daemon-reexec
    systemctl enable genieacs-$svc
    systemctl start genieacs-$svc
    systemctl status genieacs-$svc --no-pager
done

echo "✅ Instalación completada. Accede a la interfaz web por http://<tu-ip>:3000"
