# Prompt: poner al día el backend CDC con el frontend existente

## Contexto del proyecto

Estás trabajando en **CDC (Control de Cosecha)** de Greenvic, en el repo [/opt/cdc/prd/cdc-back](/opt/cdc/prd/cdc-back). Es un BFF Node 22 + Express 4 + TypeScript (ESM) con sesiones en Redis y SQL Server externo. El frontend ([/opt/cdc/prd/cdc-front-ng](/opt/cdc/prd/cdc-front-ng), Angular 21) ya está desarrollado y consume endpoints REST bajo `/api/v1/{resource}`. Hoy el backend solo tiene implementado `auth` y `health`; las 20 rutas de negocio que el front espera devuelven 404.

**Objetivo:** implementar todos los recursos que faltan siguiendo el patrón ya establecido en CDC. No trasplantar código de otros proyectos — inspirarse en ellos solo para detalles visuales/estéticos si aplicara. CDC tiene su propia identidad (schema `cdc`, tabla `Usuario`/`Auditoria` propias, estándar de sesión BFF, etc.).

No toques el frontend: su contrato es la fuente de verdad. El backend debe amoldarse a lo que el front ya llama.

---

## 1. Contrato que el frontend espera

El cliente HTTP genérico es [cdc-api.service.ts](/opt/cdc/prd/cdc-front-ng/src/app/core/services/cdc-api.service.ts). Todos los recursos usan la misma forma:

| Método front              | HTTP                                    | Respuesta esperada                                         |
| ------------------------- | --------------------------------------- | ---------------------------------------------------------- |
| `list(resource, params)`  | `GET  /api/v1/{resource}?page&pageSize&q&...` | `{ page, pageSize, total, data: T[] }` (`PagedResponse<T>`) |
| `getById(resource, id)`   | `GET  /api/v1/{resource}/{id}`          | `T`                                                        |
| `create(resource, body)`  | `POST /api/v1/{resource}`               | `{ id?, affected?, data? }` (`MutationResponse`)           |
| `update(resource, id, b)` | `PUT  /api/v1/{resource}/{id}`          | `MutationResponse`                                         |
| `delete(resource, id)`    | `DELETE /api/v1/{resource}/{id}`        | `MutationResponse`                                         |
| `fetchAllRows(resource)`  | Pagina por detrás con `pageSize=500`, hasta `total`. No requiere endpoint especial. | — |

Tipos canónicos en [api.model.ts](/opt/cdc/prd/cdc-front-ng/src/app/core/models/api.model.ts):

```ts
interface PagedResponse<T> { page: number; pageSize: number; total: number; data: T[]; }
interface MutationResponse { id?: number | string; affected?: number; data?: unknown; }
```

**Base URL del front:** `/api/v1` (ver [api-base.ts](/opt/cdc/prd/cdc-front-ng/src/app/core/config/api-base.ts)). Los POST/PUT/DELETE ya envían `X-CSRF-Token` automáticamente ([csrf.interceptor.ts](/opt/cdc/prd/cdc-front-ng/src/app/core/interceptors/csrf.interceptor.ts)) y `withCredentials: true` para la cookie de sesión.

---

## 2. Inventario de recursos — todo lo que hay que implementar

Lista derivada de [entities.model.ts](/opt/cdc/prd/cdc-front-ng/src/app/core/models/entities.model.ts) + [mantenedores-config.ts](/opt/cdc/prd/cdc-front-ng/src/app/features/mantenedores/mantenedores-config.ts) + componentes concretos (`dashboard`, `cuadros`, `aplicaciones`, `auditoria`).

Cada fila es un `{resource}` distinto bajo `/api/v1/`. La columna "tabla" es el destino en SQL Server (`cdc` schema, ver [UP.sql](/opt/cdc/prd/cdc-infra/database/modelo-datos/UP.sql)). La columna "shape" es la interfaz TypeScript que el front espera recibir (camelCase).

