SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =============================================================================
   MODELO CDC (Cuaderno de Campo) - Esquema: cdc
   Convenciones:
     - Tablas en PascalCase, sin prefijo de aplicacion.
     - Columnas en PascalCase. PK = Id. FKs = <Padre>Id.
     - Restricciones: PK_<Tabla>, FK_<Hija>_<Padre>, UQ_<Tabla>_<Cols>,
                      DF_<Tabla>_<Col>, CK_<Tabla>_<Col>.
     - NVARCHAR para texto libre con posibles acentos.
     - VARCHAR solo para identificadores/codigos ASCII.
     - CreatedAt/UpdatedAt en tablas mutables principales.
============================================================================= */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'cdc')
    EXEC('CREATE SCHEMA [cdc] AUTHORIZATION [dbo];');
GO

/* =========================
   Usuario
========================= */
CREATE TABLE [cdc].[Usuario] (
    [Id]            BIGINT IDENTITY(1,1) NOT NULL,
    [Usuario]       VARCHAR(50)     NOT NULL,
    [Nombre]        NVARCHAR(100)   NOT NULL,
    [Email]         NVARCHAR(150)   NULL,
    [PasswordHash]  VARCHAR(255)    NULL,
    [Activo]        BIT             NOT NULL CONSTRAINT [DF_Usuario_Activo]    DEFAULT(1),
    [CreatedAt]     DATETIME2(0)    NOT NULL CONSTRAINT [DF_Usuario_CreatedAt] DEFAULT(SYSUTCDATETIME()),
    [UpdatedAt]     DATETIME2(0)    NOT NULL CONSTRAINT [DF_Usuario_UpdatedAt] DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT [PK_Usuario]         PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Usuario_Usuario] UNIQUE ([Usuario])
);
GO

/* =========================
   Auditoria
========================= */
CREATE TABLE [cdc].[Auditoria] (
    [Id]           BIGINT IDENTITY(1,1) NOT NULL,
    [UsuarioId]    BIGINT          NULL,
    [FechaEvento]  DATETIME2(0)    NOT NULL CONSTRAINT [DF_Auditoria_FechaEvento] DEFAULT(SYSUTCDATETIME()),
    [Operacion]    VARCHAR(10)     NOT NULL,
    [Tabla]        VARCHAR(128)    NOT NULL,
    [Pk]           VARCHAR(200)    NOT NULL,
    [Detalle]      NVARCHAR(500)   NULL,
    [BeforeJson]   NVARCHAR(MAX)   NULL,
    [AfterJson]    NVARCHAR(MAX)   NULL,
    [Origen]       VARCHAR(50)     NULL CONSTRAINT [DF_Auditoria_Origen] DEFAULT('UI'),
    CONSTRAINT [PK_Auditoria] PRIMARY KEY ([Id])
);
GO

/* =========================
   Mantenedores base
========================= */
CREATE TABLE [cdc].[Temporada] (
    [Id]          INT IDENTITY(1,1) NOT NULL,
    [Codigo]      VARCHAR(20)   NOT NULL,
    [Nombre]      NVARCHAR(100) NOT NULL,
    [FechaInicio] DATETIME2(0)  NOT NULL,
    [FechaFin]    DATETIME2(0)  NOT NULL,
    [Activa]      BIT           NOT NULL CONSTRAINT [DF_Temporada_Activa] DEFAULT(0),
    CONSTRAINT [PK_Temporada]        PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Temporada_Codigo] UNIQUE ([Codigo]),
    CONSTRAINT [CK_Temporada_Fechas] CHECK ([FechaFin] >= [FechaInicio])
);
GO

CREATE TABLE [cdc].[Exportador] (
    [Id]     INT IDENTITY(1,1) NOT NULL,
    [Codigo] VARCHAR(20)   NOT NULL,
    [Nombre] NVARCHAR(100) NOT NULL,
    [Activo] BIT           NOT NULL CONSTRAINT [DF_Exportador_Activo] DEFAULT(1),
    CONSTRAINT [PK_Exportador]        PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Exportador_Codigo] UNIQUE ([Codigo])
);
GO

CREATE TABLE [cdc].[Productor] (
    [Id]        INT IDENTITY(1,1) NOT NULL,
    [Rut]       VARCHAR(20)   NOT NULL,
    [Nombre]    NVARCHAR(100) NOT NULL,
    [Direccion] NVARCHAR(200) NULL,
    CONSTRAINT [PK_Productor]     PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Productor_Rut] UNIQUE ([Rut])
);
GO

