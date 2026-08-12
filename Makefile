
all: up

up: build
	mkdir -p  /home/abrami/data/mariadb /home/abrami/data/wordpress
	docker compose -f ./srcs/docker-compose.yml up -d

build:
	docker compose -f ./srcs/docker-compose.yml build

down:
	docker compose -f ./srcs/docker-compose.yml down

stop:
	docker compose -f ./srcs/docker-compose.yml stop


restart:
	docker compose -f ./srcs/docker-compose.yml restart


clean:
	docker compose -f ./srcs/docker-compose.yml down -v --rmi all

fclean: clean
	docker compose -f ./srcs/docker-compose.yml  down --rmi all --volumes
	sudo rm -fr /home/abrami/data

re: fclean all

.PHONY: all up build down stop restart clean fclean re