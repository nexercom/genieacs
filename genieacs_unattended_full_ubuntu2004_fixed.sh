#!/bin/bash
set -e

echo -e "\n\033[1;32m┌────────────────────────────────────────────┐"
echo -e "│         GENIEACS AUTO INSTALLER V1         │"
echo -e "│           by Steven Montero ☕             │"
echo -e "└────────────────────────────────────────────┘\033[0m\n"

# Instala Node.js 14.x
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs

# Agrega repo temporal para libssl1.1
echo "deb http://security.ubuntu.com/ubuntu impish-security main" | sudo tee /etc/apt/sources.list.d/impish-security.list
sudo apt-get update || true
sudo apt-get install -y libssl1.1
sudo rm /etc/apt/sources.list.d/impish-security.list
sudo apt-get update || true

# Instala MongoDB 4.4
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt-get update
sudo apt-get install -y mongodb-org

# Inicia y habilita MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod

# Espera a que MongoDB arranque completamente
sleep 5

# Verifica conexión a MongoDB
mongo --eval 'db.runCommand({ connectionStatus: 1 })'

# Instala GenieACS desde NPM
sudo npm install -g genieacs@1.2.13

# Crea usuario y directorios
sudo useradd --system --no-create-home --user-group genieacs
sudo mkdir -p /opt/genieacs/ext
sudo chown genieacs:genieacs /opt/genieacs/ext

# Crea archivo de configuración de entorno
cat <<EOF | sudo tee /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
EOF

# Genera JWT secreto y lo agrega
node -e "console.log('GENIEACS_UI_JWT_SECRET=' + require('crypto').randomBytes(128).toString('hex'))" | sudo tee -a /opt/genieacs/genieacs.env
sudo chown genieacs:genieacs /opt/genieacs/genieacs.env
sudo chmod 600 /opt/genieacs/genieacs.env

# Crea logs
sudo mkdir -p /var/log/genieacs
sudo chown genieacs:genieacs /var/log/genieacs

# Crea servicios systemd
for service in cwmp nbi fs ui; do
  sudo tee /etc/systemd/system/genieacs-$service.service > /dev/null <<EOF
[Unit]
Description=GenieACS ${service^^}
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$service

[Install]
WantedBy=default.target
EOF
done

# Habilita e inicia servicios
for service in cwmp nbi fs ui; do
  sudo systemctl enable genieacs-$service
  sudo systemctl start genieacs-$service
done

clear

echo -e "\n\033[1;32m┌────────────────────────────────────────────┐"
echo -e "│         GENIEACS AUTO INSTALLER V1         │"
echo -e "│           by Steven Montero ☕             │"
echo -e "└────────────────────────────────────────────┘\033[0m\n"


echo -e "\n\033[1;32m✔ Instalación completa de GenieACS"
echo -e "✔ Servicios iniciados correctamente"
echo -e "✔ Accede vía: http://<IP_DEL_SERVIDOR>:3000 (usuario: admin / contraseña: admin)"
echo -e "☕ Agradece a Steven Montero con un café :)\033[0m"