| # | Resource              | Tabla SQL             | PK tipo     | Shape (camelCase) — columnas requeridas por el front                                                                                                                 | CRUD usa el front |
|---|-----------------------|-----------------------|-------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------|
| 1 | `temporadas`          | `cdc.Temporada`       | INT         | `id, codigo, nombre, fechaInicio, fechaFin, activa`                                                                                                                  | list/create/update/delete |
| 2 | `exportadores`        | `cdc.Exportador`      | INT         | `id, codigo, nombre, activo`                                                                                                                                         | list/create/update/delete |
| 3 | `productores`         | `cdc.Productor`       | INT         | `id, rut, nombre, direccion`                                                                                                                                         | list/create/update/delete |
| 4 | `agronomos`           | `cdc.Agronomo`        | INT         | `id, rut, nombre, email`                                                                                                                                             | list/create/update/delete |
| 5 | `especies`            | `cdc.Especie`         | INT         | `id, codigoEspecie, nombreComun, nombreCientifico, estado`                                                                                                           | list/create/update/delete |
| 6 | `variedades`          | `cdc.Variedad`        | INT         | `id, especieId, codigoVariedad, nombreComercial, codigoGrupo, grupoVariedad, activo`                                                                                 | list/create/update/delete |
| 7 | `condiciones-fruta`   | `cdc.CondicionFruta`  | INT         | `id, codigo, glosa`                                                                                                                                                  | list/create/update/delete |
| 8 | `fundos`              | `cdc.Fundo`           | INT         | `id, productorId, agronomoId, codigoSap, codigoSag, nombre, region, provincia, comuna, direccion`                                                                    | list/create/update/delete |
| 9 | `predios`             | `cdc.Predio`          | INT         | `id, fundoId, codigoSap, codigoSag, superficie, georefLatitud, georefLongitud, georefFuente, georefPrecision, georefFecha`                                           | list/create/update/delete |
| 10 | `familias-quimicos`  | `cdc.FamiliaQuimico`  | INT         | `id, codigo, glosa`                                                                                                                                                  | list/create/update/delete |
| 11 | `ingredientes-activos` | `cdc.IngredienteActivo` | INT      | `id, familiaId, codigo, glosa`                                                                                                                                       | list/create/update/delete |
| 12 | `tipos-agua`         | `cdc.TipoAgua`        | INT         | `id, codigo, nombre`                                                                                                                                                 | list/create/update/delete |
| 13 | `patogenos`          | `cdc.Patogeno`        | INT         | `id, codigo, nombre, activo`                                                                                                                                         | list/create/update/delete |
| 14 | `productos`          | `cdc.Producto`        | INT         | `id, codigo, glosa, formulacion, dosisEstandar, unidadMedida`                                                                                                        | list/create/update/delete |
| 15 | `productos-especie`  | `cdc.ProductoEspecie` | BIGINT      | `id, especieId, productoId, activo`                                                                                                                                  | list/create/update/delete |
| 16 | `ingredientes-producto` | `cdc.IngredienteProducto` | BIGINT | `id, ingredienteId, productoId`                                                                                                                                      | list/create/update/delete |
| 17 | `mercados`           | `cdc.Mercado`         | INT         | `id, nombre, activo`                                                                                                                                                 | list/create/update/delete |
| 18 | `reglas`             | `cdc.Regla`           | INT         | `id, productoEspecieId, mercadoId, ppm, dias, activo, unidad, vigenciaDesde, vigenciaHasta, fuente, fechaFuente`                                                     | list/create/update/delete |
| 19 | `cuadros`            | `cdc.Cuadro`          | INT         | `id, temporadaId, predioId, tipoAguaId, variedadId, condicionId, nombre, estado, superficie, observaciones, fechaEstimadaCosecha`                                    | list(con `q`)/create/update/delete |
| 20 | `aplicaciones`       | `cdc.Aplicacion`      | BIGINT      | `id, temporadaId, cuadroId, tipoAguaId, exportadorId, patogenoId, productoId, fechaAplicacion, dosisAplicada, observaciones`                                         | list/create (masivo por N cuadros, el front hace N POSTs en paralelo) |
| 21 | `usuarios`           | `cdc.Usuario`         | BIGINT      | `id, usuario, nombre, email, activo` (el front NO expone `sub` ni `primaryRole` en el mantenedor)                                                                    | list/update/delete (**no create**: los usuarios nacen por login OIDC) |
| 22 | `auditoria`          | `cdc.Auditoria`       | BIGINT      | `id, usuarioId, fechaEvento, operacion, tabla, pk, detalle, beforeJson, afterJson, origen` — **solo lectura**. Usa `q` para buscar texto. (Nota: `beforeJson/afterJson` no existen en la tabla actual; ver §7) | list solo |

**Nota importante sobre casing:** la DB está en PascalCase (`TemporadaId`, `FechaAplicacion`, etc.), el front espera camelCase (`temporadaId`, `fechaAplicacion`). El repositorio/servicio es responsable del mapping en ambos sentidos — NO mutar el schema SQL existente.

---

## 3. Patrón backend ya establecido en CDC (estudiar antes de codear)

