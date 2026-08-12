FROM debian:bookworm

RUN apt update -y   && apt install -y nginx openssl 

COPY ./conf/ssl.sh /

RUN chmod +x /ssl.sh

ENTRYPOINT [ "/ssl.sh" ]
CMD [ "nginx" ,"-g" ,"daemon off;"]
