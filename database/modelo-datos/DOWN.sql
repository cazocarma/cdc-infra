SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* =============================================================================
   DROP COMPLETO CDC (DATA + OBJETOS) + ESQUEMA
   - Borra datos respetando dependencias.
   - Elimina FKs, tablas y finalmente el schema [cdc].
============================================================================= */

BEGIN TRY
    BEGIN TRAN;

    /* 1) BORRAR DATA (hijos -> padres) */
    IF OBJECT_ID('cdc.Auditoria','U')           IS NOT NULL DELETE FROM cdc.Auditoria;

    IF OBJECT_ID('cdc.Regla','U')               IS NOT NULL DELETE FROM cdc.Regla;
    IF OBJECT_ID('cdc.ProductoEspecie','U')     IS NOT NULL DELETE FROM cdc.ProductoEspecie;
    IF OBJECT_ID('cdc.IngredienteProducto','U') IS NOT NULL DELETE FROM cdc.IngredienteProducto;

    IF OBJECT_ID('cdc.Aplicacion','U')          IS NOT NULL DELETE FROM cdc.Aplicacion;
    IF OBJECT_ID('cdc.Cuadro','U')              IS NOT NULL DELETE FROM cdc.Cuadro;

    IF OBJECT_ID('cdc.Producto','U')            IS NOT NULL DELETE FROM cdc.Producto;
    IF OBJECT_ID('cdc.IngredienteActivo','U')   IS NOT NULL DELETE FROM cdc.IngredienteActivo;
    IF OBJECT_ID('cdc.FamiliaQuimico','U')      IS NOT NULL DELETE FROM cdc.FamiliaQuimico;

    IF OBJECT_ID('cdc.Variedad','U')            IS NOT NULL DELETE FROM cdc.Variedad;
    IF OBJECT_ID('cdc.Especie','U')             IS NOT NULL DELETE FROM cdc.Especie;

    IF OBJECT_ID('cdc.Predio','U')              IS NOT NULL DELETE FROM cdc.Predio;
    IF OBJECT_ID('cdc.Fundo','U')               IS NOT NULL DELETE FROM cdc.Fundo;
    IF OBJECT_ID('cdc.Agronomo','U')            IS NOT NULL DELETE FROM cdc.Agronomo;
    IF OBJECT_ID('cdc.Productor','U')           IS NOT NULL DELETE FROM cdc.Productor;

    IF OBJECT_ID('cdc.Patogeno','U')            IS NOT NULL DELETE FROM cdc.Patogeno;
    IF OBJECT_ID('cdc.TipoAgua','U')            IS NOT NULL DELETE FROM cdc.TipoAgua;
    IF OBJECT_ID('cdc.Mercado','U')             IS NOT NULL DELETE FROM cdc.Mercado;
    IF OBJECT_ID('cdc.Exportador','U')          IS NOT NULL DELETE FROM cdc.Exportador;
    IF OBJECT_ID('cdc.CondicionFruta','U')      IS NOT NULL DELETE FROM cdc.CondicionFruta;
    IF OBJECT_ID('cdc.Temporada','U')           IS NOT NULL DELETE FROM cdc.Temporada;

    IF OBJECT_ID('cdc.Usuario','U')             IS NOT NULL DELETE FROM cdc.Usuario;

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH;
GO

/* 2) DROPEAR TODAS LAS FKs DEL ESQUEMA [cdc] */
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql + N'
ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(fk.schema_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) +
              N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
FROM sys.foreign_keys fk
WHERE SCHEMA_NAME(fk.schema_id) = 'cdc';

IF (@sql <> N'')
BEGIN
    EXEC sys.sp_executesql @sql;
END
GO

/* 3) DROPEAR TODAS LAS TABLAS DEL ESQUEMA [cdc] */
DECLARE @sql2 NVARCHAR(MAX) = N'';

SELECT @sql2 = @sql2 + N'
DROP TABLE ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N';'
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'cdc';

IF (@sql2 <> N'')
BEGIN
    EXEC sys.sp_executesql @sql2;
END
GO

/* 4) DROPEAR EL ESQUEMA [cdc] */
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'cdc')
BEGIN
    DROP SCHEMA [cdc];
END
GO
