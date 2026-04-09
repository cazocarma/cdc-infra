.DEFAULT_GOAL := help

# =============================================================================
# CDC — Makefile operativo para entorno Linux/Ubuntu
# Repos esperados:
#   /opt/cdc/repos/cdc-front-ng
#   /opt/cdc/repos/cdc-back
#   /opt/cdc/repos/cdc-infra   <-- este Makefile vive aquí
# =============================================================================

# --- Rutas base ---------------------------------------------------------------
ROOT_DIR       := $(abspath $(CURDIR))
INFRA_DIR      := $(ROOT_DIR)
CDC_FRONT_DIR  := $(abspath $(INFRA_DIR)/../cdc-front-ng)
CDC_BACK_DIR   := $(abspath $(INFRA_DIR)/../cdc-back)

# --- Compose / env ------------------------------------------------------------
COMPOSE_FILE   := $(INFRA_DIR)/docker-compose.yml
ENV_FILE       := $(INFRA_DIR)/.env
ENV_EXAMPLE    := $(INFRA_DIR)/.env.example

COMPOSE        := docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE)
COMPOSE_NODE   := $(COMPOSE) --profile node

# --- Utilidades ---------------------------------------------------------------
TAIL           ?= 200
SHELL          := /bin/bash

# --- Phony targets ------------------------------------------------------------
.PHONY: help
.PHONY: env-check repo-check net-check doctor
.PHONY: build-cdc-front build-cdc-back build-all rebuild
.PHONY: up up-build down down-v stop start restart restart-cdc-front restart-cdc-back
.PHONY: ps logs logs-cdc-front logs-cdc-back
.PHONY: config pull deploy redeploy
.PHONY: exec-cdc-front exec-cdc-back
.PHONY: images volumes networks
.PHONY: prune prune-soft
.PHONY: status

# =============================================================================
# Help
# =============================================================================
help:
	@echo "Greenvic Cuaderno de Campo — Makefile"
	@echo ""
	@echo "Bootstrap:"
	@echo "  make env-check        Verifica .env"
	@echo "  make repo-check       Verifica que existan los repos esperados"
	@echo "  make net-check        Verifica redes Docker externas"
	@echo "  make doctor           Verifica docker, compose, .env y repos"
	@echo ""
	@echo "Build:"
	@echo "  make build-cdc-front  Build de cdc-front-ng"
	@echo "  make build-cdc-back   Build de cdc-back"
	@echo "  make build-all        Build de todas las imagenes"
	@echo "  make rebuild          Rebuild completo sin cache"
	@echo ""
	@echo "Run:"
	@echo "  make up               Levanta el stack"
	@echo "  make up-build         Levanta reconstruyendo"
	@echo "  make down             Baja el stack"
	@echo "  make down-v           Baja el stack y elimina volumenes"
	@echo "  make stop             Detiene servicios"
	@echo "  make start            Inicia servicios ya creados"
	@echo "  make restart          Reinicia todo el stack"
	@echo ""
	@echo "Ops:"
	@echo "  make ps               Estado de contenedores"
	@echo "  make status           Estado + resumen"
	@echo "  make logs             Logs de todo el stack"
	@echo "  make logs-cdc-front   Logs de cdc-front-ng"
	@echo "  make logs-cdc-back    Logs de cdc-back"
	@echo "  make restart-cdc-front Reinicia cdc-front-ng"
	@echo "  make restart-cdc-back Reinicia cdc-back"
	@echo ""
	@echo "Debug:"
	@echo "  make config           Render de docker compose"
	@echo "  make exec-cdc-front   Shell en cdc-front-ng"
	@echo "  make exec-cdc-back    Shell en cdc-back"
	@echo ""
	@echo "Deploy:"
	@echo "  make pull             Git pull en front/back/infra"
	@echo "  make deploy           Pull + up -d --build"
	@echo "  make redeploy         Down + deploy"
	@echo ""
	@echo "Infra:"
	@echo "  make images           Lista imagenes"
	@echo "  make volumes          Lista volumenes"
	@echo "  make networks         Lista redes"
	@echo "  make prune-soft       Limpieza suave"
	@echo "  make prune            Limpieza agresiva"
	@echo ""
	@echo "Variables opcionales:"
	@echo "  TAIL=500 make logs"
	@echo ""
	@true

# =============================================================================
# Validaciones
# =============================================================================
env-check:
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "ERROR: Falta $(ENV_FILE)"; \
		echo "Crea el archivo copiando $(ENV_EXAMPLE)"; \
		exit 1; \
	fi

net-check:
	@docker network inspect greenvic-cdc_default > /dev/null 2>&1 || \
		(echo "ERROR: La red greenvic-cdc_default no existe. Levanta el stack platform primero." && exit 1)
	@docker network inspect platform_identity > /dev/null 2>&1 || \
		(echo "ERROR: La red platform_identity no existe. Levanta el stack platform primero." && exit 1)
	@docker network inspect platform_cache > /dev/null 2>&1 || \
		(echo "ERROR: La red platform_cache no existe. Levanta el stack platform primero." && exit 1)

