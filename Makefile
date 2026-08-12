# all:
all: up
# 	docker compose up -d // spinn all conatiner simultaneously

up:
	mkdir -p  /home/$(USER)/data/mariadb /home/$(USER)/data/wordpress
	docker compose -f ./srcs/docker-compose.yml up -d --build

build:
# 	docker compose build -d // whts diff between up and build
	docker compose -f ./srcs/docker-compose.yml build

down:
# 	docker compose down           # Stop and remove containers
	docker compose -f ./srcs/docker-compose.yml down

stop:
# 	docker compose stop
	docker compose -f ./srcs/docker-compose.yml stop


restart:
# 	docker compose restart
	docker compose -f ./srcs/docker-compose.yml restart


clean:
# 	docker compose down -v
	docker compose -f ./srcs/docker-compose.yml down -v --rmi all
# Remove all containers (including stopped ones)
# 	docker rm -f $(docker ps -aq)
# Remove all images
# 	docker rmi -f $(docker images -aq)
# Remove unused volumes
# 	docker volume prune -f
# Remove unused networks
# 	docker network prune -f
# Remove build cache
# 	docker builder prune -a -f
#it rm all 
# fclean: clean
fclean: clean
# 	docker system prune -a --volumes -f
	docker compose -f ./srcs/docker-compose.yml  down --rmi all --volumes
	sudo rm -fr /home/$(USER)/data

re: fclean all

.PHONY: all up build down stop restart clean fclean re