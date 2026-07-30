#!/bin/bash

set -e

SSL_DIR=/etc/nginx/ssl

mkdir -p "$SSL_DIR"

rm -f "$SSL_DIR"/*.pem "$SSL_DIR"/*.key "$SSL_DIR"/*.crt

# Generate CA key and certificate
openssl req -x509 -newkey rsa:4096 -days 365 -nodes -keyout "$SSL_DIR/ca-key.pem" -out "$SSL_DIR/ca-cert.pem"  -subj "/C=MA/ST=Khouribga/L=Khouribga/O=1337/CN=${DOMAIN_NAME}"

# Generate nginx private key
openssl genrsa \
  -out "$SSL_DIR/nginx.key" \
  2048

# Generate CSR
openssl req \
  -new \
  -key "$SSL_DIR/nginx.key" \
  -out "$SSL_DIR/nginx.csr" \
  -subj "/C=MA/ST=Khouribga/L=Khouribga/O=1337/CN=${DOMAIN_NAME}"
    # -addext "subjectAltName=DNS:${DOMAIN_NAME}" # add it for new machine but idk
# Sign certificate with CA
openssl x509 \
  -req \
  -days 365 \
  -in "$SSL_DIR/nginx.csr" \
  -CA "$SSL_DIR/ca-cert.pem" \
  -CAkey "$SSL_DIR/ca-key.pem" \
  -CAcreateserial \
  -out "$SSL_DIR/nginx.crt"

chmod 600 "$SSL_DIR/nginx.key"
chmod 644 "$SSL_DIR/nginx.crt"

nginx -t

exec nginx -g "daemon off;"