repo-check:
	@if [ ! -d "$(CDC_FRONT_DIR)" ]; then \
		echo "ERROR: No existe repo front en $(CDC_FRONT_DIR)"; \
		exit 1; \
	fi
	@if [ ! -d "$(CDC_BACK_DIR)" ]; then \
		echo "ERROR: No existe repo back en $(CDC_BACK_DIR)"; \
		exit 1; \
	fi
	@if [ ! -f "$(COMPOSE_FILE)" ]; then \
		echo "ERROR: No existe $(COMPOSE_FILE)"; \
		exit 1; \
	fi

doctor: env-check repo-check
	@echo "== Doctor =="
	@echo ""
	@echo "[Docker]"
	@docker --version
	@echo ""
	@echo "[Docker Compose]"
	@docker compose version
	@echo ""
	@echo "[Repos]"
	@echo "INFRA: $(INFRA_DIR)"
	@echo "FRONT: $(CDC_FRONT_DIR)"
	@echo "BACK : $(CDC_BACK_DIR)"
	@echo ""
	@echo "[Compose file]"
	@echo "$(COMPOSE_FILE)"
	@echo ""
	@echo "[Env file]"
	@echo "$(ENV_FILE)"
	@echo ""
	@echo "OK"

# =============================================================================
# Build
# =============================================================================
build-cdc-front: env-check repo-check
	$(COMPOSE) build front-ng

build-cdc-back: env-check repo-check
	$(COMPOSE_NODE) build back

build-all: env-check repo-check
	$(COMPOSE_NODE) build

rebuild: env-check repo-check
	$(COMPOSE_NODE) build --no-cache

# =============================================================================
# Run
# =============================================================================
up: env-check repo-check net-check
	$(COMPOSE_NODE) up -d

up-build: env-check repo-check net-check
	$(COMPOSE_NODE) up -d --build

down: env-check repo-check
	$(COMPOSE_NODE) down --remove-orphans

down-v: env-check repo-check
	$(COMPOSE_NODE) down -v --remove-orphans

stop: env-check repo-check
	$(COMPOSE_NODE) stop

start: env-check repo-check
	$(COMPOSE_NODE) start

restart: env-check repo-check
	$(COMPOSE_NODE) restart

restart-cdc-front: env-check repo-check
	$(COMPOSE) restart front-ng

restart-cdc-back: env-check repo-check
	$(COMPOSE_NODE) restart back

# =============================================================================
# Ops
# =============================================================================
ps: env-check repo-check
	$(COMPOSE_NODE) ps

status: env-check repo-check
	@echo "== Estado de contenedores =="
	@$(COMPOSE_NODE) ps
	@echo ""
	@echo "== Imagenes CDC =="
	@docker images | grep -i cdc || true

logs: env-check repo-check
	$(COMPOSE_NODE) logs -f --tail=$(TAIL)

logs-cdc-front: env-check repo-check
	$(COMPOSE) logs -f --tail=$(TAIL) front-ng

logs-cdc-back: env-check repo-check
	$(COMPOSE_NODE) logs -f --tail=$(TAIL) back

# =============================================================================
# Debug / acceso a contenedores
# =============================================================================
config: env-check repo-check
	$(COMPOSE_NODE) config

exec-cdc-front: env-check repo-check
	$(COMPOSE) exec front-ng sh

exec-cdc-back: env-check repo-check
	$(COMPOSE_NODE) exec back sh

# =============================================================================
# Git / Deploy
# =============================================================================
pull: repo-check
	@echo "== Git pull cdc-front-ng =="
	@if [ -d "$(CDC_FRONT_DIR)/.git" ]; then \
		cd "$(CDC_FRONT_DIR)" && git pull; \
	else \
		echo "WARN: $(CDC_FRONT_DIR) no es repo git"; \
	fi
	@echo ""
	@echo "== Git pull cdc-back =="
	@if [ -d "$(CDC_BACK_DIR)/.git" ]; then \
		cd "$(CDC_BACK_DIR)" && git pull; \
	else \
		echo "WARN: $(CDC_BACK_DIR) no es repo git"; \
	fi
	@echo ""
	@echo "== Git pull infra =="
	@if [ -d "$(INFRA_DIR)/.git" ]; then \
		cd "$(INFRA_DIR)" && git pull; \
	else \
		echo "WARN: $(INFRA_DIR) no es repo git"; \
	fi

deploy: env-check repo-check pull
	$(COMPOSE_NODE) up -d --build --remove-orphans

redeploy: env-check repo-check
	$(COMPOSE_NODE) down --remove-orphans
	$(COMPOSE_NODE) up -d --build --remove-orphans

# =============================================================================
# Infra helpers
# =============================================================================
images:
	@docker images

volumes:
	@docker volume ls

networks:
	@docker network ls

prune-soft:
	@docker image prune -f
	@docker container prune -f
	@docker network prune -f

prune:
	@docker system prune -af --volumes
