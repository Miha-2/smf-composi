# smf-composi

Docker Compose setup za hitro postavljanje Traefik + Mautic instanc na Hetzner serverjih.

## Hitra namestitev

### Nov server (Docker + Traefik + Mautic)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Miha-2/smf-composi/main/new-server-setup.sh)
```

### Nova Mautic instanca na obstoječem serverju
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Miha-2/smf-composi/main/new-mautic-instance.sh)
```

## Struktura repota

```
smf-composi/
├── traefik/                  ← Traefik reverse proxy z Let's Encrypt
│   ├── docker-compose.yml
│   └── .env.example
├── mautic/                   ← Mautic (osnova + opcijski backup)
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── .mautic_env.example
│   ├── apache-https.conf
│   ├── borgmatic/            ← BorgBackup config (opcijsko)
│   │   ├── config.yaml
│   │   ├── config-media.yaml
│   │   └── crontab.txt
│   └── README.md
├── new-server-setup.sh       ← Skripta za nov server
├── new-mautic-instance.sh    ← Skripta za novo instanco
├── .gitignore
└── README.md
```

## Kaj je vključeno

**Traefik** — reverse proxy ki avtomatsko pridobi Let's Encrypt certifikate za vse Mautic instance.

**Mautic** — marketing automation platforma s štirimi containerji: `mautic_web`, `mautic_cron`, `mautic_worker` in `db` (MariaDB 11.4). Opcijsko vključuje `backup` container za šifrirane backupe na Hetzner Storage Box.

**Backup (opcijsko)** — BorgBackup preko SSH na Hetzner Storage Box:
- 3x na dan: DB dump + config
- Enkrat na 3 dni: DB dump + config + media

## Več instanc na istem serverju

Vsaka Mautic instanca mora imeti unikatni `COMPOSE_PROJECT_NAME` v `.env`. Skripti to preverita interaktivno.

## Več informacij

Glej `mautic/README.md` za podrobna navodila.
