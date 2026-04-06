# cdc-infra

Infraestructura local de desarrollo para `greenvic-cuaderno-campo`.

## Requisitos previos

- Docker y Docker Compose
- Stack **greenvic-platform** levantado (provee las redes `greenvic-cdc_default` y `platform_identity`)
- Repos clonados en `/opt/cdc/repos/`: `cdc-front-ng`, `cdc-back`, `cdc-infra`

## Fuente de entorno

- Archivo real: `cdc-infra/.env`
- Plantilla: `cdc-infra/.env.example`
- `cdc-back` consume este archivo; no usa `.env` propio

## Arquitectura de red

El stack CDC se conecta a redes externas gestionadas por `greenvic-platform`:

| Red                    | Tipo     | Proposito                              |
|------------------------|----------|----------------------------------------|
| `greenvic-cdc_default` | externa  | Red principal del stack CDC            |
| `platform_identity`    | externa  | Comunicacion con Keycloak (authn/authz)|
| `greenvic-cdc_egress`  | interna  | Salida controlada a servicios externos |

> El gateway (NGINX) fue delegado a `greenvic-platform`. CDC ya no levanta su propio reverse proxy.

## Flujo recomendado

```bash
make doctor         # Verifica docker, compose, .env, repos
make up-build       # Levanta el stack reconstruyendo imagenes
make logs           # Sigue logs de todos los servicios
make down           # Baja el stack
```

## Servicios

| Servicio   | Puerto | Descripcion                      |
|------------|--------|----------------------------------|
| `front-ng` | 80     | Frontend Angular (Cuaderno Campo)|
| `back`     | 3000   | Backend Node (perfil `node`)     |

## Targets del Makefile

```
Bootstrap:
  make env-check        Verifica .env
  make repo-check       Verifica repos esperados
  make net-check        Verifica redes Docker externas
  make doctor           Verifica docker, compose, .env y repos

Build:
  make build-front      Build de cdc-front-ng
  make build-back       Build de cdc-back
  make build-all        Build de todas las imagenes
  make rebuild          Rebuild completo sin cache

Run:
  make up               Levanta el stack
  make up-build         Levanta reconstruyendo
  make down             Baja el stack
  make down-v           Baja el stack y elimina volumenes

Ops:
  make ps               Estado de contenedores
  make status           Estado + resumen
  make logs             Logs de todo el stack
  make logs-front       Logs de front-ng
  make logs-back        Logs de back

Deploy:
  make pull             Git pull en front/back/infra
  make deploy           Pull + up -d --build
  make redeploy         Down + deploy
```

## Base de datos

Los scripts SQL del modelo de datos se encuentran en `database/modelo-datos/`:

| Script                 | Proposito                          |
|------------------------|------------------------------------|
| `UP.sql`               | Creacion del schema y tablas       |
| `DOWN.sql`             | Eliminacion destructiva del schema |
| `SEED.sql`             | Datos iniciales                    |
| `ZZZ_ADMIN_USER.sql`   | Usuario administrador por defecto  |

## Validacion rapida

```bash
docker compose ps
curl http://127.0.0.1/healthz       # front-ng via platform gateway
curl http://127.0.0.1/api/health    # back via platform gateway
```
