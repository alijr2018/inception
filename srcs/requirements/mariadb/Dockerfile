FROM debian:bookworm

RUN apt update -y && apt install -y mariadb-server mariadb-client

RUN rm -rf /var/lib/mysql/*

COPY ./conf/mariadb.sh /mariadb.sh

RUN chmod +x /mariadb.sh

ENTRYPOINT ["/mariadb.sh"]
