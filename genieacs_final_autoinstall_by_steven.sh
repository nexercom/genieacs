
#!/bin/bash

set -e

echo -e "\n\033[1;32m╔═══════════════════════════════════════╗"
echo -e "║    GENIEACS AUTO INSTALLER V1        ║"
echo -e "║        by Steven Montero ☕          ║"
echo -e "╚═══════════════════════════════════════╝\033[0m\n"

log_step() {
    STEP=$1
    TOTAL=$2
    DESC=$3
    echo -e "\e[1;32m🔧 Instalando $DESC ($STEP/$TOTAL)...\e[0m"
}

# Ocultar la salida de comandos individuales y solo mostrar progreso
exec 3>&1 4>&2
exec > >(tee /tmp/genieacs_install.log >/dev/null) 2>&1

TOTAL_STEPS=9

log_step 1 $TOTAL_STEPS "Actualización del sistema"
apt update -y >/dev/null && apt upgrade -y >/dev/null

log_step 2 $TOTAL_STEPS "Instalación de dependencias"
apt install -y curl sudo gnupg2 ca-certificates lsb-release software-properties-common >/dev/null

log_step 3 $TOTAL_STEPS "Instalando Node.js 14"
curl -fsSL https://deb.nodesource.com/setup_14.x | bash - >/dev/null 2>&1
apt install -y nodejs >/dev/null

log_step 4 $TOTAL_STEPS "Instalación de MongoDB 4.4"
echo "deb http://security.ubuntu.com/ubuntu impish-security main" > /etc/apt/sources.list.d/impish-security.list
apt update -y >/dev/null
apt install -y libssl1.1 >/dev/null
rm /etc/apt/sources.list.d/impish-security.list
apt update -y >/dev/null
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add - >/dev/null
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-4.4.list
apt update -y >/dev/null
apt install -y mongodb-org >/dev/null
systemctl start mongod
systemctl enable mongod

log_step 5 $TOTAL_STEPS "Instalación de GenieACS"
npm install -g genieacs@1.2.13 >/dev/null

log_step 6 $TOTAL_STEPS "Configurando entorno GenieACS"
useradd --system --no-create-home --user-group genieacs || true
mkdir -p /opt/genieacs/ext
chown genieacs:genieacs /opt/genieacs/ext

mkdir -p /var/log/genieacs
chown genieacs:genieacs /var/log/genieacs

ENV_FILE="/opt/genieacs/genieacs.env"
cat <<EOF > $ENV_FILE
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
EOF

echo "GENIEACS_UI_JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(128).toString('hex'))")" >> $ENV_FILE
chown genieacs:genieacs $ENV_FILE
chmod 600 $ENV_FILE

log_step 7 $TOTAL_STEPS "Creación de servicios systemd"
for svc in cwmp nbi fs ui; do
cat <<EOF > /etc/systemd/system/genieacs-$svc.service
[Unit]
Description=GenieACS $svc
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$svc

[Install]
WantedBy=default.target
EOF
done

log_step 8 $TOTAL_STEPS "Activación de servicios"
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui
systemctl start genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui

log_step 9 $TOTAL_STEPS "Finalizando instalación"

exec 1>&3 2>&4

echo -e "\n\e[1;34m✅ Instalación completada con éxito\e[0m"
echo -e "➡ GenieACS está corriendo. Accede vía: http://<TU-IP>:3000"
echo -e "\n☕ Créditos: Steven Montero - Si te funcionó, ¡invítame un café!\n"
