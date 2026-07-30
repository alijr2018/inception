FROM debian:bullseye

# RUN apt update -y  && apt upgrade -y && apt install mariadb-server -y
# RUN mean Executes a command while building the image.
RUN apt update -y  && apt upgrade -y && apt install -y mariadb-server mariadb-client galera-4 

RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld && chown 755 /var/run/mysqld
# COPY conf/mariadb.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY ./conf/mariadb.conf /usr/local/bin/mariadb.sh

RUN chmod +x /usr/local/bin/mariadb.sh

EXPOSE 3306

# seach more about healtcheck
HEALTHCHECK --interval=30s --timeout=30s  --retries=3 CMD [ "mariadb-admin", "ping", "-h", "localhost" ]

# CMD ["bash", "mariadb.conf"]
# ENTRYPOINT [ "/usr/local/bin/mariadb.sh" ]
ENTRYPOINT [ "mariadb.sh" ]