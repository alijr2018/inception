FROM debian:bookworm

RUN apt update -y   && apt install -y nginx openssl 

COPY ./conf/ssl.sh /
COPY ./conf/default.conf /etc/nginx/conf.d/default.conf

RUN chmod +x /ssl.sh

ENTRYPOINT [ "/ssl.sh" ]
