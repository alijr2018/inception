FROM: debian:bullseye

# RUN apt update -y  && apt upgrade -y && apt install mariadb-server -y
# RUN mean Executes a command while building the image.
RUN apt update -y  && apt upgrade -y && apt install mariadb-server mariadb-client galera-4 -y


COPY ./conf/mariadb.conf .

