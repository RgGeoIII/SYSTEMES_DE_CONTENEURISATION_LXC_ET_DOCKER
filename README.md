# 🐳 SYSTEMES DE CONTENEURISATION LXC ET DOCKER

## 📚 Objectif

Mettre en place une **infrastructure hybride** combinant :
- **LXD** pour la virtualisation légère de services web
- **Docker** pour l'orchestration et le déploiement d’applications containerisées
- Partage de fichiers entre l’hôte et les conteneurs
- Configuration réseau avancée entre les services

---

## 🧱 Architecture

### 🖥️ 3 Machines Virtuelles (VM)

| VM                         | Rôle                | Adresse IP    |
|----------------------------|---------------------|---------------|
| `2501 (LXC)`               | LXC                 | `192.168.4.5` |
| `2302 (Dockerpourlesnuls)` | Docker              | `192.168.4.6` |

---

## 📦 Technologies utilisées

- **LXD** (Linux Containers)
- **Docker** & **Docker Compose**
- **Apache / Nginx**
- **MySQL / MariaDB**
- **Node.js / PHP**
- **Bridge réseau LXD**
- **Bind mount** (partage hôte → conteneur)

---

## 🔐 Sécurité

- 🔒 Isolation réseau entre conteneurs
- 🔐 Accès restreint via firewall UFW
- 🔐 Volumes Docker sécurisés
- 🔐 Gestion des droits UNIX sur le dossier partagé
- 🔐 Limitation des privilèges root dans les conteneurs

---

## 📂 Contenu du Projet
```plaintext
Projet Conteneurisation Hybride/
├── partie1/       → TP sur la simulation d’un ransomware
│   ├── db/
│   │   ├── Dockerfile
│   │   └── entrypoint.sh
│   ├── web/
│   │   └── Dockerfile
│   └── deploymentscript.sh
│
├── partie2/            
│   └── deploymentscript.sh
│
└── site/
```

---

## 🚀 Projet Conteneurisation Hybride


#### 1. 🛠️ Partie1

```bash
chmod +x deploymentscript.sh
./deploymentscript.sh
```

---

#### 1. 🛠️ Partie2

Mise en place d'un ensemble Apache (Httpd) + MariaDB avec LXD

1. Préparation de l'environement
```bash
sudo apt update -y && sudo apt upgrade -y
sudo snap install lxd
sudo lxt init
```

2. Création des conteners
```bash
#Serveur Web
sudo lxc lauch images:ubuntu/24.04 web1

#Serveur base de données
sudo lxc lauch images:ubuntu/24.04 db1
```

3. Installation et configuration d'apache (httpd)
```bash
# Installer Apache
sudo lxc exec web1 -- bash -lc "apt update && apt install -y apache2"

# Activer le module rewrite et démarrer Apache
sudo lxc exec web1 -- bash -lc "a2enmod rewrite && systemctl enable --now apache2"
```

4. Installation et configuration de MariaDB
```bash
# Installer MariaDB
sudo lxc exec db1 -- bash -lc "apt update && apt install -y mariadb-server"

# Autoriser les connexions distantes
sudo lxc exec db1 -- bash -lc \
'sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf && systemctl restart mariadb'
```

5. Création d’un utilisateur MariaDB pour le serveur web
```bash
#Récupérer l’adresse IP du conteneur web1 :
WEB1_IP=$(lxc list web1 -c 4 --format csv | cut -d" " -f1)

#Créer l’utilisateur MariaDB et lui donner les droits :
sudo lxc exec db1 -- bash -lc "mysql -uroot -e \"
CREATE USER IF NOT EXISTS 'web'@'$WEB1_IP' IDENTIFIED BY 'pwd';
GRANT ALL PRIVILEGES ON *.* TO 'web'@'$WEB1_IP';
FLUSH PRIVILEGES;\""

```

6. Test de connexion

```bash
# Installer le client MariaDB sur le conteneur web1 et tester :
sudo lxc exec web1 -- bash -lc "apt install -y mariadb-client"

# Récupérer l’IP du conteneur db1
DB1_IP=$(lxc list db1 -c 4 --format csv | cut -d" " -f1)

# Tester la connexion
sudo lxc exec web1 -- bash -lc "mysql -h $DB1_IP -u web -ppwd -e 'SELECT VERSION();'"
```

Procédure de migration des infrastructures existantes (Docker → LXD)

