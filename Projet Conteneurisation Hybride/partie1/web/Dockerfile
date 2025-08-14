FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y apache2 \
 && rm -rf /var/lib/apt/lists/*

# Apache écoute en 80
EXPOSE 80

# Garde Apache au premier plan
CMD ["apachectl", "-D", "FOREGROUND"]
