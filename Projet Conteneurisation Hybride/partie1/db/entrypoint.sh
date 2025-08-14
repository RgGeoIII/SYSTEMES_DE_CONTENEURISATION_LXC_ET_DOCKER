#!/usr/bin/env bash
set -e

# Variables
DB_NAME="${DB_NAME:-appdb}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-secretpass}"
ROOT_PASSWORD="${ROOT_PASSWORD:-secretroot}"

# Init du datadir si nécessaire
if [ ! -d /var/lib/mysql/mysql ]; then
  echo "[db] Initialisation du datadir..."
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null
fi

# Démarre MariaDB en arrière-plan le temps de configurer
mysqld_safe --datadir=/var/lib/mysql &
PID=$!

# Attendre que le serveur réponde
echo "[db] Attente du socket MariaDB..."
for i in $(seq 1 30); do
  if mariadb -uroot -e "SELECT 1" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Set mot de passe root et créer DB/utilisateur
echo "[db] Configuration utilisateurs et bases..."
mariadb -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}'; FLUSH PRIVILEGES;" || true
mariadb -uroot -p"${ROOT_PASSWORD}" -e \
  "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
   CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
   GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
   FLUSH PRIVILEGES;"

# Arrêt propre du serveur temporaire
mysqladmin -uroot -p"${ROOT_PASSWORD}" shutdown

# Relance en avant-plan
echo "[db] Démarrage final..."
exec mysqld_safe --datadir=/var/lib/mysql