1. Préparation
```bash
sudo docker volume ls
```
2. Migration de la base de données (Maria DB)

2.1 Démarrage temporaire du conteneur Docker

```bash
#On démarre un conteneur MariaDB temporaire, en utilisant le volume de données existant :
sudo docker rm -f tmp_db 2>/dev/null || true
sudo docker run -d --name tmp_db --network webnet \
  -e MARIADB_ROOT_PASSWORD=root \
  -v tp_hybride_db_data:/var/lib/mysql \
  mariadb:10.11 --innodb-force-recovery=1
```

2.2 Démmarage temporaire du conteneur Docker
```bash
sudo docker exec tmp_db bash -lc \
'for i in {1..90}; do mysqladmin ping -uroot -p"$MARIADB_ROOT_PASSWORD" --silent && exit 0; sleep 1; done; exit 1'
```

2.3 Export et import direct vers LXD
```bash
#On transfère directement le dump vers le conteneur LXD db1 :
sudo docker exec -i tmp_db bash -lc \
  'mysqldump -uroot -p"$MARIADB_ROOT_PASSWORD" --all-databases --single-transaction --quick --force' \
sudo lxc exec db1 -- bash -lc 'mysql -uroot'
```
2.4 Export et import direct vers LXD
```bash
sudo docker rm -f tmp_db
```

3. Migration des fichiers Web

```bash
#Créer un répertoire de migration sur l’hôte
sudo mkdir -p /srv/migration/tp_hybride/web
#Copier les fichiers web depuis l’ancien environnement
sudo rsync -a ~/tp_hybride/site_web/ /srv/migration/tp_hybride/web/
#Créer le répertoire de projet pour LXD
sudo mkdir -p /srv/projects/tp_hybride
sudo rsync -a /srv/migration/tp_hybride/web/ /srv/projects/tp_hybride/

```

4. Montage du répertoire dans LXD

```bash
sudo lxc config device add web1 webroot disk source=/srv/projects/tp_hybride path=/var/www/html
```
5. Tests Finaux

```bash
#Depuis web1, vérifier que les fichiers sont accessibles via Apache.
#Depuis web1, vérifier la connexion à db1 :
DB1_IP=$(lxc list db1 -c 4 --format csv | cut -d" " -f1)
sudo lxc exec web1 -- bash -lc "mysql -h $DB1_IP -u web -ppwd -e 'SHOW DATABASES
```
Mise en place d’un dossier partagé entre la machine hôte et le conteneur web

Pour chaque projet déployé, un répertoire partagé est automatiquement créé sur la machine hôte et monté dans le conteneur web.
Cela permet que tout fichier ajouté ou modifié sur l’hôte soit directement disponible dans le site web servi par Apache dans le conteneur.
Procédure intégrée dans le script :
1.	Création d’un répertoire sur l’hôte :

```bash
sudo mkdir -p /srv/projects/$PROJET
```

2.	Montage du dossier dans le conteneur web :

```bash
lxc config device add "$WEB_CTN" webroot disk source="/srv/projects/$PROJET" path=/var/www/html
```

•	source : chemin du dossier sur l’hôte
•	path : emplacement du dossier dans le conteneur (/var/www/html), qui est le répertoire par défaut utilisé par Apache.
Avantage :
•	Permet une publication directe des fichiers web depuis l’hôte.
•	Facilite les mises à jour sans redéploiement complet du conteneur.
Vérification :
•	Sur l’hôte :
```bash
ls /srv/projects/nom_projet
```

•	Sur le conteneur :
```bash
lxc exec nom_projet-web -- ls /var/www/html
```

Les deux emplacements doivent afficher le même contenu.


```bash
chmod +x deploymentscript.sh
./deploymentscript.sh
```

---

## 🤖 Auteur

**Geoffrey ROUVEL**  
Étudiant à l’IPSSI | Administrateur Systèmes & Réseaux  
GitHub : [@RgGeolll](https://github.com/RgGeolll)

---

## 🤖 Collaborateur

**Xavier ROCHER**  
Étudiant à l’IPSSI | Administrateur Systèmes & Réseaux

**Ludovic MANGENOT**  
Étudiant à l’IPSSI | Administrateur Systèmes & Réseaux

---

🎓 Projet réalisé dans le cadre du module **SYSTEMES DE CONTENEURISATION LXC ET DOCKER
** – Mastère Cybersécurité & Cloudcomputing.
