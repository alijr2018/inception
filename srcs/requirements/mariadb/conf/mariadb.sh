#!/bin/bash

set -e

echo "Start MariaDB"

mkdir -p /run/mysqld 
chown -R mysql:mysql /run/mysqld 
    echo "Script start"

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "INIT DB"
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

if [ ! -d "/var/lib/mysql/${DB_NAME}" ]; then
    mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 &


    until mariadb-admin ping --silent; do
        sleep 5
    done

mariadb -e "
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
"
    mariadb-admin shutdown
fi


echo "Start Mariadb .."

exec mysqld  --user=mysql  --datadir=/var/lib/mysql --bind-address=0.0.0.0

