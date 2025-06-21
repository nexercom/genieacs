#!/bin/bash

# GenieACS unattended installation script for Ubuntu 22.04+

# Exit on error
set -e

# === VARIABLES ===
GENIEACS_DIR="/opt/genieacs"
GENIEACS_PORT="3000"
ADMIN_USER="admin"
ADMIN_PASS="admin123"

# === ACTUALIZACIÓN DEL SISTEMA ===
echo "🔧 Actualizando sistema..."
apt update && apt upgrade -y

# === INSTALACIÓN DE DEPENDENCIAS ===
echo "📦 Instalando dependencias..."
apt install -y curl gnupg build-essential mongodb npm git nodejs systemd

# === INSTALAR NODEJS VERSIÓN RECOMENDADA POR GENIEACS ===
curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
apt install -y nodejs

# === CLONAR GENIEACS ===
echo "📥 Clonando GenieACS..."
rm -rf "$GENIEACS_DIR"
git clone https://github.com/genieacs/genieacs.git "$GENIEACS_DIR"
cd "$GENIEACS_DIR"

# === INSTALAR DEPENDENCIAS DE NODEJS ===
echo "📦 Instalando paquetes NPM..."
npm install

# === CREAR SCRIPT DE INICIO ===
cat <<EOF > "$GENIEACS_DIR/start.sh"
#!/bin/bash
genieacs-cwmp &
genieacs-nbi &
genieacs-fs &
genieacs-ui
EOF
chmod +x "$GENIEACS_DIR/start.sh"

# === CREAR SERVICIO SYSTEMD ===
echo "🛠️ Configurando GenieACS como servicio..."
cat <<EOF > /etc/systemd/system/genieacs.service
[Unit]
Description=GenieACS Unified Service
After=network.target

[Service]
ExecStart=$GENIEACS_DIR/start.sh
WorkingDirectory=$GENIEACS_DIR
Restart=always
User=root
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# === RELOAD SYSTEMD Y HABILITAR SERVICIO ===
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable genieacs
systemctl start genieacs

# === SALIDA ===
echo "✅ Instalación completada."
echo "🌐 Accede a la UI: http://<tu_ip>:${GENIEACS_PORT}"
echo "👤 Usuario: ${ADMIN_USER} | Contraseña: ${ADMIN_PASS}"