Lee estos archivos para absorber el estilo. **No inventes convenciones nuevas; extiende las que ya hay.**

### Config y bootstrap
- [src/app.ts](/opt/cdc/prd/cdc-back/src/app.ts) — ensamblado Express. Línea 52 es el lugar exacto donde se montan las features de negocio (va detrás de `authnMiddleware + csrfMiddleware`).
- [src/config/env.ts](/opt/cdc/prd/cdc-back/src/config/env.ts) — env con zod; si agregas variables, acá se declaran.
- [src/config/logger.ts](/opt/cdc/prd/cdc-back/src/config/logger.ts) — pino.
- [src/infra/db.ts](/opt/cdc/prd/cdc-back/src/infra/db.ts) — pool `mssql`. Usar `const pool = await getPool(); await pool.request().input(...).query(...)`.

### Middleware (todo esto ya existe, úsalo)
- [src/middleware/authn.ts](/opt/cdc/prd/cdc-back/src/middleware/authn.ts) — exige `req.session.userId` + role `cdc-user`, refresca token si queda <30s. **Aplicar a TODAS las features de negocio.**
- [src/middleware/csrf.ts](/opt/cdc/prd/cdc-back/src/middleware/csrf.ts) — valida header `X-CSRF-Token` contra `req.session.csrfToken` (timing-safe). **Aplicar a toda ruta no-GET/HEAD/OPTIONS.**
- [src/middleware/error.ts](/opt/cdc/prd/cdc-back/src/middleware/error.ts) — `HttpError(status, code, message, details?)`, `errorHandler` mapea `ZodError → 422`. **Usa `HttpError` en vez de `res.status().json()` manual.**
- [src/middleware/requestId.ts](/opt/cdc/prd/cdc-back/src/middleware/requestId.ts) — ya inyectado.
- [src/middleware/session.ts](/opt/cdc/prd/cdc-back/src/middleware/session.ts) — sesión Redis.

### Auth feature (patrón de referencia para estructura de carpeta)
- [src/features/auth/auth.controller.ts](/opt/cdc/prd/cdc-back/src/features/auth/auth.controller.ts) — `buildAuthRouter()` que retorna un `Router`.
- [src/features/auth/auth.service.ts](/opt/cdc/prd/cdc-back/src/features/auth/auth.service.ts)
- [src/features/auth/auth.repository.ts](/opt/cdc/prd/cdc-back/src/features/auth/auth.repository.ts) — queries con `pool.request().input(...).query(...)`, `MERGE` para upsert.
- [src/features/auth/auth.audit.ts](/opt/cdc/prd/cdc-back/src/features/auth/auth.audit.ts) — `logAuditEvent()`. **Reutilizar para auditar INSERT/UPDATE/DELETE de negocio** (ver §5).

### Convenciones del repo (no se documentaron en CLAUDE.md, se infieren del código)
- ESM nativo: imports con `.js` aunque los archivos sean `.ts` (`import { x } from './y.js'`).
- `Router` por feature, se compone en `app.ts`.
- Validación: **zod**. Ya está instalado ([package.json](/opt/cdc/prd/cdc-back/package.json)). Mapear a `HttpError(422,...)` lo hace solo el `errorHandler` al tirar un `ZodError`.
- Nada de ORM (Prisma, TypeORM): `mssql` raw con inputs parametrizados (anti-SQLi).
- Nada de controllers como clases: funciones puras y `router.get(...)`.
- Logging: `pino` vía `logger` del módulo config; `req.log` también existe gracias a `pino-http`.
- Respuestas: envolver con `MutationResponse` (`{id, affected}`) en mutaciones y con `PagedResponse<T>` en listas.
- Nada de `any`, nada de `!` non-null assertions sin comentario. TSconfig es strict.

---

## 4. Estructura propuesta por feature (replicar 20 veces)

```
src/features/{resource-kebab}/
├── {resource}.controller.ts   # buildRouter() — rutas + validación zod + llamadas a service
├── {resource}.service.ts      # lógica de negocio, composición de queries, mapping DB↔API
├── {resource}.repository.ts   # solo SQL (queries parametrizadas)
└── {resource}.schema.ts       # zod schemas: Create, Update, Query (listado), Row (DB), Dto (API)
```

