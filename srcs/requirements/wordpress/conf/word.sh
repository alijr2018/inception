#!/bin/bash

set -e

if [ ! -f /var/www/html/wp-load.php ]; then
    cd /tmp
    wget https://wordpress.org/latest.tar.gz
    tar -xf latest.tar.gz
    mv wordpress/* /var/www/html/
fi

chown -R www-data:www-data /var/www/html


until mysqladmin ping -h "$DB_HOST" --silent; do
    echo "Wait for mariadb"
    sleep 2
done

if [ ! -f /var/www/html/wp-config.php ]; then
    wp --allow-root config create --path=/var/www/html --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" --dbhost="$DB_HOST"
fi

if ! wp --allow-root core is-installed --path=/var/www/html ; then
    wp --allow-root core install --path=/var/www/html --url="$DOMAIN_NAME" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASS"  --admin_email="$WP_ADMIN_EMAIL"
    wp --allow-root user create "${WP_USER}" "${WP_USER_EMAIL}" --role=author --user_pass="${WP_USER_PASS}" --path=/var/www/html
fi

exec php-fpm8.2 -F 
