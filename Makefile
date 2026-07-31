COMPOSE_FILE = ./srcs/docker-compose.yml

.PHONY: all up build down stop restart clean re logs ps

all: up

up:
	docker compose -f $(COMPOSE_FILE) up -d --build

build:
	docker compose -f $(COMPOSE_FILE) build

down:
	docker compose -f $(COMPOSE_FILE) down

stop:
	docker compose -f $(COMPOSE_FILE) stop

restart:
	docker compose -f $(COMPOSE_FILE) restart

clean:
	docker compose -f $(COMPOSE_FILE) down -v --remove-orphans
	docker system prune -af --volumes

re: clean up

logs:
	docker compose -f $(COMPOSE_FILE) logs -f

ps:
	docker compose -f $(COMPOSE_FILE) ps
