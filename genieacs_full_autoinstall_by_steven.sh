    #!/bin/bash

    clear
    echo "███████╗██╗   ██╗████████╗ ██████╗ ███╗   ██╗███████╗ █████╗  ██████╗███████╗"
    echo "██╔════╝██║   ██║╚══██╔══╝██╔═══██╗████╗  ██║██╔════╝██╔══██╗██╔════╝██╔════╝"
    echo "█████╗  ██║   ██║   ██║   ██║   ██║██╔██╗ ██║█████╗  ███████║██║     █████╗  "
    echo "██╔══╝  ██║   ██║   ██║   ██║   ██║██║╚██╗██║██╔══╝  ██╔══██║██║     ██╔══╝  "
    echo "██║     ╚██████╔╝   ██║   ╚██████╔╝██║ ╚████║███████╗██║  ██║╚██████╗███████╗"
    echo "╚═╝      ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚══════╝"
    echo "                      AutoInstallGenieACS by Steven Montero"
    echo ""

    read -p "👤 Usuario para CPE (cwmp.auth): " cpe_user
    read -p "🔒 Contraseña para CPE (cwmp.auth): " cpe_pass
    read -p "🔌 Puerto HTTP para conexión ACS [por defecto: 7547]: " cpe_port
    cpe_port=${cpe_port:-7547}

    echo "🔧 5% - Actualizando sistema..."
    apt-get update -y && apt-get upgrade -y

    echo "📦 15% - Instalando dependencias base..."
    apt-get install -y curl sudo gnupg build-essential mongodb-org git nodejs npm

    echo "🔐 25% - Agregando soporte para libssl1.1 (requerido por MongoDB 4.4)..."
    echo "deb http://security.ubuntu.com/ubuntu impish-security main" | tee /etc/apt/sources.list.d/impish-security.list
    apt-get update || true
    apt-get install -y libssl1.1
    rm /etc/apt/sources.list.d/impish-security.list
    apt-get update || true

    echo "🧰 35% - Instalando MongoDB..."
    curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt-get update
    apt-get install -y mongodb-org
    systemctl enable --now mongod

    echo "🟢 45% - Instalando GenieACS desde NPM..."
    npm install -g genieacs@1.2.13

    echo "👤 55% - Creando usuario y directorios..."
    useradd --system --no-create-home --user-group genieacs
    mkdir -p /opt/genieacs/ext
    chown genieacs:genieacs /opt/genieacs/ext

    echo "⚙️ 65% - Configurando entorno..."
    mkdir -p /var/log/genieacs
    chown genieacs:genieacs /var/log/genieacs

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

    echo "🧠 75% - Configurando servicios systemd..."
    for svc in cwmp nbi fs ui; do
        cat <<EOL > /etc/systemd/system/genieacs-$svc.service
[Unit]
Description=GenieACS ${svc^^}
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$svc

[Install]
WantedBy=default.target
EOL
    done

    echo "🚀 85% - Habilitando y levantando servicios GenieACS..."
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable genieacs-{cwmp,nbi,fs,ui}
    systemctl start genieacs-{cwmp,nbi,fs,ui}

    echo "⏳ 90% - Esperando 30 segundos para aplicar configuración CWMP..."
    sleep 30

    echo "🔐 95% - Aplicando parámetros CWMP en MongoDB..."
    mongo genieacs --eval '
    db.configurations.updateOne(
      { _id: "cwmp.auth" },
      { $set: { _id: "cwmp.auth", value: { username: "'$cpe_user'", password: "'$cpe_pass'" } } },
      { upsert: true }
    );
    db.configurations.updateOne(
      { _id: "cwmp.connectionRequestAuth" },
      { $set: { _id: "cwmp.connectionRequestAuth", value: { username: "'$cpe_user'", password: "'$cpe_pass'" } } },
      { upsert: true }
    );
    db.configurations.updateOne(
      { _id: "cwmp.port" },
      { $set: { _id: "cwmp.port", value: '$cpe_port' } },
      { upsert: true }
    );'

    echo ""
    echo "🎉 100% - Instalación y configuración completa de GenieACS"
    echo "✅ Configuración CWMP aplicada"
    echo "✅ GenieACS accesible por defecto en http://<IP_SERVER>:3000 (usuario: admin / contraseña: admin)"
    echo ""
    echo "📢 Créditos: Steven Montero"
