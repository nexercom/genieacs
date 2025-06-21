#!/bin/bash

set -e

echo -e "\n\033[1;32m┌────────────────────────────────────────────┐"
echo -e "│         GENIEACS AUTO INSTALLER V1         │"
echo -e "│           by Steven Montero ☕             │"
echo -e "└────────────────────────────────────────────┘\033[0m\n"

log_step() {
    STEP=$1
    TOTAL=$2
    DESC=$3
    echo -e "\033[1;36m→ ($STEP/$TOTAL) $DESC... Done\033[0m"
}

TOTAL_STEPS=9

log_step 1 $TOTAL_STEPS "Actualización del sistema"
(
  apt update -y >/dev/null 2>&1
  apt upgrade -y >/dev/null 2>&1
)

log_step 2 $TOTAL_STEPS "Instalación de dependencias"
(
  apt install -y curl sudo gnupg2 ca-certificates lsb-release software-properties-common >/dev/null 2>&1
)

log_step 3 $TOTAL_STEPS "Instalando Node.js 14"
(
  curl -fsSL https://deb.nodesource.com/setup_14.x | bash - >/dev/null 2>&1
  apt install -y nodejs >/dev/null 2>&1
)

log_step 4 $TOTAL_STEPS "Instalando MongoDB"
(
  wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add - >/dev/null 2>&1
  echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list >/dev/null
  apt update -y >/dev/null 2>&1
  apt install -y mongodb-org >/dev/null 2>&1
  systemctl enable mongod >/dev/null 2>&1
  systemctl start mongod >/dev/null 2>&1
)

log_step 5 $TOTAL_STEPS "Clonando GenieACS desde GitHub"
(
  git clone https://github.com/genieacs/genieacs.git /opt/genieacs >/dev/null 2>&1
)

log_step 6 $TOTAL_STEPS "Instalando dependencias de GenieACS"
(
  cd /opt/genieacs
  npm install >/dev/null 2>&1
)

log_step 7 $TOTAL_STEPS "Configurando servicios GenieACS"
(
  cat <<EOF > /etc/systemd/system/genieacs-cwmp.service
[Unit]
Description=GenieACS CWMP
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/genieacs
ExecStart=/usr/bin/node dist/bin/cwmp.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  cat <<EOF > /etc/systemd/system/genieacs-nbi.service
[Unit]
Description=GenieACS NBI
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/genieacs
ExecStart=/usr/bin/node dist/bin/nbi.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  cat <<EOF > /etc/systemd/system/genieacs-fs.service
[Unit]
Description=GenieACS FS
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/genieacs
ExecStart=/usr/bin/node dist/bin/fs.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  cat <<EOF > /etc/systemd/system/genieacs-ui.service
[Unit]
Description=GenieACS UI
After=network.target

[Service]
Environment=UI_JWT_SECRET=$(openssl rand -hex 32)
Type=simple
User=root
WorkingDirectory=/opt/genieacs
ExecStart=/usr/bin/node dist/bin/ui.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
)

log_step 8 $TOTAL_STEPS "Habilitando y arrancando servicios GenieACS"
(
  systemctl daemon-reexec >/dev/null 2>&1
  systemctl daemon-reload >/dev/null 2>&1
  systemctl enable genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui >/dev/null 2>&1
  systemctl start genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui >/dev/null 2>&1
)

log_step 9 $TOTAL_STEPS "Finalizando instalación"

echo -e "\n\033[1;32m✔ Instalación completa de GenieACS"
echo -e "✔ Servicios iniciados correctamente"
echo -e "✔ Accede vía: http://<IP_DEL_SERVIDOR>:3000 (usuario: admin / contraseña: admin)"
echo -e "☕ Agradece a Steven Montero con un café :)\033[0m"
