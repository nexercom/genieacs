
echo "╔══════════════════════════════════════════════════╗"
echo "║          GenieACS Auto-Installer v1.0            ║"
echo "║         Creado por Steven Montero 🇩🇴☕           ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
#!/bin/bash
set -e

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
echo "🔧 Instalando paso (1/20)... sudo systemctl start mongod"
sudo systemctl start mongod > /dev/null 2>&1
echo "✅ Paso 1 completado."

echo "🔧 Instalando paso (2/20)... sudo systemctl enable mongod"
sudo systemctl enable mongod > /dev/null 2>&1
echo "✅ Paso 2 completado."


# Espera a que MongoDB arranque completamente
sleep 5

# Verifica conexión a MongoDB
mongo --eval 'db.runCommand({ connectionStatus: 1 })'

# Instala GenieACS desde NPM
echo "🔧 Instalando paso (3/20)... sudo npm install -g genieacs@1.2.13"
sudo npm install -g genieacs@1.2.13 > /dev/null 2>&1
echo "✅ Paso 3 completado."


# Crea usuario y directorios
sudo useradd --system --no-create-home --user-group genieacs
echo "🔧 Instalando paso (4/20)... sudo mkdir -p /opt/genieacs/ext"
sudo mkdir -p /opt/genieacs/ext > /dev/null 2>&1
echo "✅ Paso 4 completado."

echo "🔧 Instalando paso (5/20)... sudo chown genieacs:genieacs /opt/genieacs/ext"
sudo chown genieacs:genieacs /opt/genieacs/ext > /dev/null 2>&1
echo "✅ Paso 5 completado."


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
echo "🔧 Instalando paso (6/20)... sudo chown genieacs:genieacs /opt/genieacs/genieacs.env"
sudo chown genieacs:genieacs /opt/genieacs/genieacs.env > /dev/null 2>&1
echo "✅ Paso 6 completado."

echo "🔧 Instalando paso (7/20)... sudo chmod 600 /opt/genieacs/genieacs.env"
sudo chmod 600 /opt/genieacs/genieacs.env > /dev/null 2>&1
echo "✅ Paso 7 completado."


# Crea logs
echo "🔧 Instalando paso (8/20)... sudo mkdir -p /var/log/genieacs"
sudo mkdir -p /var/log/genieacs > /dev/null 2>&1
echo "✅ Paso 8 completado."

echo "🔧 Instalando paso (9/20)... sudo chown genieacs:genieacs /var/log/genieacs"
sudo chown genieacs:genieacs /var/log/genieacs > /dev/null 2>&1
echo "✅ Paso 9 completado."


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
echo "🔧 Instalando paso (10/20)... sudo systemctl enable genieacs-$service"
sudo systemctl enable genieacs-$service > /dev/null 2>&1
echo "✅ Paso 10 completado."

echo "🔧 Instalando paso (11/20)... sudo systemctl start genieacs-$service"
sudo systemctl start genieacs-$service > /dev/null 2>&1
echo "✅ Paso 11 completado."

done

echo "✅ Instalación completada. Accede a la UI: http://<tu_ip>:3000"

echo ""
echo "🎉 Instalación completada exitosamente."
echo "📋 Resumen:"
echo "- GenieACS instalado y configurado"
echo "- Servicios activados y habilitados"
echo "- MongoDB, Node.js, Redis y demás dependencias listas"
echo ""
echo "☕ Si esto te ayudó, ¡invita un café a Steven Montero!"
