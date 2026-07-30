all:
	docker compose up -d // spinn all conatiner simultaneously
build:
	docker compose build -d // whts diff between up and build
down:
	docker compose down           # Stop and remove containers
stop:
	docker compose stop

restart:
	docker compose restart

clean:
	docker compose down -v