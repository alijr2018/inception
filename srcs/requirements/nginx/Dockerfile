FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx openssl gettext-base && \
    rm -rf /var/lib/apt/lists/*

COPY ./conf/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY ./conf/ssl.sh /usr/local/bin/ssl.sh

RUN chmod +x /usr/local/bin/ssl.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/ssl.sh"]
