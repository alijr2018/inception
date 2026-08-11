FROM debian:bookworm

RUN apt update -y && apt install -y mariadb-server mariadb-client

COPY ./conf/mariadb.sh /usr/local/bin/mariadb.sh

RUN chmod +x /usr/local/bin/mariadb.sh

HEALTHCHECK --interval=30s --timeout=30s  --retries=3 CMD [ "mariadb-admin", "ping", "-h", "localhost" ]

ENTRYPOINT ["/usr/local/bin/mariadb.sh"]