#!/bin/bash

set -e

echo "Start MariaDB"

# if [ ! -f "/var/lib/mysql/.initialized" ]; then
if [ ! -f "/var/lib/mysql/${inception}" ]; then
    echo "Init DB"

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql

    mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock &
    
    mysql --socket=/run/mysqld/mysqld.sock -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    mysqladmin --socket=/run/mysqld/mysqld.sock -u root shutdown
fi

echo "Start Mariadb .."

exec mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock --bind-address=0.0.0.0