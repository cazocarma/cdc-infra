# CDC Infra

Este proyecto es el punto de arranque del stack completo:

- `cdc-front`
- `cdc-back`
- `cdc-infra` (SQL Server)

## Levantar todo desde infra

1. Copia `.env.example` a `.env` y define:
   - `MSSQL_SA_PASSWORD`
   - `JWT_SECRET`
2. Ejecuta:

```bash
docker compose up --build
```

## Scripts SQL one-time

- Deja tus scripts `.sql` en `initdb/`.
- Orden recomendado y soportado: `DOWN.sql`, `UP.sql`, `SEED.sql`.
- Por defecto se ejecuta:
  - `DOWN.sql` (si existe, tolera error)
  - `UP.sql` (si existe)
  - `SEED.sql` (si existe)
- Luego se ejecuta cualquier `*.sql` adicional en orden alfabetico (por ejemplo `ZZZ_ADMIN_USER.sql`).
- Modo por defecto: `DB_INIT_MODE=once` (solo primera inicializacion del volumen).
- Si necesitas ejecutar en cada arranque: `DB_INIT_MODE=always`.
- Si no quieres ejecutar `DOWN.sql`: `DB_INIT_RUN_DOWN=false`.
- Si necesitas re-ejecutar desde cero en modo `once`, elimina el volumen `greenvic-cdc_cdc-sql-data`.

## Usuario inicial

- Se incluye `initdb/ZZZ_ADMIN_USER.sql` para crear usuario inicial si no existe:
  - usuario: `admin`
  - password: `admin`
