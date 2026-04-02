#!/bin/bash
set -e

GITHUB_RAW="https://raw.githubusercontent.com/Miha-2/smf-composi/main"
BASE_DIR="/root/server"

# ─────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════╗"
echo "║     Nova Mautic instanca             ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Vnos parametrov ──────────────────────
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

# ── Ustvari mapo ─────────────────────────
INSTANCE_DIR="$BASE_DIR/$PROJECT_NAME/mautic"
echo ""
echo "→ Ustvarjam mapo: $INSTANCE_DIR"
mkdir -p "$INSTANCE_DIR"
cd "$INSTANCE_DIR"

# ── Prenesi datoteke iz GitHub ────────────
echo "→ Prenašam datoteke iz GitHub..."
curl -fsSL "$GITHUB_RAW/mautic/docker-compose.yml" -o docker-compose.yml
curl -fsSL "$GITHUB_RAW/mautic/apache-https.conf" -o apache-https.conf
curl -fsSL "$GITHUB_RAW/mautic/.mautic_env.example" -o .mautic_env.example

mkdir -p borgmatic/ssh
curl -fsSL "$GITHUB_RAW/mautic/borgmatic/config.yaml" -o borgmatic/config.yaml
curl -fsSL "$GITHUB_RAW/mautic/borgmatic/config-media.yaml" -o borgmatic/config-media.yaml
curl -fsSL "$GITHUB_RAW/mautic/borgmatic/crontab.txt" -o borgmatic/crontab.txt

# ── Ustvari .env ──────────────────────────
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

# ── Ustvari .mautic_env ───────────────────
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

# ── Zaženi ───────────────────────────────
echo ""
echo "→ Zaganjam kontejnerje..."
docker compose up -d

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
echo "✓ Instanca '$PROJECT_NAME' je zagotovljena na https://$DOMAIN"
echo "  (dostopna bo takoj po propagaciji DNS in izdaji certifikata)"
echo ""
