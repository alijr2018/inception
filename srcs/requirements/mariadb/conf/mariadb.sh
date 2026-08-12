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
    mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock &

    until mariadb-admin --socket=/run/mysqld/mysqld.sock ping --silent; do
        sleep 5
    done
    
    mysql --socket=/run/mysqld/mysqld.sock << EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    # mysqladmin --socket=/run/mysqld/mysqld.sock -u root shutdown
    mysqladmin --socket=/run/mysqld/mysqld.sock shutdown


echo "Start Mariadb .."

exec "$@"
# exec mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock --bind-address=0.0.0.0