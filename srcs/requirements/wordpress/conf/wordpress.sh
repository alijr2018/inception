#!/bin/bash
set -e

WP_PATH=/var/www/html

mkdir -p "$WP_PATH"
chown -R www-data:www-data "$WP_PATH"

until mariadb-admin ping -h"${MARIADB_HOST}" -u"${MARIADB_USER}" -p"${MARIADB_PASSWORD}" --silent; do
    sleep 2
done

if [ ! -f "$WP_PATH/wp-config.php" ]; then
    wp core download --path="$WP_PATH" --allow-root

    wp config create \
        --path="$WP_PATH" \
        --dbname="${MARIADB_DATABASE}" \
        --dbuser="${MARIADB_USER}" \
        --dbpass="${MARIADB_PASSWORD}" \
        --dbhost="${MARIADB_HOST}" \
        --allow-root

    wp core install \
        --path="$WP_PATH" \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --path="$WP_PATH" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root

    chown -R www-data:www-data "$WP_PATH"
fi

exec /usr/sbin/php-fpm7.4 -F