Montaje en [src/app.ts:52](/opt/cdc/prd/cdc-back/src/app.ts#L52):

```ts
import { buildTemporadasRouter } from './features/temporadas/temporadas.controller.js';
// ... etc

// Todas las features de negocio van detrás de authn + csrf.
// Crear helper para no repetir: en src/middleware/protect.ts
app.use('/api/v1/temporadas', authnMiddleware, csrfMiddleware, buildTemporadasRouter());
app.use('/api/v1/exportadores', authnMiddleware, csrfMiddleware, buildExportadoresRouter());
// ... 20 líneas así.
```

**Sugerencia:** un helper `protect(router)` que compone `[authnMiddleware, csrfMiddleware, router]` mantiene `app.ts` corto. Evalúa si vale la pena.

---

## 5. Contratos detallados — lo que debe hacer cada feature

### 5.1 Listado — `GET /api/v1/{resource}?page=1&pageSize=20&q=...`

- `page` ≥ 1 (default 1), `pageSize` entre 1 y 500 (default 20 salvo que la UI pida 5).
- `q` opcional: búsqueda case-insensitive en columnas de texto relevantes de la tabla. Decidir por recurso cuáles — ej. `patogenos` → `Codigo` + `Nombre`; `auditoria` → `Operacion` + `Tabla` + `Detalle`.
- Respuesta **obligatoria** `{ page, pageSize, total, data }` con `data` ya mapeado a camelCase.
- `total` debe ser `COUNT(*)` con el mismo filtro `q`. Ideal: una sola query con `COUNT() OVER()` para evitar ida-vuelta.
- Cualquier otro query param extra declarado en la URL (ej. `?productorId=12`) queda a criterio, pero **el front hoy no los manda**: el filtrado jerárquico de `aplicaciones` lo hace en memoria via `fetchAllRows`. No optimizar anticipadamente.

### 5.2 Detail — `GET /api/v1/{resource}/{id}`

- `id` validado como número positivo (o bigint en tablas `BIGINT`).
- 404 si no existe: `HttpError(404, 'not_found', 'Recurso no encontrado')`.
- Devuelve el objeto directo (no sobre).

### 5.3 Create — `POST /api/v1/{resource}`

- Body validado con zod (schema Create — sin `id`, sin `createdAt`/`updatedAt`).
- INSERT con `OUTPUT INSERTED.Id`. Respuesta `{ id }` (status 201).
- Manejar UNIQUE violations del SQL Server como `HttpError(409, 'conflict', 'Ya existe ...')`. Error de mssql tiene `number === 2627` (UNIQUE) o `2601` (INDEX UNIQUE); envolver en el service o repository.
- **Auditar** con `logAuditEvent(req, 'INSERT', detalle)` después del commit exitoso. `Tabla` = nombre de la tabla SQL; `Pk` = id recién insertado.

### 5.4 Update — `PUT /api/v1/{resource}/{id}`

- Body zod Update (todas las columnas opcionales, pero al menos una requerida — usa `.refine()`).
- UPDATE parcial (solo las columnas presentes en el body). Si nada viene → 400.
- 404 si no existe; `affected: 0` no es válido — lanzar `HttpError(404)`.
- Auditar `'UPDATE'`. Guardar en `Detalle` qué columnas cambiaron (no el contenido, solo los nombres — evita filtrar PII al log).

### 5.5 Delete — `DELETE /api/v1/{resource}/{id}`

- DELETE directo. Si hay FK violation (SQL error `547`) → `HttpError(409, 'fk_violation', 'No se puede eliminar: en uso')`.
- 404 si no existía antes del DELETE.
- Auditar `'DELETE'`.

### 5.6 Casos especiales

- **`aplicaciones` POST masivo:** el front llama a `create` una vez por cuadro ([aplicaciones.component.ts:372-374](/opt/cdc/prd/cdc-front-ng/src/app/features/aplicaciones/aplicaciones.component.ts#L372-L374)). **No hacer endpoint batch** — es N POSTs en paralelo, y el front ya lo maneja con `forkJoin`. Solo garantizar que el POST individual funciona.
- **`usuarios` sin POST:** los usuarios se crean via `upsertUsuario()` en el flujo OIDC ([auth.repository.ts](/opt/cdc/prd/cdc-back/src/features/auth/auth.repository.ts)). El mantenedor solo permite listar/editar/desactivar. Implementa PUT y DELETE; para POST devuelve `HttpError(405, 'method_not_allowed', 'Usuarios se crean via login OIDC')`.
- **`auditoria` read-only:** solo `GET /` y `GET /:id`. POST/PUT/DELETE → 405.
- **`cuadros` usa `q`:** [cuadros.component.ts](/opt/cdc/prd/cdc-front-ng/src/app/features/cuadros/cuadros.component.ts) pasa `q`; buscar en `Nombre` al menos.
- **`reglas.ppm` es `VARCHAR(20)`:** soporta valores como `'ST'`, `'EX'` o números como texto. **No coercer a número** — guardar como string tal cual viene. El front declara `ppm: string` a pesar de que el mantenedor lo marca como `type: 'number'` ([mantenedores-config.ts:226](/opt/cdc/prd/cdc-front-ng/src/app/features/mantenedores/mantenedores-config.ts#L226)); confiar en `entities.model.ts`.

---

## 6. Mapping DB ↔ API — regla única

- **DB → API:** snake/Pascal → camel. Fechas `DATETIME2` → ISO 8601 UTC string. `BIT` → `boolean`. `DECIMAL` → `number` (Ojo: JS number perdería precisión en decimales grandes, pero los valores del dominio CDC son chicos; si aparece precisión crítica, usar string — no es el caso actual).
- **API → DB:** inverso. Escribir un mapper por entidad en el repository (no dependencia mágica). Es verbose pero explícito y seguro.

Ejemplo (la forma, no prescribir literalmente):

```ts
// cuadros.repository.ts
function rowToDto(r: CuadroRow): CuadroDto {
  return {
    id: r.Id,
    temporadaId: r.TemporadaId,
    predioId: r.PredioId,
    // ...
    fechaEstimadaCosecha: r.FechaEstimadaCosecha.toISOString(),
  };
}
```

---

## 7. Decisión pendiente: `auditoria.beforeJson / afterJson`

El modelo TS del front declara `beforeJson` y `afterJson` en la interfaz `Auditoria`, pero la tabla `cdc.Auditoria` de [UP.sql:50-61](/opt/cdc/prd/cdc-infra/database/modelo-datos/UP.sql#L50-L61) NO los tiene. Opciones, en orden de preferencia:

1. **Devolver `null` por ahora** (más simple; el front ya maneja `a.detalle` siempre y muestra `beforeJson/afterJson` en un detalle colapsable que queda vacío).
2. Agregar dos columnas `NVARCHAR(MAX)` a la tabla en un nuevo script `UP_002_auditoria_beforejson.sql` y guardar JSON serializado en el middleware de auditoría de mutaciones. Solo tiene sentido si el usuario confirma que quiere el diff completo auditado (agrega tamaño a la tabla).

**Acción recomendada:** preguntar al usuario antes de tocar schema. Por defecto, ir por (1).

---

## 8. Auditoría de mutaciones de negocio

Hoy [auth.audit.ts](/opt/cdc/prd/cdc-back/src/features/auth/auth.audit.ts) solo acepta operaciones `LOGIN|LOGOUT|REFRESH_FAIL|CSRF_FAIL|UNAUTHORIZED|FORBIDDEN_ROLE`. Para CRUD hay que:

1. Ampliar el union `AuditOperacion` con `'INSERT' | 'UPDATE' | 'DELETE'`.
2. Extender la firma para recibir `{ tabla, pk }`:

   ```ts
   logCrudEvent(req, { operacion: 'INSERT', tabla: 'cdc.Patogeno', pk: '123', detalle?: 'cols: codigo,nombre' })
   ```

3. Mantener la garantía de "auditoría no bloquea la request": si falla, `logger.warn` y seguir.

Llamar desde cada repository después del commit, dentro del mismo handler de controller (no pasar `req` hasta el repository — pasar el callback o devolver metadata y que el controller audite). Decide qué es más limpio.

---

## 9. Validación con zod — convención

Cada `*.schema.ts` exporta al menos:

```ts
export const CreateX = z.object({ /* required fields */ });
export const UpdateX = CreateX.partial().refine(o => Object.keys(o).length > 0, { message: 'Cuerpo vacio' });
export const QueryX = z.object({
  page: z.coerce.number().int().positive().default(1),
  pageSize: z.coerce.number().int().min(1).max(500).default(20),
  q: z.string().trim().min(1).optional(),
});
export type CreateXInput = z.infer<typeof CreateX>;
// etc.
```

Cuando una ruta recibe un body inválido, `CreateX.parse(req.body)` tira `ZodError` y el `errorHandler` global ([error.ts:22-32](/opt/cdc/prd/cdc-back/src/middleware/error.ts#L22-L32)) lo serializa como 422. **No capturar ZodError manualmente.**

---

## 10. Plan de trabajo sugerido (para el agente/desarrollador que tome esto)

Orden por dependencias y riesgo (de menor a mayor):

1. **Helpers comunes** que vas a necesitar 20 veces:
   - `src/shared/pagination.ts` — helper que dado `{page, pageSize, total}` y `rows` arma el sobre `PagedResponse`.
   - `src/shared/sql.ts` — traductor de errores mssql (2627/2601 → 409 conflict, 547 → 409 fk).
   - `src/middleware/protect.ts` — helper `protect(router)` que aplica authn+csrf.
   - Extensión de `auth.audit.ts` con `logCrudEvent` (§8).

2. **Mantenedores simples sin FK** (válvula para probar el patrón end-to-end): `temporadas`, `exportadores`, `productores`, `agronomos`, `tipos-agua`, `patogenos`, `mercados`, `familias-quimicos`, `condiciones-fruta`, `especies`, `productos`.

3. **Mantenedores con FK**: `variedades` (→ especie), `fundos` (→ productor/agrónomo), `predios` (→ fundo), `ingredientes-activos` (→ familia), `productos-especie`, `ingredientes-producto`, `reglas`.

4. **Operación**: `cuadros`, `aplicaciones`.

5. **Usuarios** (sin POST, §5.6) y **auditoria** (read-only, §5.6).

6. **Smoke test manual**: entrar al front en `http://192.168.18.18:81`, loguearse, abrir dashboard (lista 4 recursos), luego cada mantenedor, luego `cuadros`, luego `aplicaciones` con el flujo jerárquico completo, luego `auditoria`. Revisar `docker logs cdc-back-prd -f` en paralelo.

---

## 11. Comandos útiles del ambiente

```bash
# Logs en vivo del backend
docker logs cdc-back-prd -f

# Rebuild + recreate tras cambios (auto-deploy está activo en /opt/cdc/prd ante push a main)
cd /opt/cdc/prd/cdc-infra && docker compose up -d --build back

# Queries read-only contra DBCDC desde el container (tiene mssql y env listos)
docker exec cdc-back-prd node -e "
const sql=require('mssql');
(async()=>{
  const p=await sql.connect({user:process.env.DB_USER,password:process.env.DB_PASSWORD,server:process.env.DB_HOST,port:+process.env.DB_PORT,database:process.env.DB_NAME,options:{encrypt:false,trustServerCertificate:true}});
  console.log((await p.request().query('SELECT TOP 5 * FROM cdc.Patogeno')).recordset);
  await p.close();
})()
"

# Probar el endpoint sin el browser (con cookie de sesión válida copiada del navegador)
curl -sS -H 'Cookie: cdc.sid=...' -H 'X-CSRF-Token: ...' \
  http://192.168.18.18:81/api/v1/patogenos?page=1\&pageSize=5
```

---

## 12. Restricciones explícitas (qué NO hacer)

- **No modificar `/opt/cdc/prd/cdc-front-ng`**. El contrato lo define el front.
- **No cambiar el schema SQL** salvo que sea estrictamente necesario (ej. §7). Si hay que cambiar, abrir PR aparte con script `UP_NNN_*.sql` + justificación.
- **No meter ORM ni query builder**. `mssql` raw con inputs parametrizados.
- **No romper el estilo ESM** (imports con `.js`). Si rompe el build, lo sabrás al primer `tsx` pass.
- **No hacer feature flags, compat shims, ni documentación de "cómo migrar"**. Es greenfield: solo implementa.
- **No instalar dependencias sin necesidad**. Todo lo necesario está: `express`, `zod`, `mssql`, `pino`, `helmet`, `express-session`, `connect-redis`. Si crees que falta algo, párate y pregunta.
- **No autoriar commits a prd sin confirmación** — [/opt/*/prd tiene auto-deploy por webhook](/home/hermes/.claude/projects/-opt/memory/feedback_prd_directo.md), cualquier push a `main` se despliega automáticamente. Trabajar en branch `dev` y mergear cuando esté validado.

---

## 13. Criterio de éxito

- Entrar al front, navegar dashboard, cada mantenedor, cuadros, aplicaciones, auditoría — **sin un solo 404 ni 500 en consola**. El único warning aceptable sigue siendo el de COOP/HTTPS (conocido, deuda de TLS).
- Cada mutación produce un row en `cdc.Auditoria` con la operación correcta.
- CRUD conserva integridad referencial (probar que borrar una especie con variedades asociadas tira 409, no 500).
- Bypass de CSRF o de sesión sigue siendo imposible (probar DELETE sin `X-CSRF-Token` → 403; sin cookie → 401).
