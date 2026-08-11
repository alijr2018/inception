#!/bin/bash

set -e

# cat << EOF > /etc/nginx/conf.d/default.conf

mkdir -p /etc/nginx/ssl

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/we.key -out /etc/nginx/ssl/we.crt -subj "/C=MO/ST=KH/O=42/OU=42/CN=${DOMAIN_NAME}"

cat << EOF > /etc/nginx/conf.d/default.conf
  server
  {
    listen 443 ssl;
    root /var/www/html;
    server_name ${DOMAIN_NAME};
    index index.php;

    ssl_certificate /etc/nginx/ssl/we.crt;
    ssl_certificate_key /etc/nginx/ssl/we.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location ~ \.php$
    {
        include snippets/fastcgi-php.conf;
        fastcgi_pass wordpress:9000;
    }
  }


EOF



nginx -t

exec nginx -g "daemon off;"