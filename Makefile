.DEFAULT_GOAL := help

# =============================================================================
# CDC — Makefile operativo
# Un solo comando, una sola fuente de verdad.
#
# Uso tipico:
#   make setup-env    # primera vez: crea .env desde .env.example
#   make up           # levanta el stack (dev o prd segun CDC_ENV en .env)
#   make down
#   make logs
#
# El entorno se decide por CDC_ENV (leido de .env). dev aplica el overlay
# docker-compose.dev.yml automaticamente; prd usa solo el base.
# En prd remoto el deployer de platform ejecuta este mismo flujo al detectar
# un push a main (poll cada 5 min); el operador solo hace `make up` una vez.
# =============================================================================

ROOT_DIR       := $(abspath $(CURDIR))
INFRA_DIR      := $(ROOT_DIR)
BACK_DIR       := $(abspath $(INFRA_DIR)/../cdc-back)
FRONT_DIR      := $(abspath $(INFRA_DIR)/../cdc-front-ng)

COMPOSE_BASE   := $(INFRA_DIR)/docker-compose.yml
ENV_FILE       := $(INFRA_DIR)/.env
# CDC_ENV se lee desde .env (default prd si no esta). El overlay correspondiente
# se monta automaticamente; fallar rapido si el archivo no existe.
CDC_ENV        := $(shell [ -f $(ENV_FILE) ] && sed -n 's/^CDC_ENV=//p' $(ENV_FILE) | tail -n 1 | tr -d '\r')
OVERLAY_COMPOSE := $(INFRA_DIR)/docker-compose.$(CDC_ENV).yml
TAIL           ?= 200

# ── Shell (Linux bash / Windows Git Bash) ──────────────────────────────────
BASH ?=
ifeq ($(strip $(BASH)),)
  ifeq ($(OS),Windows_NT)
    BASH := $(strip $(shell command -v bash 2>/dev/null))
    ifeq ($(strip $(BASH)),)
      ifneq ($(wildcard C:/Progra~1/Git/bin/bash.exe),)
        BASH := C:/Progra~1/Git/bin/bash.exe
      else ifneq ($(wildcard C:/Progra~1/Git/usr/bin/bash.exe),)
        BASH := C:/Progra~1/Git/usr/bin/bash.exe
      endif
    endif
  else
    BASH := $(firstword $(shell command -v bash))
  endif
endif
SHELL := $(BASH)
.SHELLFLAGS := -c

# ── Carga .env al entorno de make (para que CDC_ENV, DB_*, etc. esten exportados) ──
ifneq (,$(wildcard $(ENV_FILE)))
  include $(ENV_FILE)
  export
endif

# ── Compose handle: base + overlay (docker-compose.$(CDC_ENV).yml) ─────────
COMPOSE := docker compose -f $(COMPOSE_BASE) -f $(OVERLAY_COMPOSE) --env-file $(ENV_FILE)

# =============================================================================
# Help
# =============================================================================

## help: lista de targets disponibles
.PHONY: help
help:
	@grep -hE '^## ' $(MAKEFILE_LIST) | sed 's/^## //'

# =============================================================================
# Bootstrap
# =============================================================================

## setup-env: crea .env a partir de .env.example si no existe
.PHONY: setup-env
setup-env:
	@if [ -f "$(ENV_FILE)" ]; then \
	  echo ".env ya existe en $(ENV_FILE)"; \
	else \
	  cp "$(INFRA_DIR)/.env.example" "$(ENV_FILE)"; \
	  chmod 600 "$(ENV_FILE)"; \
	  echo ".env creado con chmod 600 — completar valores <changeme>"; \
	fi

