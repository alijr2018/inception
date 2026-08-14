#!/bin/bash

set -e

mkdir -p /etc/nginx/ssl

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/we.key -out /etc/nginx/ssl/we.crt -subj "/CN=${DOMAIN_NAME}"


nginx -t

exec nginx -g "daemon off;"