CREATE TABLE [cdc].[Agronomo] (
    [Id]     INT IDENTITY(1,1) NOT NULL,
    [Rut]    VARCHAR(20)   NOT NULL,
    [Nombre] NVARCHAR(100) NOT NULL,
    [Email]  NVARCHAR(150) NULL,
    CONSTRAINT [PK_Agronomo]     PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Agronomo_Rut] UNIQUE ([Rut])
);
GO

CREATE TABLE [cdc].[Especie] (
    [Id]               INT IDENTITY(1,1) NOT NULL,
    [CodigoEspecie]    VARCHAR(20)   NOT NULL,
    [NombreComun]      NVARCHAR(100) NOT NULL,
    [NombreCientifico] NVARCHAR(150) NULL,
    [Estado]           BIT           NOT NULL CONSTRAINT [DF_Especie_Estado] DEFAULT(1),
    CONSTRAINT [PK_Especie]               PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Especie_CodigoEspecie] UNIQUE ([CodigoEspecie])
);
GO

CREATE TABLE [cdc].[Variedad] (
    [Id]              INT IDENTITY(1,1) NOT NULL,
    [EspecieId]       INT           NOT NULL,
    [CodigoVariedad]  VARCHAR(20)   NOT NULL,
    [NombreComercial] NVARCHAR(100) NOT NULL,
    [CodigoGrupo]     VARCHAR(20)   NOT NULL,
    [GrupoVariedad]   NVARCHAR(100) NOT NULL,
    [Activo]          BIT           NOT NULL CONSTRAINT [DF_Variedad_Activo] DEFAULT(1),
    CONSTRAINT [PK_Variedad]                       PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Variedad_Especie_NombreComercial] UNIQUE ([EspecieId],[NombreComercial])
);
GO

CREATE TABLE [cdc].[CondicionFruta] (
    [Id]     INT IDENTITY(1,1) NOT NULL,
    [Codigo] VARCHAR(20)   NULL,
    [Glosa]  NVARCHAR(100) NULL,
    CONSTRAINT [PK_CondicionFruta] PRIMARY KEY ([Id])
);
GO

CREATE TABLE [cdc].[Fundo] (
    [Id]          INT IDENTITY(1,1) NOT NULL,
    [ProductorId] INT           NOT NULL,
    [AgronomoId]  INT           NOT NULL,
    [CodigoSap]   VARCHAR(20)   NOT NULL,
    [CodigoSag]   VARCHAR(20)   NOT NULL,
    [Nombre]      NVARCHAR(100) NOT NULL,
    [Region]      NVARCHAR(100) NOT NULL,
    [Provincia]   NVARCHAR(100) NOT NULL,
    [Comuna]      NVARCHAR(100) NOT NULL,
    [Direccion]   NVARCHAR(200) NULL,
    CONSTRAINT [PK_Fundo]           PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Fundo_CodigoSap] UNIQUE ([CodigoSap])
);
GO

CREATE TABLE [cdc].[Predio] (
    [Id]              INT IDENTITY(1,1) NOT NULL,
    [FundoId]         INT           NOT NULL,
    [CodigoSap]       VARCHAR(20)   NOT NULL,
    [CodigoSag]       VARCHAR(20)   NOT NULL,
    [Superficie]      DECIMAL(12,4) NOT NULL,
    [GeorefLatitud]   DECIMAL(9,6)  NULL,
    [GeorefLongitud]  DECIMAL(9,6)  NULL,
    [GeorefFuente]    VARCHAR(20)   NULL,
    [GeorefPrecision] INT           NULL,
    [GeorefFecha]     DATETIME2(0)  NULL,
    CONSTRAINT [PK_Predio]           PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Predio_CodigoSap] UNIQUE ([CodigoSap])
);
GO

CREATE TABLE [cdc].[FamiliaQuimico] (
    [Id]     INT IDENTITY(1,1) NOT NULL,
    [Codigo] VARCHAR(20)   NOT NULL,
    [Glosa]  NVARCHAR(100) NOT NULL,
    CONSTRAINT [PK_FamiliaQuimico]        PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_FamiliaQuimico_Codigo] UNIQUE ([Codigo])
);
GO

CREATE TABLE [cdc].[IngredienteActivo] (
    [Id]        INT IDENTITY(1,1) NOT NULL,
    [FamiliaId] INT           NOT NULL,
    [Codigo]    VARCHAR(20)   NOT NULL,
    [Glosa]     NVARCHAR(200) NOT NULL,
    CONSTRAINT [PK_IngredienteActivo]              PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_IngredienteActivo_Familia_Glosa] UNIQUE ([FamiliaId],[Glosa])
);
GO

