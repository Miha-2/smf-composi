#!/bin/bash
set -e

GITHUB_RAW="https://raw.githubusercontent.com/Miha-2/smf-composi/main"
BASE_DIR="/root/server"

# ─────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════╗"
echo "║     Nov server: Traefik + Mautic     ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Vnos parametrov: Traefik ─────────────
echo "── Traefik nastavitve ──"
read -p "Email za Let's Encrypt certifikate: " ACME_EMAIL

echo ""
echo "── Mautic nastavitve ──"
read -p "Ime instance (npr. mautic-client1, mora biti unikatno): " PROJECT_NAME
read -p "Domena (npr. mautic.example.com): " DOMAIN
read -p "Časovni pas [Europe/Ljubljana]: " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Ljubljana}
read -p "Mautic verzija [6.0.4]: " MAUTIC_VERSION
MAUTIC_VERSION=${MAUTIC_VERSION:-6.0.4}

echo ""
echo "── Nastavitve baze ──"
read -p "Ime baze [mautic_db]: " MYSQL_DATABASE
MYSQL_DATABASE=${MYSQL_DATABASE:-mautic_db}
read -p "Uporabnik baze [mautic_db_user]: " MYSQL_USER
MYSQL_USER=${MYSQL_USER:-mautic_db_user}
read -s -p "Geslo za DB uporabnika: " MYSQL_PASSWORD; echo ""
read -s -p "Root geslo za DB: " MYSQL_ROOT_PASSWORD; echo ""

# ── Docker install ────────────────────────
echo ""
echo "→ Preverjam Docker..."
if ! command -v docker &> /dev/null; then
    echo "→ Docker ni nameščen, nameščam..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo "✓ Docker nameščen."
else
    echo "✓ Docker že nameščen ($(docker --version))."
fi

# ── Traefik network ───────────────────────
echo "→ Ustvarjam traefik mrežo..."
docker network create traefik 2>/dev/null && echo "✓ Mreža ustvarjena." || echo "✓ Mreža že obstaja."

# ── Traefik setup ─────────────────────────
TRAEFIK_DIR="$BASE_DIR/traefik"
echo "→ Ustvarjam mapo: $TRAEFIK_DIR"
mkdir -p "$TRAEFIK_DIR/letsencrypt"

cd "$TRAEFIK_DIR"
echo "→ Prenašam Traefik docker-compose.yml iz GitHub..."
curl -fsSL "$GITHUB_RAW/traefik/docker-compose.yml" -o docker-compose.yml

echo "→ Ustvarjam .env..."
cat > .env <<EOF
ACME_EMAIL=${ACME_EMAIL}
EOF

echo "→ Pripravljam acme.json..."
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json

echo "→ Zaganjam Traefik..."
docker compose up -d
echo "✓ Traefik zagnan."

# ── Mautic setup ──────────────────────────
INSTANCE_DIR="$BASE_DIR/$PROJECT_NAME/mautic"
echo ""
echo "→ Ustvarjam mapo: $INSTANCE_DIR"
mkdir -p "$INSTANCE_DIR"
cd "$INSTANCE_DIR"

echo "→ Prenašam Mautic datoteke iz GitHub..."
curl -fsSL "$GITHUB_RAW/mautic/docker-compose.yml" -o docker-compose.yml
curl -fsSL "$GITHUB_RAW/mautic/apache-https.conf" -o apache-https.conf
curl -fsSL "$GITHUB_RAW/mautic/.mautic_env.example" -o .mautic_env.example

mkdir -p borgmatic/ssh
curl -fsSL "$GITHUB_RAW/mautic/borgmatic/config.yaml" -o borgmatic/config.yaml
curl -fsSL "$GITHUB_RAW/mautic/borgmatic/config-media.yaml" -o borgmatic/config-media.yaml
curl -fsSL "$GITHUB_RAW/mautic/borgmatic/crontab.txt" -o borgmatic/crontab.txt

echo "→ Ustvarjam .env..."
cat > .env <<EOF
COMPOSE_PROJECT_NAME=${PROJECT_NAME}
DOMAIN=${DOMAIN}
TIMEZONE=${TIMEZONE}
MAUTIC_VERSION=${MAUTIC_VERSION}

