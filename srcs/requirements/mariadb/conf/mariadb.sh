#!/bin/bash

set -e

echo "Start MariaDB"

if [ ! -f "/var/lib/mysql/.initialized" ]; then
    echo "Init DB"

    rm -fr /var/lib/mysql/*

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql

    mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock &

    until mysqladmin ping --socket=/run/mysqld/mysqld.sock --silent; do
        sleep 1
    done
    echo "DB is ready"
    
    mysql --socket=/run/mysqld/mysqld.sock -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    mysqladmin --socket=/run/mysqld/mysqld.sock -u root  -p"${MARIADB_ROOT_PASSWORD}"  shutdown
    touch /var/lib/mysql/.initialized
    echo "MariaDB initialization complete"

    else
        echo "MariaDB already initialized"
fi

echo "Start Mariadb .."

exec mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock --bind-address=0.0.0.0