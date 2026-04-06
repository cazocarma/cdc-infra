# Base de datos — Cuaderno de Campo

## Estructura

```text
database/
  modelo-datos/
    UP.sql               — Creacion del schema cdc y todas las tablas
    DOWN.sql             — Drop destructivo del schema completo
    SEED.sql             — Datos iniciales (catalogos, configuracion)
    ZZZ_ADMIN_USER.sql   — Usuario administrador por defecto
```

## Uso

Los scripts estan disenados para ejecutarse con `sqlcmd` contra una instancia SQL Server:

```bash
# Crear schema desde cero
sqlcmd -S <host> -U <user> -P <password> -d master -i database/modelo-datos/UP.sql
sqlcmd -S <host> -U <user> -P <password> -d master -i database/modelo-datos/SEED.sql
sqlcmd -S <host> -U <user> -P <password> -d master -i database/modelo-datos/ZZZ_ADMIN_USER.sql

# Eliminar schema (destructivo)
sqlcmd -S <host> -U <user> -P <password> -d master -i database/modelo-datos/DOWN.sql
```

## Usuario inicial

- Usuario: `admin`
- Password: `admin`