## doctor: valida .env + overlay + repos hermanos + red de platform + branch
.PHONY: doctor
doctor:
	@if [ ! -f "$(ENV_FILE)" ]; then \
	  echo "Falta $(ENV_FILE). Ejecuta 'make setup-env' y completa valores."; exit 1; \
	fi
	@cdc_env="$$(sed -n 's/^CDC_ENV=//p' "$(ENV_FILE)" | tail -n 1 | tr -d '\r')"; \
	if [ -z "$$cdc_env" ]; then \
	  echo "ERROR: Falta CDC_ENV=dev|prd en $(ENV_FILE)"; exit 1; \
	fi; \
	case "$$cdc_env" in \
	  dev|prd) ;; \
	  *) echo "ERROR: CDC_ENV debe ser 'dev' o 'prd' (actual: $$cdc_env)"; exit 1 ;; \
	esac; \
	overlay="$(INFRA_DIR)/docker-compose.$$cdc_env.yml"; \
	if [ ! -f "$$overlay" ]; then \
	  echo "ERROR: Falta $$overlay. Los overlays dev/prd deben existir en cdc-infra/."; \
	  exit 1; \
	fi
	@for d in "$(BACK_DIR)" "$(FRONT_DIR)"; do \
	  if [ ! -d "$$d" ]; then echo "Falta repo hermano: $$d"; exit 1; fi; \
	done
	@if ! docker network ls --format '{{.Name}}' | grep -qx "platform_identity"; then \
	  echo "Falta red 'platform_identity'. Levanta platform primero ('make up' en /platform)."; \
	  exit 1; \
	fi
	@if [ "$$CDC_ENV" = "prd" ]; then \
	  for d in "$(INFRA_DIR)" "$(BACK_DIR)" "$(FRONT_DIR)"; do \
	    if [ -d "$$d/.git" ]; then \
	      cur=$$(git -C "$$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "<no-git>"); \
	      if [ "$$cur" != "main" ]; then \
	        echo "$$d esta en rama '$$cur', prd espera 'main'"; exit 1; \
	      fi; \
	    fi; \
	  done; \
	fi
	@echo "OK — entorno listo para CDC_ENV=$(CDC_ENV) (overlay: docker-compose.$(CDC_ENV).yml)"

# =============================================================================
# Run
# =============================================================================

## up: build + create + start del stack (dev o prd segun CDC_ENV)
.PHONY: up
up: doctor
	$(COMPOSE) up -d --build --remove-orphans
	@$(COMPOSE) ps

## down: baja el stack (sin tocar volumenes)
.PHONY: down
down:
	$(COMPOSE) down --remove-orphans

## down-v: baja el stack y borra volumenes (uso con cuidado)
.PHONY: down-v
down-v:
	$(COMPOSE) down -v --remove-orphans

## stop: detiene servicios sin borrarlos
.PHONY: stop
stop:
	$(COMPOSE) stop

## start: arranca servicios ya creados
.PHONY: start
start:
	$(COMPOSE) start

## restart: reinicia todo
.PHONY: restart
restart:
	$(COMPOSE) restart

## restart-back: reinicia solo el back
.PHONY: restart-back
restart-back:
	$(COMPOSE) restart back

## restart-front: reinicia solo el front
.PHONY: restart-front
restart-front:
	$(COMPOSE) restart front-ng

# =============================================================================
# Observabilidad
# =============================================================================

## ps: estado de contenedores
.PHONY: ps
ps:
	$(COMPOSE) ps

## logs: logs de todos los servicios (TAIL=N para ajustar)
.PHONY: logs
logs:
	$(COMPOSE) logs -f --tail=$(TAIL)

## logs-back: logs del back
.PHONY: logs-back
logs-back:
	$(COMPOSE) logs -f --tail=$(TAIL) back

## logs-front: logs del front
.PHONY: logs-front
logs-front:
	$(COMPOSE) logs -f --tail=$(TAIL) front-ng

## config: renderiza el compose efectivo (debug de interpolacion)
.PHONY: config
config:
	$(COMPOSE) config

## exec-back: shell en el back
.PHONY: exec-back
exec-back:
	$(COMPOSE) exec back sh

## exec-front: shell en el front
.PHONY: exec-front
exec-front:
	$(COMPOSE) exec front-ng sh