CREATE TABLE [cdc].[TipoAgua] (
    [Id]     INT IDENTITY(1,1) NOT NULL,
    [Codigo] VARCHAR(20)   NOT NULL,
    [Nombre] NVARCHAR(100) NOT NULL,
    CONSTRAINT [PK_TipoAgua]        PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_TipoAgua_Codigo] UNIQUE ([Codigo])
);
GO

CREATE TABLE [cdc].[Patogeno] (
    [Id]     INT IDENTITY(1,1) NOT NULL,
    [Codigo] VARCHAR(20)   NOT NULL,
    [Nombre] NVARCHAR(200) NOT NULL,
    [Activo] BIT           NOT NULL CONSTRAINT [DF_Patogeno_Activo] DEFAULT(1),
    CONSTRAINT [PK_Patogeno]        PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Patogeno_Codigo] UNIQUE ([Codigo])
);
GO

/* =========================
   Productos / Quimicos
========================= */
CREATE TABLE [cdc].[Producto] (
    [Id]            INT IDENTITY(1,1) NOT NULL,
    [Codigo]        VARCHAR(50)   NULL,
    [Glosa]         NVARCHAR(200) NOT NULL,
    [Formulacion]   NVARCHAR(50)  NULL,
    [DosisEstandar] DECIMAL(12,4) NULL,
    [UnidadMedida]  NVARCHAR(20)  NULL,
    CONSTRAINT [PK_Producto]       PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Producto_Glosa] UNIQUE ([Glosa])
);
GO

CREATE TABLE [cdc].[ProductoEspecie] (
    [Id]         BIGINT IDENTITY(1,1) NOT NULL,
    [EspecieId]  INT NOT NULL,
    [ProductoId] INT NOT NULL,
    [Activo]     BIT NOT NULL CONSTRAINT [DF_ProductoEspecie_Activo] DEFAULT(1),
    CONSTRAINT [PK_ProductoEspecie]                     PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_ProductoEspecie_Especie_Producto]    UNIQUE ([EspecieId],[ProductoId])
);
GO

CREATE TABLE [cdc].[IngredienteProducto] (
    [Id]            BIGINT IDENTITY(1,1) NOT NULL,
    [IngredienteId] INT NOT NULL,
    [ProductoId]    INT NOT NULL,
    CONSTRAINT [PK_IngredienteProducto]                       PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_IngredienteProducto_Ingrediente_Producto]  UNIQUE ([IngredienteId],[ProductoId])
);
GO

/* =========================
   Operacion (Cuadros / Aplicaciones)
========================= */
CREATE TABLE [cdc].[Cuadro] (
    [Id]                   INT IDENTITY(1,1) NOT NULL,
    [TemporadaId]          INT           NOT NULL,
    [PredioId]             INT           NOT NULL,
    [TipoAguaId]           INT           NOT NULL,
    [VariedadId]           INT           NOT NULL,
    [CondicionId]          INT           NOT NULL,
    [Nombre]               NVARCHAR(100) NOT NULL,
    [Estado]               TINYINT       NOT NULL,
    [Superficie]           DECIMAL(12,4) NULL,
    [Observaciones]        NVARCHAR(300) NULL,
    [FechaEstimadaCosecha] DATETIME2(0)  NOT NULL,
    CONSTRAINT [PK_Cuadro] PRIMARY KEY ([Id])
);
GO

CREATE TABLE [cdc].[Aplicacion] (
    [Id]              BIGINT IDENTITY(1,1) NOT NULL,
    [TemporadaId]     INT           NOT NULL,
    [CuadroId]        INT           NOT NULL,
    [TipoAguaId]      INT           NOT NULL,
    [ExportadorId]    INT           NOT NULL,
    [PatogenoId]      INT           NOT NULL,
    [ProductoId]      INT           NOT NULL,
    [FechaAplicacion] DATETIME2(0)  NOT NULL,
    [DosisAplicada]   DECIMAL(12,4) NOT NULL,
    [Observaciones]   NVARCHAR(500) NULL,
    CONSTRAINT [PK_Aplicacion] PRIMARY KEY ([Id])
);
GO

