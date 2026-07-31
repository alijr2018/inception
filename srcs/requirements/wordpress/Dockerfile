FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    php-fpm php-mysql curl mariadb-client ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN sed -i 's|^listen = .*|listen = 9000|g' /etc/php/7.4/fpm/pool.d/www.conf && \
    sed -i 's|^;clear_env = no|clear_env = no|g' /etc/php/7.4/fpm/pool.d/www.conf

RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp && \
    chmod +x /usr/local/bin/wp

COPY ./conf/wordpress.sh /usr/local/bin/wordpress.sh
RUN chmod +x /usr/local/bin/wordpress.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wordpress.sh"]
