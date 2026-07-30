#!/bin/bash

# sudo mariadb-secure-installation
# 
# sudo systemctl status mariadb
# 
# sudo systemctl start mariadb
# 
# mariadb -u root -p
# 
# /etc/my.cnf /etc/mysql/my.cnf ~/.my.cnf 
# 


# set -e

# echo "Start MariaDB init"

# mkdir -p /run/mysqld
# chown mysql:mysql /run/mysqld

set -e

echo "Start MariaDB init"

if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null

    mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock &

    until mysqladmin ping --socket=/run/mysqld/mysqld.sock --silent; do
        sleep 1
    done

    mysql --socket=/run/mysqld/mysqld.sock -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MARIADB_DATABASE};
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MARIADB_DATABASE}.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    mysqladmin --socket=/run/mysqld/mysqld.sock shutdown
fi

exec mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock