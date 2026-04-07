# cdc-infra

Infraestructura local de desarrollo y scripts de base de datos para **Cuaderno de Campo** (CDC).

Este repo orquesta los contenedores de `cdc-back` y `cdc-front-ng`, y contiene los scripts SQL del modelo de datos.

## Requisitos

- Docker y Docker Compose v2
- Stack **greenvic-platform** levantado (provee las redes externas `greenvic-cdc_default` y `platform_identity`, y el reverse proxy compartido)
- Repos clonados en `/opt/cdc/repos/`: `cdc-front-ng`, `cdc-back`, `cdc-infra`
- Una instancia de SQL Server accesible desde el host (no se levanta en contenedor; el back se conecta vía `DB_HOST`)

## Configuracion de entorno

- Archivo real: `cdc-infra/.env` (no versionado)
- Plantilla: `cdc-infra/.env.example`
- `cdc-back` consume este `.env` directamente; **no** usa uno propio

Variables principales:

| Variable | Proposito |
|---|---|
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | Conexion a SQL Server |
| `DB_ENCRYPT`, `DB_TRUST_SERVER_CERTIFICATE` | TLS al motor SQL |
| `JWT_SECRET` (>= 32 bytes), `JWT_EXPIRES_IN` | Firma de tokens del back |
| `CORS_ORIGIN` | Origen permitido por el back (URL del front) |
| `LOGIN_RATE_LIMIT_*` | Rate limiting de `/auth/login` |

## Arquitectura de red

| Red | Tipo | Proposito |
|---|---|---|
| `greenvic-cdc_default` | externa | Red principal del stack CDC |
| `platform_identity` | externa | Comunicacion con Keycloak (authn/authz) |
| `greenvic-cdc_egress` | interna | Salida controlada a servicios externos |

> El reverse proxy (NGINX) vive en `greenvic-platform`. CDC ya no levanta su propio gateway; los aliases `cdc-frontend` / `cdc-backend` permiten al router enrutar por hostname.

## Servicios

| Servicio | Puerto interno | Descripcion |
|---|---|---|
| `front-ng` | 3000 | Frontend Angular servido por nginx (`cdc-front-ng:local`) |
| `back` | 4000 | Backend Express + Node 20 (perfil `node`) |

Ambos quedan accesibles desde el host vía el router de la plataforma (puertos publicados por `greenvic-router`).

## Flujo recomendado

```bash
make doctor       # Verifica docker, compose, .env, repos y redes
make up-build     # Levanta el stack reconstruyendo imagenes
make logs         # Sigue logs de todos los servicios
make down         # Baja el stack
```

### Targets del Makefile

```
Bootstrap:
  make env-check        Verifica .env
  make repo-check       Verifica repos esperados
  make net-check        Verifica redes Docker externas
  make doctor           Verifica docker, compose, .env y repos

Build:
  make build-cdc-front  Build de cdc-front-ng
  make build-cdc-back   Build de cdc-back
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
  make logs-cdc-front   Logs de cdc-front-ng
  make logs-cdc-back    Logs de cdc-back

Deploy:
  make pull             Git pull en front/back/infra
  make deploy           Pull + up -d --build
  make redeploy         Down + deploy
```

## Base de datos

Los scripts SQL viven en `database/modelo-datos/`. Estan pensados para ejecutarse con `sqlcmd` (o cualquier cliente equivalente) contra una instancia SQL Server.

### Convenciones del modelo

- **Esquema unico:** `cdc`
- **Tablas:** PascalCase, sin prefijo de aplicacion (`cdc.Fundo`, `cdc.Usuario`, `cdc.ProductoEspecie`, …)
- **Columnas:** PascalCase. PK siempre `Id`. FKs con patron `<Padre>Id` (ej: `ProductorId`, `EspecieId`)
- **Tipos:** `NVARCHAR` para texto libre con posibles acentos; `VARCHAR` solo para identificadores/codigos puramente ASCII; `DECIMAL(12,4)` para superficies y dosis
- **Restricciones:** `PK_<Tabla>`, `FK_<Hija>_<Padre>`, `UQ_<Tabla>_<Cols>`, `DF_<Tabla>_<Col>`, `CK_<Tabla>_<Col>`
- **Indices:** `IX_<Tabla>_<Col>` no clustered en FKs frecuentes para evitar table scans en joins

### Scripts

| Script | Proposito |
|---|---|
| `UP.sql` | Crea el schema `cdc` y todas las tablas/restricciones/indices |
| `DOWN.sql` | Drop destructivo: borra datos, FKs, tablas y el schema completo |
| `SEED.sql` | Datos iniciales (catalogos: temporadas, especies, variedades, productos, ingredientes, mercados, reglas, etc.) |
| `ZZZ_ADMIN_USER.sql` | Crea el usuario `admin` con un hash `sha256:` compatible con el back |

### Flujo de bootstrap

```bash
cd database/modelo-datos

sqlcmd -S <host> -U <user> -P <password> -d <db> -i UP.sql
sqlcmd -S <host> -U <user> -P <password> -d <db> -i SEED.sql
sqlcmd -S <host> -U <user> -P <password> -d <db> -i ZZZ_ADMIN_USER.sql
```

Para reconstruir desde cero (destructivo):

```bash
sqlcmd -S <host> -U <user> -P <password> -d <db> -i DOWN.sql
sqlcmd -S <host> -U <user> -P <password> -d <db> -i UP.sql
sqlcmd -S <host> -U <user> -P <password> -d <db> -i SEED.sql
sqlcmd -S <host> -U <user> -P <password> -d <db> -i ZZZ_ADMIN_USER.sql
```

### Usuario inicial

- Usuario: `admin`
- Password: `123456789`

El hash almacenado es `sha256:15e2b0d3...8eb225` (SHA-256 hex de la contraseña con prefijo `sha256:`), formato que `verifyPassword` del back valida nativamente.

## Validacion rapida

```bash
docker compose ps
curl http://127.0.0.1/healthz       # front-ng via platform gateway
curl http://127.0.0.1/api/health    # back via platform gateway
```
