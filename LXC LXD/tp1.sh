#!/usr/bin/env bash
set -e

echo "==> Init LXD (minimal)"
sudo lxd init --minimal || true

echo "==> Réseaux"
lxc network create lxcbr-test ipv4.address=10.10.10.1/24 ipv4.nat=false ipv4.dhcp=true ipv6.address=none || true
lxc network create lxdbr0     ipv4.address=10.0.0.1/24    ipv4.nat=true  ipv6.address=none || true
# (tu actives le NAT sur lxcbr-test ici)
lxc network set lxcbr-test ipv4.nat true

echo "==> Conteneurs"
lxc launch images:ubuntu/22.04 srv-web  -n lxcbr-test
lxc launch images:ubuntu/22.04 srv-db   -n lxcbr-test
lxc launch images:ubuntu/22.04 cli-test -n lxcbr-test

echo "==> IP statiques + limites"
lxc config device set srv-web  eth0 ipv4.address 10.10.10.10
lxc config set srv-web  limits.memory=512MiB limits.cpu=1

lxc config device set srv-db   eth0 ipv4.address 10.10.10.20
lxc config set srv-db   limits.memory=1GiB   limits.cpu=2

lxc config device set cli-test eth0 ipv4.address 10.10.10.30
lxc config set cli-test limits.memory=256MiB limits.cpu=1

echo "==> Internet pour srv-web via lxdbr0"
lxc config device add srv-web ext0 nic network=lxdbr0 name=eth1 || true
lxc restart srv-web

echo "==> Installation services"
# Web
lxc exec srv-web -- bash -c 'apt-get update && apt-get install -y apache2 mariadb-client curl'
lxc exec srv-web -- bash -c 'echo "Serveur Web LXD – TP" > /var/www/html/index.html'

# DB
lxc exec srv-db -- bash -c 'apt-get update && apt-get install -y mariadb-server'
lxc exec srv-db -- bash -c "sed -i 's/^bind-address.*/bind-address = 10.10.10.20/' /etc/mysql/mariadb.conf.d/50-server.cnf || echo 'bind-address = 10.10.10.20' >> /etc/mysql/mariadb.conf.d/50-server.cnf"
lxc exec srv-db -- systemctl restart mariadb
lxc exec srv-db -- mariadb -e "CREATE USER 'etudiant'@'10.10.10.10' IDENTIFIED BY 'password'; GRANT ALL PRIVILEGES ON *.* TO 'etudiant'@'10.10.10.10'; FLUSH PRIVILEGES;"

echo "==> Tests (cli-test -> web/db)"
lxc exec cli-test -- ping -c2 10.10.10.10
lxc exec cli-test -- ping -c2 10.10.10.20
# Si curl non installé sur cli-test, cette ligne peut échouer: c'est attendu
lxc exec cli-test -- sh -lc 'curl -s http://10.10.10.10 | head -n1 || echo "curl non installé sur cli-test (ok)"'

echo "==> Test (srv-web -> DB)"
# Attention: option -p de MariaDB = -ppassword (sans espace)
lxc exec srv-web -- mariadb -h 10.10.10.20 -u etudiant -ppassword -e "SELECT 1;"

echo "==> Terminé."
