SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* =============================================================================
   DROP COMPLETO CDC (DATA + OBJETOS) + ESQUEMA
   - Elimina datos (por si hay FKs)
   - Luego elimina FKs, tablas y finalmente el schema [cdc]
   - Ejecutar en la BD objetivo (ej: DBPRD)
============================================================================= */

BEGIN TRY
    BEGIN TRAN;

    /* 1) BORRAR DATA (hijos -> padres) */
    IF OBJECT_ID('cdc.CDC_auditoria','U') IS NOT NULL DELETE FROM cdc.CDC_auditoria;

    IF OBJECT_ID('cdc.CDC_regla','U') IS NOT NULL DELETE FROM cdc.CDC_regla;
    IF OBJECT_ID('cdc.CDC_producto_especie','U') IS NOT NULL DELETE FROM cdc.CDC_producto_especie;
    IF OBJECT_ID('cdc.CDC_ingrediente_producto','U') IS NOT NULL DELETE FROM cdc.CDC_ingrediente_producto;

    IF OBJECT_ID('cdc.CDC_aplicacion','U') IS NOT NULL DELETE FROM cdc.CDC_aplicacion;
    IF OBJECT_ID('cdc.CDC_Cuadro','U') IS NOT NULL DELETE FROM cdc.CDC_Cuadro;

    IF OBJECT_ID('cdc.CDC_producto','U') IS NOT NULL DELETE FROM cdc.CDC_producto;
    IF OBJECT_ID('cdc.CDC_ingrediente_activo','U') IS NOT NULL DELETE FROM cdc.CDC_ingrediente_activo;
    IF OBJECT_ID('cdc.CDC_familia_quimico','U') IS NOT NULL DELETE FROM cdc.CDC_familia_quimico;

    IF OBJECT_ID('cdc.CDC_variedad','U') IS NOT NULL DELETE FROM cdc.CDC_variedad;
    IF OBJECT_ID('cdc.CDC_especie','U') IS NOT NULL DELETE FROM cdc.CDC_especie;

    IF OBJECT_ID('cdc.CDC_predio','U') IS NOT NULL DELETE FROM cdc.CDC_predio;
    IF OBJECT_ID('cdc.CDC_fundo','U') IS NOT NULL DELETE FROM cdc.CDC_fundo;
    IF OBJECT_ID('cdc.CDC_agronomo','U') IS NOT NULL DELETE FROM cdc.CDC_agronomo;
    IF OBJECT_ID('cdc.CDC_productor','U') IS NOT NULL DELETE FROM cdc.CDC_productor;

    IF OBJECT_ID('cdc.CDC_patogeno','U') IS NOT NULL DELETE FROM cdc.CDC_patogeno;
    IF OBJECT_ID('cdc.CDC_tipo_agua','U') IS NOT NULL DELETE FROM cdc.CDC_tipo_agua;
    IF OBJECT_ID('cdc.CDC_mercado','U') IS NOT NULL DELETE FROM cdc.CDC_mercado;
    IF OBJECT_ID('cdc.CDC_exportador','U') IS NOT NULL DELETE FROM cdc.CDC_exportador;
    IF OBJECT_ID('cdc.CDC_condicion_fruta','U') IS NOT NULL DELETE FROM cdc.CDC_condicion_fruta;
    IF OBJECT_ID('cdc.CDC_temporada','U') IS NOT NULL DELETE FROM cdc.CDC_temporada;

    IF OBJECT_ID('cdc.CDC_usuario','U') IS NOT NULL DELETE FROM cdc.CDC_usuario;

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
