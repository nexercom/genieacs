#!/bin/bash
clear
echo "###############################################################"
echo "#                                                             #"
echo "#          AutoInstallGenieACS - By Steven Montero           #"
echo "#                                                             #"
echo "###############################################################"
sleep 2
#!/bin/bash

# GenieACS Installer con Parametrización Interactiva
# Probado en Ubuntu 20.04

echo "╔═══════════════════════════════════════════╗"
echo "║ GenieACS Instalación - Modo Interactivo  ║"
echo "╚═══════════════════════════════════════════╝"

# Solicita parámetros al usuario
read -p "👉 Usuario para la interfaz web: " UI_USER
read -sp "🔐 Contraseña para la interfaz web: " UI_PASS
echo ""
read -p "📡 Usuario que usarán los CPEs para conectarse: " CPE_USER
read -sp "🔐 Contraseña de los CPEs: " CPE_PASS
echo ""
read -p "🌐 Puerto TR-069 (CWMP) [default 7547]: " CPE_PORT
CPE_PORT=${CPE_PORT:-7547}

# Instala dependencias base
apt update && apt install -y curl gnupg build-essential git software-properties-common

# Node.js 14.x
curl -sL https://deb.nodesource.com/setup_14.x | bash -
apt install -y nodejs

# MongoDB 4.4 + libssl1.1 para Ubuntu 20.04
echo "deb http://security.ubuntu.com/ubuntu impish-security main" | tee /etc/apt/sources.list.d/impish-security.list
apt update || true
apt install -y libssl1.1
rm /etc/apt/sources.list.d/impish-security.list
apt update || true
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
apt update
apt install -y mongodb-org
systemctl enable --now mongod

# Verifica MongoDB
until mongo --eval 'db.runCommand({ connectionStatus: 1 })'; do
  echo "⏳ Esperando MongoDB..."
  sleep 2
done

# Instala GenieACS
npm install -g genieacs@1.2.13

# Crea usuario sistema
useradd --system --no-create-home --user-group genieacs

# Directorios
mkdir -p /opt/genieacs/ext
mkdir -p /var/log/genieacs
chown -R genieacs:genieacs /opt/genieacs/ext /var/log/genieacs

# Archivo de entorno
cat <<EOF > /opt/genieacs/genieacs.env
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

# Archivos systemd
for svc in cwmp nbi fs ui; do
cat <<EOF > /etc/systemd/system/genieacs-$svc.service
[Unit]
Description=GenieACS $svc
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

# Modifica CWMP para usar el puerto personalizado
sed -i "s|ExecStart=/usr/bin/genieacs-cwmp|ExecStart=/usr/bin/genieacs-cwmp --port $CPE_PORT|" /etc/systemd/system/genieacs-cwmp.service

# Habilita servicios
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now genieacs-{cwmp,nbi,fs,ui}

# Espera que la UI esté arriba
sleep 5

# Inserta credenciales CPE vía API
curl -X PUT http://localhost:7557/config/cwmp.auth   -H 'Content-Type: application/json'   -d '["AUTH(\"'"$CPE_USER"'\", \"'"$CPE_PASS"'\")"]'

# Cambia credenciales de UI
htpasswd -bc /opt/genieacs/ui/.htpasswd "$UI_USER" "$UI_PASS"
chown genieacs:genieacs /opt/genieacs/ui/.htpasswd

echo "✅ Instalación completada"
echo "🌐 Accede a: http://<tu_ip>:3000 con $UI_USER / $UI_PASS"
echo "📡 CPEs usarán usuario: $CPE_USER, contraseña: $CPE_PASS en puerto $CPE_PORT"

echo ""
echo "==============================================================="
echo "🚀 Instalación completada con éxito"
echo "Componentes instalados y configurados:"
echo "- Node.js 14.x"
echo "- MongoDB 4.4 (con libssl1.1)"
echo "- GenieACS (cwmp, nbi, fs, ui)"
echo "- Usuario y contraseña de la interfaz web configurados"
echo "- Usuario, contraseña y puerto de los CPE configurados"
echo ""
echo "🔒 Accede al panel en: http://<TU_IP>:3000"
echo ""
echo "🎉 Créditos: Steven Montero"
echo "==============================================================="
