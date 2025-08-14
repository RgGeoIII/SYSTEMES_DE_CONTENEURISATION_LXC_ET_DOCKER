#!/usr/bin/env bash
mkdir -p tp1-static/site
cat > tp1-static/site/index.html <<'HTML'
<!doctype html><meta charset="utf-8">
<title>TP1 Nginx</title>
<h1>Bonjour 👋 — site statique</h1>
<p>Servi par Nginx dans un container.</p>
HTML

cat > tp1-static/Dockerfile <<'DOCKER'
FROM nginx:alpine
# On remplace la page par défaut par la nôtre
COPY site/ /usr/share/nginx/html/
EXPOSE 80
DOCKER

# Build + run
cd tp1-static
docker build -t tp1-nginx:latest .
docker run -d --name tp1-nginx -p 8080:80 tp1-nginx:latest

# Test
curl -s http://localhost:8080 | head -n1