/* =========================
   Mercado / Reglas
========================= */
CREATE TABLE [cdc].[Mercado] (
    [Id]     INT IDENTITY(1,1) NOT NULL,
    [Nombre] NVARCHAR(100) NOT NULL,
    [Activo] BIT           NOT NULL CONSTRAINT [DF_Mercado_Activo] DEFAULT(1),
    CONSTRAINT [PK_Mercado]        PRIMARY KEY ([Id]),
    CONSTRAINT [UQ_Mercado_Nombre] UNIQUE ([Nombre])
);
GO

CREATE TABLE [cdc].[Regla] (
    [Id]                INT IDENTITY(1,1) NOT NULL,
    [ProductoEspecieId] BIGINT        NOT NULL,
    [MercadoId]         INT           NOT NULL,
    [Ppm]               VARCHAR(20)   NOT NULL,        -- soporta ST/EX y valores numericos
    [Dias]              INT           NOT NULL,
    [Activo]            BIT           NOT NULL CONSTRAINT [DF_Regla_Activo]        DEFAULT(1),
    [Unidad]            VARCHAR(20)   NOT NULL CONSTRAINT [DF_Regla_Unidad]        DEFAULT('ppm'),
    [VigenciaDesde]     DATETIME2(0)  NOT NULL CONSTRAINT [DF_Regla_VigenciaDesde] DEFAULT(SYSUTCDATETIME()),
    [VigenciaHasta]     DATETIME2(0)  NULL,
    [Fuente]            NVARCHAR(100) NULL,
    [FechaFuente]       DATETIME2(0)  NULL,
    CONSTRAINT [PK_Regla] PRIMARY KEY ([Id])
);
GO

/* =========================
   FOREIGN KEYS
========================= */
ALTER TABLE [cdc].[Auditoria]
    ADD CONSTRAINT [FK_Auditoria_Usuario]
    FOREIGN KEY ([UsuarioId]) REFERENCES [cdc].[Usuario]([Id]);
GO

ALTER TABLE [cdc].[Variedad]
    ADD CONSTRAINT [FK_Variedad_Especie]
    FOREIGN KEY ([EspecieId]) REFERENCES [cdc].[Especie]([Id]);
GO

ALTER TABLE [cdc].[Fundo]
    ADD CONSTRAINT [FK_Fundo_Productor]
    FOREIGN KEY ([ProductorId]) REFERENCES [cdc].[Productor]([Id]);
GO
ALTER TABLE [cdc].[Fundo]
    ADD CONSTRAINT [FK_Fundo_Agronomo]
    FOREIGN KEY ([AgronomoId]) REFERENCES [cdc].[Agronomo]([Id]);
GO

ALTER TABLE [cdc].[Predio]
    ADD CONSTRAINT [FK_Predio_Fundo]
    FOREIGN KEY ([FundoId]) REFERENCES [cdc].[Fundo]([Id]);
GO

ALTER TABLE [cdc].[IngredienteActivo]
    ADD CONSTRAINT [FK_IngredienteActivo_FamiliaQuimico]
    FOREIGN KEY ([FamiliaId]) REFERENCES [cdc].[FamiliaQuimico]([Id]);
GO

ALTER TABLE [cdc].[IngredienteProducto]
    ADD CONSTRAINT [FK_IngredienteProducto_IngredienteActivo]
    FOREIGN KEY ([IngredienteId]) REFERENCES [cdc].[IngredienteActivo]([Id]);
GO
ALTER TABLE [cdc].[IngredienteProducto]
    ADD CONSTRAINT [FK_IngredienteProducto_Producto]
    FOREIGN KEY ([ProductoId]) REFERENCES [cdc].[Producto]([Id]);
GO

ALTER TABLE [cdc].[ProductoEspecie]
    ADD CONSTRAINT [FK_ProductoEspecie_Especie]
    FOREIGN KEY ([EspecieId]) REFERENCES [cdc].[Especie]([Id]);
GO
ALTER TABLE [cdc].[ProductoEspecie]
    ADD CONSTRAINT [FK_ProductoEspecie_Producto]
    FOREIGN KEY ([ProductoId]) REFERENCES [cdc].[Producto]([Id]);
GO

ALTER TABLE [cdc].[Cuadro]
    ADD CONSTRAINT [FK_Cuadro_Temporada]
    FOREIGN KEY ([TemporadaId]) REFERENCES [cdc].[Temporada]([Id]);
GO
ALTER TABLE [cdc].[Cuadro]
    ADD CONSTRAINT [FK_Cuadro_Predio]
    FOREIGN KEY ([PredioId]) REFERENCES [cdc].[Predio]([Id]);
GO
ALTER TABLE [cdc].[Cuadro]
    ADD CONSTRAINT [FK_Cuadro_TipoAgua]
    FOREIGN KEY ([TipoAguaId]) REFERENCES [cdc].[TipoAgua]([Id]);
