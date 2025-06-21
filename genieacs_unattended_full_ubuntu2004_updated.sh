
#!/bin/bash

set -e

echo "=== Actualizando sistema ==="
apt update && apt upgrade -y

echo "=== Instalando dependencias base ==="
apt install -y curl sudo gnupg build-essential software-properties-common

echo "=== Instalando Node.js 14.x ==="
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
apt install -y nodejs

echo "=== Añadiendo y eliminando soporte temporal para libssl1.1 ==="
echo "deb http://security.ubuntu.com/ubuntu impish-security main" | tee /etc/apt/sources.list.d/impish-security.list
apt update || true
apt install -y libssl1.1
rm /etc/apt/sources.list.d/impish-security.list
apt update || true

echo "=== Instalando MongoDB 4.4 ==="
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-org-4.4.gpg
echo "deb [signed-by=/usr/share/keyrings/mongodb-org-4.4.gpg] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
apt update
apt install -y mongodb-org
systemctl enable --now mongod

echo "=== Verificando MongoDB ==="
mongo --eval 'db.runCommand({ connectionStatus: 1 })'

echo "=== Instalando GenieACS 1.2.13 ==="
npm install -g genieacs@1.2.13

echo "=== Creando usuario y carpetas ==="
useradd --system --no-create-home --user-group genieacs
mkdir -p /opt/genieacs/ext
chown -R genieacs:genieacs /opt/genieacs

echo "=== Configurando variables de entorno ==="
cat <<EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
$(node -e "console.log('GENIEACS_UI_JWT_SECRET=' + require('crypto').randomBytes(128).toString('hex'))")
EOF

chown genieacs:genieacs /opt/genieacs/genieacs.env
chmod 600 /opt/genieacs/genieacs.env

echo "=== Creando carpeta de logs ==="
mkdir -p /var/log/genieacs
chown genieacs:genieacs /var/log/genieacs

echo "=== Configurando servicios systemd ==="
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

systemctl daemon-reexec
systemctl daemon-reload

echo "=== Habilitando e iniciando servicios ==="
for svc in cwmp nbi fs ui; do
    systemctl enable genieacs-$svc
    systemctl start genieacs-$svc
done

echo "=== Instalación completada ==="
echo "Accede a la interfaz: http://<TU_IP>:3000"
echo "Usuario: admin"
echo "Contraseña: admin123"
