#!/bin/bash

set -e

echo "Start MariaDB"

mkdir -p /run/mysqld 
chown -R mysql:mysql /run/mysqld 

# if [ ! -f "/var/lib/mysql/.initialized" ]; then
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Init DB"

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql

fi

    mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock &

    until mariadb-admin --socket=/run/mysqld/mysqld.sock ping --silent; do
        sleep 3
    done
    
    mysql --socket=/run/mysqld/mysqld.sock -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    mysqladmin --socket=/run/mysqld/mysqld.sock -u root shutdown

echo "Start Mariadb .."

exec mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock --bind-address=0.0.0.0