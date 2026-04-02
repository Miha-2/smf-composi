# Traefik

Reverse proxy z avtomatskimi Let's Encrypt certifikati.

## Namestitev

```bash
# 1. Ustvari zunanjo docker mrežo (enkrat na server)
docker network create traefik

# 2. Kopiraj .env.example v .env in nastavi vrednosti
cp .env.example .env

# 3. Ustvari acme.json z ustreznimi dovoljenji
mkdir -p letsencrypt
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json

# 4. Zaženi
docker compose up -d
```