# --- MariaDB ---
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
EOF

echo "→ Ustvarjam .mautic_env..."
cat > .mautic_env <<EOF
MAUTIC_DB_HOST=db
MAUTIC_DB_PORT=3306
MAUTIC_DB_NAME=${MYSQL_DATABASE}
MAUTIC_DB_USER=${MYSQL_USER}
MAUTIC_DB_PASSWORD=${MYSQL_PASSWORD}

MAUTIC_MESSENGER_DSN_EMAIL=doctrine://default
MAUTIC_MESSENGER_DSN_HIT=doctrine://default

DOCKER_MAUTIC_RUN_MIGRATIONS=false
DOCKER_MAUTIC_LOAD_TEST_DATA=false

TRUSTED_PROXIES=0.0.0.0/0
TRUSTED_HEADERS=x-forwarded-for,x-forwarded-host,x-forwarded-proto,x-forwarded-port,x-forwarded-prefix
EOF

# ── Backup (opcijsko) ────────────────────
echo ""
read -p "Ali želiš aktivirati backupe na Hetzner Storage Box? [d/N]: " SETUP_BACKUP
if [[ "$SETUP_BACKUP" =~ ^[dD]$ ]]; then
    echo ""
    echo "── Hetzner Storage Box ──"
    read -p "Storage Box uporabnik (npr. u123456): " STORAGE_BOX_USER
    read -p "Storage Box host (npr. u123456.your-storagebox.de): " STORAGE_BOX_HOST
    read -s -p "Borg passphrase (dolgo naključno geslo — shrani na varno!): " BORG_PASSPHRASE; echo ""

    # Dodaj backup spremenljivke v .env
    cat >> .env <<EOF

# --- Hetzner Storage Box ---
STORAGE_BOX_USER=${STORAGE_BOX_USER}
STORAGE_BOX_HOST=${STORAGE_BOX_HOST}

# --- BorgBackup ---
BORG_PASSPHRASE=${BORG_PASSPHRASE}
EOF

    # Ustvari SSH ključ
    echo "→ Ustvarjam SSH ključ za Storage Box..."
    ssh-keygen -t ed25519 -f borgmatic/ssh/hetzner_storage -N ""
    chmod 700 borgmatic/ssh
    chmod 600 borgmatic/ssh/hetzner_storage

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ⚠  DODAJ JAVNI KLJUČ V HETZNER ROBOT                      ║"
    echo "║  Storage Box → SSH Keys → Add key                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    cat borgmatic/ssh/hetzner_storage.pub
    echo ""
    read -p "Ko dodaš ključ, pritisni ENTER za nadaljevanje..."

    # Zaženi vse skupaj
    echo "→ Zaganjam Mautic..."
    docker compose up -d

    # Inicializiraj Borg repozitorij
    echo "→ Inicializiram Borg repozitorij..."
    docker compose run --rm backup \
        borg init --encryption=repokey \
        "ssh://${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}:23/./borg/${PROJECT_NAME}"
    docker compose run --rm backup \
        borg init --encryption=repokey \
        "ssh://${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}:23/./borg/${PROJECT_NAME}-media"

    echo "✓ Backupi aktivirani."
else
    # Zaženi brez backup containerja
    echo "→ Zaganjam Mautic..."
    docker compose up -d --scale backup=0
fi

# ── DNS reminder ─────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ⚠  NE POZABI: DNS NASTAVITEV                               ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
SERVER_IP=$(curl -4 -fsSL ifconfig.me 2>/dev/null || echo "???")
printf  "║  Dodaj A zapis:  %-20s  →  %-15s  ║\n" "$DOMAIN" "$SERVER_IP"
echo "║                                                              ║"
echo "║  Brez tega Let's Encrypt certifikat ne bo deloval!          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "✓ Server postavljen!"
echo "  Traefik:  /root/server/traefik"
echo "  Mautic:   $INSTANCE_DIR"
echo ""
echo "  Mautic bo dostopen na https://$DOMAIN"
echo "  (takoj po propagaciji DNS in izdaji certifikata)"
echo ""
