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
