FROM debian:bookworm

RUN apt update -y && apt install curl wget php8.2 php8.2-mysql php8.2-fpm mariadb-client -y

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar &&  chmod +x wp-cli.phar &&  mv wp-cli.phar /usr/local/bin/wp


WORKDIR /var/www/html

COPY ./conf/word.sh /

COPY ./conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

RUN chmod +x /word.sh


ENTRYPOINT [ "/word.sh" ]
