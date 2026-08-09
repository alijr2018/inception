FROM debian:bookworm

# RUN apt update -y   && apt install mariadb-server -y
# RUN mean Executes a command while building the image.
RUN apt update -y && apt install -y mariadb-server mariadb-client

RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld 
# RUN rm -fr /var/lib/mysql/mysql
# RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld && chown 755 /var/run/mysqld
# COPY conf/mariadb.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY ./conf/mariadb.sh /usr/local/bin/mariadb.sh

RUN chmod +x /usr/local/bin/mariadb.sh

EXPOSE 3306

# seach more about healtcheck
HEALTHCHECK --interval=30s --timeout=30s  --retries=3 CMD [ "mariadb-admin", "ping", "-h", "localhost" ]

# CMD ["bash", "mariadb.conf"]
# ENTRYPOINT [ "/usr/local/bin/mariadb.sh" ]
ENTRYPOINT ["/usr/local/bin/mariadb.sh"]