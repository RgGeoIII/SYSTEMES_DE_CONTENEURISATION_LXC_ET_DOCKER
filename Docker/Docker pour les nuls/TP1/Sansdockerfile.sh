#!/usr/bin/env bash
mkdir -p tp1-nodf/site
cat > tp1-nodf/site/index.html <<'HTML'
<!doctype html><meta charset="utf-8">
<title>TP1 Nginx (volume)</title>
<h1>Site statique monté en volume</h1>
HTML

# Lancer Nginx en montant le dossier local comme volume
docker run -d --name tp1-nginx-vol \
  -p 8081:80 \
  -v "$PWD/tp1-nodf/site:/usr/share/nginx/html:ro" \
  nginx:alpine

# Test
curl -s http://localhost:8081 | head -n1
