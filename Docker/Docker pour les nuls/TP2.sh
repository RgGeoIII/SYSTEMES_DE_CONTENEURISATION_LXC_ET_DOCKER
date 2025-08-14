#!/usr/bin/env bash
mkdir -p tp2-wp
cd tp2-wp

# Variables (tu peux modifier)
cat > .env <<'ENV'
MYSQL_ROOT_PASSWORD=changeme-root
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD=changeme-wp

# Pour t'aider lors de l'install WP (l'admin est créé depuis l'assistant web)
WORDPRESS_TABLE_PREFIX=wp_
ENV

# Compose
cat > docker-compose.yml <<'YAML'
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MARIADB_DATABASE: ${MYSQL_DATABASE}
      MARIADB_USER: ${MYSQL_USER}
      MARIADB_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - wpnet

  wordpress:
    image: wordpress:6.5-apache
    depends_on:
      - db
    restart: unless-stopped
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: ${MYSQL_USER}
      WORDPRESS_DB_PASSWORD: ${MYSQL_PASSWORD}
      WORDPRESS_DB_NAME: ${MYSQL_DATABASE}
      WORDPRESS_TABLE_PREFIX: ${WORDPRESS_TABLE_PREFIX}
    ports:
      - "8080:80"           # Accès http://localhost:8080
    volumes:
      - wp_data:/var/www/html
    networks:
      - wpnet

volumes:
  db_data:
  wp_data:

networks:
  wpnet:
    driver: bridge
YAML