GO
ALTER TABLE [cdc].[Cuadro]
    ADD CONSTRAINT [FK_Cuadro_Variedad]
    FOREIGN KEY ([VariedadId]) REFERENCES [cdc].[Variedad]([Id]);
GO
ALTER TABLE [cdc].[Cuadro]
    ADD CONSTRAINT [FK_Cuadro_CondicionFruta]
    FOREIGN KEY ([CondicionId]) REFERENCES [cdc].[CondicionFruta]([Id]);
GO

ALTER TABLE [cdc].[Aplicacion]
    ADD CONSTRAINT [FK_Aplicacion_Temporada]
    FOREIGN KEY ([TemporadaId]) REFERENCES [cdc].[Temporada]([Id]);
GO
ALTER TABLE [cdc].[Aplicacion]
    ADD CONSTRAINT [FK_Aplicacion_Cuadro]
    FOREIGN KEY ([CuadroId]) REFERENCES [cdc].[Cuadro]([Id]);
GO
ALTER TABLE [cdc].[Aplicacion]
    ADD CONSTRAINT [FK_Aplicacion_TipoAgua]
    FOREIGN KEY ([TipoAguaId]) REFERENCES [cdc].[TipoAgua]([Id]);
GO
ALTER TABLE [cdc].[Aplicacion]
    ADD CONSTRAINT [FK_Aplicacion_Exportador]
    FOREIGN KEY ([ExportadorId]) REFERENCES [cdc].[Exportador]([Id]);
GO
ALTER TABLE [cdc].[Aplicacion]
    ADD CONSTRAINT [FK_Aplicacion_Patogeno]
    FOREIGN KEY ([PatogenoId]) REFERENCES [cdc].[Patogeno]([Id]);
GO
ALTER TABLE [cdc].[Aplicacion]
    ADD CONSTRAINT [FK_Aplicacion_Producto]
    FOREIGN KEY ([ProductoId]) REFERENCES [cdc].[Producto]([Id]);
GO

ALTER TABLE [cdc].[Regla]
    ADD CONSTRAINT [FK_Regla_ProductoEspecie]
    FOREIGN KEY ([ProductoEspecieId]) REFERENCES [cdc].[ProductoEspecie]([Id]);
GO
ALTER TABLE [cdc].[Regla]
    ADD CONSTRAINT [FK_Regla_Mercado]
    FOREIGN KEY ([MercadoId]) REFERENCES [cdc].[Mercado]([Id]);
GO

/* =========================
   Indices no clustered en FKs frecuentes
========================= */
CREATE INDEX [IX_Variedad_EspecieId]              ON [cdc].[Variedad]([EspecieId]);
CREATE INDEX [IX_Predio_FundoId]                  ON [cdc].[Predio]([FundoId]);
CREATE INDEX [IX_Fundo_ProductorId]               ON [cdc].[Fundo]([ProductorId]);
CREATE INDEX [IX_Fundo_AgronomoId]                ON [cdc].[Fundo]([AgronomoId]);
CREATE INDEX [IX_IngredienteActivo_FamiliaId]     ON [cdc].[IngredienteActivo]([FamiliaId]);
CREATE INDEX [IX_IngredienteProducto_ProductoId]  ON [cdc].[IngredienteProducto]([ProductoId]);
CREATE INDEX [IX_ProductoEspecie_ProductoId]      ON [cdc].[ProductoEspecie]([ProductoId]);
CREATE INDEX [IX_Cuadro_PredioId]                 ON [cdc].[Cuadro]([PredioId]);
CREATE INDEX [IX_Cuadro_TemporadaId]              ON [cdc].[Cuadro]([TemporadaId]);
CREATE INDEX [IX_Cuadro_VariedadId]               ON [cdc].[Cuadro]([VariedadId]);
CREATE INDEX [IX_Aplicacion_CuadroId]             ON [cdc].[Aplicacion]([CuadroId]);
CREATE INDEX [IX_Aplicacion_ProductoId]           ON [cdc].[Aplicacion]([ProductoId]);
CREATE INDEX [IX_Aplicacion_TemporadaId]          ON [cdc].[Aplicacion]([TemporadaId]);
CREATE INDEX [IX_Regla_MercadoId]                 ON [cdc].[Regla]([MercadoId]);
CREATE INDEX [IX_Regla_ProductoEspecieId]         ON [cdc].[Regla]([ProductoEspecieId]);
GO
