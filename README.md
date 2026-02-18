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
- Se ejecutan una sola vez cuando el volumen de SQL Server no tiene el marcador de inicializacion.
- Si necesitas re-ejecutarlos desde cero, elimina el volumen `greenvic-cdc_cdc-sql-data`.
