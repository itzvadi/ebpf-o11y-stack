COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; else echo "docker-compose"; fi)

.PHONY: up down restart logs ps traffic bootstrap metrics clean

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart alloy

logs:
	$(COMPOSE) logs -f alloy

ps:
	$(COMPOSE) ps

traffic:
	./scripts/generate_traffic.sh

bootstrap:
	./scripts/bootstrap.sh

metrics:
	python3 scripts/query_metrics.py

clean:
	$(COMPOSE) down -v
