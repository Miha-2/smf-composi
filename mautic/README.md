# Mautic

Marketing automation platforma, postavljena z Docker Compose in Traefik reverse proxyjem.

Opcijsko vključuje `backup` container za avtomatske šifrirane backupe na Hetzner Storage Box (BorgBackup):
- **3x na dan** (2:00, 10:00, 18:00) — DB dump + config
- **Enkrat na 3 dni** (3:00) — DB dump + config + media

## Predpogoji

- Traefik mora biti zagnan (zunanja `traefik` mreža mora obstajati)
- DNS A zapis mora kazati na server

## Hitra namestitev (priporočeno)

```bash
# Nov server (Docker + Traefik + Mautic)
bash <(curl -fsSL https://raw.githubusercontent.com/Miha-2/smf-composi/main/new-server-setup.sh)

# Nova instanca na obstoječem serverju
bash <(curl -fsSL https://raw.githubusercontent.com/Miha-2/smf-composi/main/new-mautic-instance.sh)
```

## Ročna namestitev

```bash
# 1. Kopiraj env datoteke in nastavi vrednosti
cp .env.example .env
cp .mautic_env.example .mautic_env

# 2. Ob PRVI namestitvi nastavi v .mautic_env:
#    DOCKER_MAUTIC_RUN_MIGRATIONS=true
#    Po uspešni namestitvi vrni nazaj na false in docker compose up -d

# 3. Zaženi
docker compose up -d
```

## Namestitev z backup containerjem

```bash
# 1. Kopiraj env datoteke in nastavi vrednosti (vključno s Storage Box in Borg)
cp .env.example .env
cp .mautic_env.example .mautic_env

# 2. Ustvari SSH ključ za Hetzner Storage Box
ssh-keygen -t ed25519 -f borgmatic/ssh/hetzner_storage -N ""
chmod 700 borgmatic/ssh
chmod 600 borgmatic/ssh/hetzner_storage

# 3. Dodaj javni ključ v Hetzner Robot: Storage Box > SSH Keys
cat borgmatic/ssh/hetzner_storage.pub

# 4. Inicializiraj Borg repozitorij (samo ob prvi namestitvi)
docker compose run --rm backup \
  borg init --encryption=repokey \
  ssh://${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}:23/./borg/${COMPOSE_PROJECT_NAME}

docker compose run --rm backup \
  borg init --encryption=repokey \
  ssh://${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}:23/./borg/${COMPOSE_PROJECT_NAME}-media

# 5. Zaženi
docker compose up -d
```

## Backup ukazi

```bash
# Ročni backup
docker compose exec backup borgmatic --verbosity 1

# Seznam arhivov
docker compose exec backup borgmatic list

# Obnovi najnovejši backup
docker compose exec backup borgmatic extract --archive latest --destination /restore
```

## Več instanc na istem serverju

Za vsako instanco nastavi unikatni `COMPOSE_PROJECT_NAME` v `.env`. Ta vrednost se uporablja
kot prefiks za vse Traefik routerje, service in middleware, ter kot ime interne docker mreže.

## Traefik labeli (za referenco)

| Label | Namen |
|-------|--------|
| `{name}-svc` | Traefik service (port 80 → mautic_web) |
| `{name}-secure` | HTTPS router z Let's Encrypt |
| `{name}-headers` | Middleware za X-Forwarded-* headerje |

## ⚠ BORG_PASSPHRASE

Brez `BORG_PASSPHRASE` backupov **ne moreš obnoviti**. Shrani jo na varno mesto (password manager) — ločeno od serverja!

## Datotečna struktura

```
mautic/
├── docker-compose.yml
├── .env.example          ← kopiraj v .env
├── .mautic_env.example   ← kopiraj v .mautic_env
├── apache-https.conf
├── borgmatic/
│   ├── config.yaml       ← DB + config (3x/dan)
│   ├── config-media.yaml ← DB + config + media (vsake 3 dni)
│   ├── crontab.txt
│   └── ssh/              ← sem daš SSH ključ (v .gitignore!)
└── mautic/               ← ustvarjeno samodejno ob zagonu
    ├── config/
    ├── logs/
    ├── run/
    └── media/
```
