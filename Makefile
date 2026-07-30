all:
# 	docker compose up -d // spinn all conatiner simultaneously
	docker compose -f ./srcs/docker-compose.yml up -d 

build:
# 	docker compose build -d // whts diff between up and build
	docker compose -f ./srcs/docker-compose.yml  

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
	docker compose -f ./srcs/docker-compose.yml down -v
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
	docker system prune -a --volumes -f
