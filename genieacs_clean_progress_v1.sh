#!/bin/bash

clear
echo "╔══════════════════════════════════════════════╗"
echo "║       GENIEACS AUTO INSTALLER v1            ║"
echo "║       Creado por Steven Montero ☕          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Contador de pasos
STEP=1
TOTAL_STEPS=10

step() {
    echo -e "[${STEP}/${TOTAL_STEPS}] $1... \033[1;32mDone\033[0m"
    STEP=$((STEP + 1))
}

# Actualizar sistema
echo "[${STEP}/${TOTAL_STEPS}] 🔄 Actualizando sistema..."
apt-get update -qq > /dev/null && apt-get upgrade -y -qq > /dev/null
step "🔄 Sistema actualizado"

# Instalar dependencias
echo "[${STEP}/${TOTAL_STEPS}] 📦 Instalando dependencias necesarias..."
apt-get install -y -qq curl sudo gnupg apt-transport-https lsb-release ca-certificates > /dev/null
step "📦 Dependencias instaladas"

# Instalar MongoDB
echo "[${STEP}/${TOTAL_STEPS}] 🧰 Instalando MongoDB..."
apt-get install -y -qq mongodb > /dev/null
systemctl enable mongodb > /dev/null
systemctl start mongodb > /dev/null
step "🧰 MongoDB instalado y habilitado"

# Instalar Node.js
echo "[${STEP}/${TOTAL_STEPS}] 🔧 Instalando Node.js..."
curl -sL https://deb.nodesource.com/setup_14.x | bash - > /dev/null
apt-get install -y -qq nodejs > /dev/null
step "🔧 Node.js instalado"

# Instalar Redis
echo "[${STEP}/${TOTAL_STEPS}] 💾 Instalando Redis..."
apt-get install -y -qq redis-server > /dev/null
systemctl enable redis-server > /dev/null
systemctl start redis-server > /dev/null
step "💾 Redis instalado y habilitado"

# Instalar GenieACS
echo "[${STEP}/${TOTAL_STEPS}] 🚀 Instalando GenieACS..."
npm install -g --silent genieacs > /dev/null
step "🚀 GenieACS instalado"

# Crear usuario y directorios
echo "[${STEP}/${TOTAL_STEPS}] 🗂️ Creando usuario y carpetas..."
useradd --system --home-dir /opt/genieacs --shell /usr/sbin/nologin genieacs || true
mkdir -p /opt/genieacs
chown -R genieacs:genieacs /opt/genieacs
step "🗂️ Usuario y carpetas listas"

# Crear servicios systemd
echo "[${STEP}/${TOTAL_STEPS}] ⚙️ Configurando servicios systemd..."
cat <<EOF > /etc/systemd/system/genieacs-cwmp.service
[Unit]
Description=GenieACS CWMP
After=network.target

[Service]
ExecStart=/usr/bin/genieacs-cwmp
Restart=always
User=genieacs
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/genieacs-nbi.service
[Unit]
Description=GenieACS NBI
After=network.target

[Service]
ExecStart=/usr/bin/genieacs-nbi
Restart=always
User=genieacs
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/genieacs-fs.service
[Unit]
Description=GenieACS FS
After=network.target

[Service]
ExecStart=/usr/bin/genieacs-fs
Restart=always
User=genieacs
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/genieacs-ui.service
[Unit]
Description=GenieACS UI
After=network.target

[Service]
ExecStart=/usr/bin/genieacs-ui
Restart=always
User=genieacs
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload > /dev/null
step "⚙️ Servicios systemd configurados"

# Habilitar y levantar servicios
echo "[${STEP}/${TOTAL_STEPS}] 🔌 Habilitando y levantando servicios..."
systemctl enable genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui > /dev/null
systemctl start genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui > /dev/null
step "🔌 Servicios GenieACS activos"

# Verificar acceso
echo "[${STEP}/${TOTAL_STEPS}] 🔍 Verificando acceso a GenieACS..."
sleep 5
if ss -tuln | grep -q ":3000"; then
    step "🔍 GenieACS accesible en el puerto 3000"
else
    echo "[!] Error: GenieACS no está corriendo correctamente"
fi

# Final
echo ""
echo "🎉 Instalación completada con éxito"
echo "🌐 Accede al panel: http://<TU-IP>:3000"
echo "🔐 Usuario: admin / Contraseña: admin"
echo ""
echo "☕ Si este script te ayudó, ¡invita un café a Steven Montero!"
