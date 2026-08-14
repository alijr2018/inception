FROM debian:bookworm

RUN apt update -y && apt install -y mariadb-server mariadb-client

COPY ./conf/mariadb.sh /usr/local/bin/mariadb.sh

RUN chmod +x /usr/local/bin/mariadb.sh

ENTRYPOINT ["/usr/local/bin/mariadb.sh"]
