#!/usr/bin/env bash
# Usage: ./lxd_easy.sh nom_projet
# Exemple: ./lxd_easy.sh demo

set -e

# -------- paramètres --------
PROJET="${1:-}"
if [ -z "$PROJET" ]; then
  echo "Usage: $0 nom_projet"
  exit 1
fi

# LXD: noms en minuscules et tirets
PROJET_CLEAN=$(echo "$PROJET" | tr '[:upper:]' '[:lower:]' | tr '_' '-')

WEB="${PROJET_CLEAN}-web"
DB="${PROJET_CLEAN}-db"
WEBROOT="/srv/projects/${PROJET_CLEAN}"

echo "[1/6] Préparation du dossier web: ${WEBROOT}"
sudo mkdir -p "$WEBROOT"
if [ ! -f "$WEBROOT/index.html" ]; then
  echo "<h1>Site ${PROJET} via LXD</h1>" | sudo tee "$WEBROOT/index.html" >/dev/null
fi

echo "[2/6] Création des conteneurs LXD (${WEB}, ${DB})"
# (re)création propre si ça existe déjà
sudo lxc delete -f "$WEB" 2>/dev/null || true
sudo lxc delete -f "$DB"  2>/dev/null || true

# images Ubuntu 24.04
sudo lxc launch ubuntu:24.04 "$WEB"
sudo lxc launch ubuntu:24.04 "$DB"

# petite fonction pour récupérer l'IP v4 du conteneur
get_ip() { sudo lxc list "$1" -c 4 --format csv | cut -d' ' -f1; }

echo "[3/6] Montage du dossier web dans ${WEB}"
sudo lxc config device add "$WEB" webroot disk source="$WEBROOT" path=/var/www/html

echo "[4/6] Installation des services"
sudo lxc exec "$WEB" -- bash -lc "apt-get update && apt-get install -y apache2 && a2enmod rewrite && systemctl enable --now apache2"
sudo lxc exec "$DB"  -- bash -lc "apt-get update && apt-get install -y mariadb-server && \
  (sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf || \
   echo -e '[mysqld]\nbind-address = 0.0.0.0' > /etc/mysql/mariadb.conf.d/50-server.cnf) && \
  systemctl restart mariadb"

WEB_IP="$(get_ip "$WEB")"
DB_IP="$(get_ip "$DB")"

echo "[5/6] Sécurisation: autoriser seulement ${WEB_IP} vers ${DB} (port 3306)"
sudo lxc exec "$DB" -- bash -lc "
iptables -F INPUT
iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp -s ${WEB_IP} --dport 3306 -j ACCEPT
"

echo "[6/6] Compte MariaDB pour l'app"
sudo lxc exec "$DB" -- bash -lc "mysql -uroot -e \"
CREATE USER IF NOT EXISTS 'web'@'${WEB_IP}' IDENTIFIED BY 'pwd';
GRANT ALL PRIVILEGES ON *.* TO 'web'@'${WEB_IP}';
FLUSH PRIVILEGES;\""

echo
echo "================= RÉCAP ================="
echo " Projet        : ${PROJET}"
echo " Web container : ${WEB} (IP: ${WEB_IP})"
echo " DB container  : ${DB}  (IP: ${DB_IP})"
echo " Webroot hôte  : ${WEBROOT}"
echo " DB User       : web@${WEB_IP}  (mdp: pwd)"
echo " Test HTTP     : curl -I http://${WEB_IP}/"
echo " Test MySQL    : lxc exec ${WEB} -- bash -lc \"apt-get update && apt-get install -y mariadb-client && mysql -h ${DB_IP} -u web -ppwd -e 'SELECT VERSION();'\""
echo "=========================================="