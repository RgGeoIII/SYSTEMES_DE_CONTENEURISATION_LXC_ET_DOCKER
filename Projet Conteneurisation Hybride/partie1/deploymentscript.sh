#!/usr/bin/env bash
# Usage: ./deploy.sh nom_projet port_web
set -euo pipefail

PROJET="${1:?Usage: $0 nom_projet port_web}"
PORT="${2:?Usage: $0 nom_projet port_web}"

NET="${PROJET}-net"
WEB="${PROJET}-web"
DB="${PROJET}-db"

HOST_WEB_DIR="${HOME}/docker-data/${PROJET}"  
DB_VOL="${PROJET}_db"                         

echo "[*] Build des images"
docker build -t "${WEB}:img" ./web
docker build -t "${DB}:img"  ./db

echo "[*] Réseau Docker"
docker network inspect "${NET}" >/dev/null 2>&1 || docker network create "${NET}"

echo "[*] Dossiers/volumes"
mkdir -p "${HOST_WEB_DIR}"
docker volume inspect "${DB_VOL}" >/dev/null 2>&1 || docker volume create "${DB_VOL}" >/dev/null

echo "[*] (Re)lancement des conteneurs"
docker rm -f "${WEB}" "${DB}" >/dev/null 2>&1 || true

# Base de données (image locale)
docker run -d --name "${DB}" \
  --network "${NET}" \
  -v "${DB_VOL}:/var/lib/mysql" \
  -e DB_NAME="${PROJET}db" \
  -e DB_USER="${PROJET}user" \
  -e DB_PASSWORD="secretpass" \
  -e ROOT_PASSWORD="secretroot" \
  "${DB}:img"

# Web (image locale) - on publie le dossier hôte
docker run -d --name "${WEB}" \
  --network "${NET}" \
  -v "${HOST_WEB_DIR}:/var/www/html" \
  -p "${PORT}:80" \
  "${WEB}:img"

# Page d'accueil si vide
if [ -z "$(ls -A "${HOST_WEB_DIR}")" ]; then
  echo "Site ${PROJET} – Docker (Ubuntu 22.04 + Apache)" > "${HOST_WEB_DIR}/index.html"
fi

echo
echo "[OK] Web:  http://localhost:${PORT}/"
echo "[OK] DB:   conteneur '${DB}' (db: ${PROJET}db / user: ${PROJET}user / pass: secretpass)"
echo "[OK] Dossier publié (hôte): ${HOST_WEB_DIR}"
echo
echo "Tests rapides :"
echo "  docker exec -it ${DB} mariadb -uroot -psecretroot -e 'SHOW DATABASES;'"
echo "  curl -s http://localhost:${PORT}/ | head -n1"
