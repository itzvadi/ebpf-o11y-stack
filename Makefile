.PHONY: up down restart logs ps clean

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart alloy

logs:
	docker compose logs -f alloy

ps:
	docker compose ps

clean:
	docker compose down -v
