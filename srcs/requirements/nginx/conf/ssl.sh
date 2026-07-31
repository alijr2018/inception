#!/bin/bash
set -e

SSL_DIR=/etc/nginx/ssl
mkdir -p "$SSL_DIR"

if [ ! -f "$SSL_DIR/nginx.key" ] || [ ! -f "$SSL_DIR/nginx.crt" ]; then
    openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
        -keyout "$SSL_DIR/nginx.key" \
        -out "$SSL_DIR/nginx.crt" \
        -subj "/C=MA/ST=Casablanca/L=Casablanca/O=42/CN=${DOMAIN_NAME}" >/dev/null 2>&1
fi

envsubst '${DOMAIN_NAME}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

nginx -t
exec nginx -g "daemon off;"
