# Mautic

Marketing automation platforma, postavljena z Docker Compose in Traefik reverse proxyjem.

## Predpogoji

- Traefik mora biti zagnan (zunanja `traefik` mreža mora obstajati)
- DNS A zapis za domeno mora kazati na server

## Namestitev

```bash
# 1. Kopiraj .env.example v .env in nastavi vrednosti
cp .env.example .env

# 2. Kopiraj .mautic_env.example v .mautic_env in nastavi vrednosti
#    (gesla morajo biti enaka kot v .env!)
cp .mautic_env.example .mautic_env

# 3. Ob PRVI namestitvi nastavi zastavice v .env:
#    DOCKER_MAUTIC_RUN_MIGRATIONS=true

# 4. Zaženi
docker compose up -d

# 5. Po uspešni namestitvi vrni zastavice nazaj:
#    DOCKER_MAUTIC_RUN_MIGRATIONS=false
#    docker compose up -d
```

## Več instanc na istem serverju

Za vsako instanco nastavi unikatni `COMPOSE_PROJECT_NAME` v `.env`.
Ta vrednost se uporablja kot prefiks za vse Traefik routerje, service in middleware,
ter kot ime interne docker mreže — s tem se izognemo konfliktom med instancami.

## Traefik labeli (za referenco)

| Label | Namen |
|-------|--------|
| `{name}-svc` | Traefik service (port 80 → mautic_web) |
| `{name}-secure` | HTTPS router z Let's Encrypt |
| `{name}-headers` | Middleware za X-Forwarded-* headerje |

## Datotečna struktura

```
mautic/
├── docker-compose.yml
├── .env.example          ← kopiraj v .env
├── .mautic_env.example   ← kopiraj v .mautic_env
├── apache-https.conf     ← ne spreminjaj
├── php-timezone.ini      ← nastavi timezone po potrebi
└── mautic/               ← ustvarjeno samodejno ob zagonu
    ├── config/
    ├── logs/
    ├── run/
    └── media/
```
