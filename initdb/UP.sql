SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =============================================================================
   MODELO CDC (Cuaderno de Campo) - Esquema: cdc
   - Tablas prefijo CDC_
   - Relaciones FK corregidas
   - CDC_usuario + CDC_auditoria para registro de cambios
   - CDC_regla soporta ppm como texto (ST/EX) + vigencia/unidad/fuente
============================================================================= */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'cdc')
    EXEC('CREATE SCHEMA [cdc] AUTHORIZATION [dbo];');
GO

/* =========================
   CDC_usuario (independiente)
========================= */
CREATE TABLE [cdc].[CDC_usuario] (
    [id_usuario]     BIGINT IDENTITY(1,1) NOT NULL,
    [usuario]        VARCHAR(50)  NOT NULL,
    [nombre]         VARCHAR(100) NOT NULL,
    [email]          VARCHAR(100) NULL,
    [password_hash]  VARCHAR(255) NULL,
    [activo]         BIT NOT NULL CONSTRAINT DF_CDC_usuario_activo DEFAULT(1),
    [created_at]     DATETIME2(0) NOT NULL CONSTRAINT DF_CDC_usuario_created DEFAULT(SYSUTCDATETIME()),
    [updated_at]     DATETIME2(0) NOT NULL CONSTRAINT DF_CDC_usuario_updated DEFAULT(SYSUTCDATETIME()),
    CONSTRAINT [PK_CDC_usuario] PRIMARY KEY ([id_usuario]),
    CONSTRAINT [UQ_CDC_usuario_usuario] UNIQUE ([usuario])
);
GO

/* =========================
   CDC_auditoria
========================= */
CREATE TABLE [cdc].[CDC_auditoria] (
    [id_auditoria] BIGINT IDENTITY(1,1) NOT NULL,
    [id_usuario]   BIGINT NULL,
    [fecha_evento] DATETIME2(0) NOT NULL CONSTRAINT DF_CDC_auditoria_fecha DEFAULT(SYSUTCDATETIME()),
    [operacion]    VARCHAR(10)  NOT NULL,
    [tabla]        VARCHAR(128) NOT NULL,
    [pk]           VARCHAR(200) NOT NULL,
    [detalle]      VARCHAR(500) NULL,
    [before_json]  NVARCHAR(MAX) NULL,
    [after_json]   NVARCHAR(MAX) NULL,
    [origen]       VARCHAR(50) NULL CONSTRAINT DF_CDC_auditoria_origen DEFAULT('UI'),
    CONSTRAINT [PK_CDC_auditoria] PRIMARY KEY ([id_auditoria])
);
GO

ALTER TABLE [cdc].[CDC_auditoria]
ADD CONSTRAINT [FK_CDC_auditoria_usuario]
FOREIGN KEY([id_usuario]) REFERENCES [cdc].[CDC_usuario]([id_usuario]);
GO

/* =========================
   Mantenedores base
========================= */
CREATE TABLE [cdc].[CDC_temporada] (
    [id_temporada] INTEGER IDENTITY(1,1) NOT NULL,
    [codigo]       VARCHAR(20)  NOT NULL,
    [nombre]       VARCHAR(100) NOT NULL,
    [fecha_inicio] DATETIME2(0) NOT NULL,
    [fecha_fin]    DATETIME2(0) NOT NULL,
    [activa]       BIT NOT NULL,
    CONSTRAINT [PK_CDC_temporada] PRIMARY KEY ([id_temporada]),
    CONSTRAINT [UQ_CDC_temporada_codigo] UNIQUE ([codigo])
);
GO

CREATE TABLE [cdc].[CDC_exportador] (
    [id_exportador] INTEGER IDENTITY(1,1) NOT NULL,
    [codigo]        VARCHAR(20)  NOT NULL,
    [nombre]        VARCHAR(100) NOT NULL,
    [activo]        BIT NOT NULL,
    CONSTRAINT [PK_CDC_exportador] PRIMARY KEY ([id_exportador]),
    CONSTRAINT [UQ_CDC_exportador_codigo] UNIQUE ([codigo])
);
GO

CREATE TABLE [cdc].[CDC_productor] (
    [id_productor] INTEGER IDENTITY(1,1) NOT NULL,
    [rut]          VARCHAR(20)  NOT NULL,
    [nombre]       VARCHAR(100) NOT NULL,
    [direccion]    VARCHAR(200) NULL,
    CONSTRAINT [PK_CDC_productor] PRIMARY KEY ([id_productor]),
    CONSTRAINT [UQ_CDC_productor_rut] UNIQUE ([rut])
);
GO

CREATE TABLE [cdc].[CDC_agronomo] (
    [id_agronomo] INTEGER IDENTITY(1,1) NOT NULL,
    [rut]         VARCHAR(20)  NOT NULL,
    [nombre]      VARCHAR(100) NOT NULL,
    [email]       VARCHAR(100) NULL,
    CONSTRAINT [PK_CDC_agronomo] PRIMARY KEY ([id_agronomo]),
    CONSTRAINT [UQ_CDC_agronomo_rut] UNIQUE ([rut])
);
GO

CREATE TABLE [cdc].[CDC_especie] (
    [id_especie]       INTEGER IDENTITY(1,1) NOT NULL,
    [codigo_especie]   VARCHAR(20)  NOT NULL,
    [nombre_comun]     VARCHAR(100) NOT NULL,
    [nombre_cientifico]VARCHAR(150) NULL,
    [estado]           BIT NOT NULL,
    CONSTRAINT [PK_CDC_especie] PRIMARY KEY ([id_especie]),
    CONSTRAINT [UQ_CDC_especie_codigo] UNIQUE ([codigo_especie])
);
GO

CREATE TABLE [cdc].[CDC_variedad] (
    [id_variedad]     INTEGER IDENTITY(1,1) NOT NULL,
    [id_especie]      INTEGER NOT NULL,
    [codigo_variedad] VARCHAR(20)  NOT NULL,
    [nombre_comercial]VARCHAR(100) NOT NULL,
    [id_grupo_variedad] VARCHAR(20) NOT NULL,
    [grupo_variedad]  VARCHAR(100) NOT NULL,
    [activo]          BIT NOT NULL,
    CONSTRAINT [PK_CDC_variedad] PRIMARY KEY ([id_variedad])
);
GO

CREATE TABLE [cdc].[CDC_condicion_fruta] (
    [id_condicion] INTEGER IDENTITY(1,1) NOT NULL,
    [codigo]       VARCHAR(20) NULL,
    [glosa]        VARCHAR(100) NULL,
    CONSTRAINT [PK_CDC_condicion_fruta] PRIMARY KEY([id_condicion])
);
GO

CREATE TABLE [cdc].[CDC_fundo] (
    [id_fundo]   INTEGER IDENTITY(1,1) NOT NULL,
    [id_productor] INTEGER NOT NULL,
    [id_agronomo]  INTEGER NOT NULL,
    [codigo_sap] VARCHAR(20) NOT NULL,
    [codigo_sag] VARCHAR(20) NOT NULL,
    [nombre]     VARCHAR(100) NOT NULL,
    [region]     VARCHAR(100) NOT NULL,
    [provincia]  VARCHAR(100) NOT NULL,
    [comuna]     VARCHAR(100) NOT NULL,
    [direccion]  VARCHAR(200) NULL,
    CONSTRAINT [PK_CDC_fundo] PRIMARY KEY([id_fundo])
);
GO

CREATE TABLE [cdc].[CDC_predio] (
    [id_predio] INTEGER IDENTITY(1,1) NOT NULL,
    [id_fundo]  INTEGER NOT NULL,
    [codigo_sap] VARCHAR(20) NOT NULL,
    [codigo_sag] VARCHAR(20) NOT NULL,
    [superficie] FLOAT NOT NULL,
    [georef_latitud]  DECIMAL(9,6) NULL,
    [georef_longitud] DECIMAL(9,6) NULL,
    [georef_fuente]   VARCHAR(20) NULL,
    [georef_precision]INTEGER NULL,
    [georef_fecha]    DATETIME2(0) NULL,
    CONSTRAINT [PK_CDC_predio] PRIMARY KEY([id_predio])
);
GO

CREATE TABLE [cdc].[CDC_familia_quimico] (
    [id_familia] INTEGER IDENTITY(1,1) NOT NULL,
    [codigo]     VARCHAR(20) NOT NULL,
    [glosa]      VARCHAR(100) NOT NULL,
    CONSTRAINT [PK_CDC_familia_quimico] PRIMARY KEY([id_familia]),
    CONSTRAINT [UQ_CDC_familia_quimico_codigo] UNIQUE([codigo])
);
GO

CREATE TABLE [cdc].[CDC_ingrediente_activo] (
    [id_ingrediente] INTEGER IDENTITY(1,1) NOT NULL,
    [id_familia]     INTEGER NOT NULL,
    [codigo]         VARCHAR(20)  NOT NULL,
    [glosa]          VARCHAR(200) NOT NULL,
    CONSTRAINT [PK_CDC_ingrediente_activo] PRIMARY KEY([id_ingrediente])
);
GO

CREATE TABLE [cdc].[CDC_tipo_agua] (
    [id_tipo_agua] INTEGER IDENTITY(1,1) NOT NULL,
    [codigo] VARCHAR(20) NOT NULL,
    [nombre] VARCHAR(100) NOT NULL,
    CONSTRAINT [PK_CDC_tipo_agua] PRIMARY KEY([id_tipo_agua]),
    CONSTRAINT [UQ_CDC_tipo_agua_codigo] UNIQUE([codigo])
);
GO

CREATE TABLE [cdc].[CDC_patogeno] (
    [id_patogeno] INTEGER IDENTITY(1,1) NOT NULL,
    [codigo] VARCHAR(20) NOT NULL,
    [nombre] VARCHAR(200) NOT NULL,
    [activo] BIT NOT NULL,
    CONSTRAINT [PK_CDC_patogeno] PRIMARY KEY([id_patogeno]),
    CONSTRAINT [UQ_CDC_patogeno_codigo] UNIQUE([codigo])
);
GO

/* =========================
   Químicos / Productos
========================= */
CREATE TABLE [cdc].[CDC_producto] (
    [id_producto]    INTEGER IDENTITY(1,1) NOT NULL,
    [codigo]         VARCHAR(50) NULL,
    [glosa]          VARCHAR(200) NOT NULL,
    [formulacion]    VARCHAR(50) NULL,
    [dosis_estandar] FLOAT NULL,
    [unidad_medida]  VARCHAR(20) NULL,
    CONSTRAINT [PK_CDC_producto] PRIMARY KEY([id_producto]),
    CONSTRAINT [UQ_CDC_producto_glosa] UNIQUE([glosa])
);
GO

CREATE TABLE [cdc].[CDC_producto_especie] (
    [id_producto_especie] BIGINT IDENTITY(1,1) NOT NULL,
    [id_especie]  INTEGER NOT NULL,
    [id_producto] INTEGER NOT NULL,
    [activo]      BIT NOT NULL,
    CONSTRAINT [PK_CDC_producto_especie] PRIMARY KEY([id_producto_especie]),
    CONSTRAINT [UQ_CDC_producto_especie] UNIQUE([id_especie],[id_producto])
);
GO

CREATE TABLE [cdc].[CDC_ingrediente_producto] (
    [id_ingrediente_producto] BIGINT IDENTITY(1,1) NOT NULL,
    [id_ingrediente] INTEGER NOT NULL,
    [id_producto]    INTEGER NOT NULL,
    CONSTRAINT [PK_CDC_ingrediente_producto] PRIMARY KEY([id_ingrediente_producto]),
    CONSTRAINT [UQ_CDC_ingrediente_producto] UNIQUE([id_ingrediente],[id_producto])
);
GO

/* =========================
   Campo (Cuadros / Aplicaciones)
========================= */
CREATE TABLE [cdc].[CDC_cuadro] (
    [id_cuadro] INTEGER IDENTITY(1,1) NOT NULL,
    [id_temporada]  INTEGER NOT NULL,
    [id_predio]     INTEGER NOT NULL,
    [id_tipo_agua]  INTEGER NOT NULL,
    [id_variedad]   INTEGER NOT NULL,
    [id_condicion]  INTEGER NOT NULL,
    [nombre]        VARCHAR(100) NOT NULL,
    [estado]        TINYINT NOT NULL,
    [superficie]    FLOAT NULL,
    [observaciones] VARCHAR(300) NULL,
    [fecha_estimada_cosecha] DATETIME2(0) NOT NULL,
    CONSTRAINT [PK_CDC_Cuadro] PRIMARY KEY([id_cuadro])
);
GO

CREATE TABLE [cdc].[CDC_aplicacion] (
    [id_aplicacion] BIGINT IDENTITY(1,1) NOT NULL,
    [id_temporada]  INTEGER NOT NULL,
    [id_cuadro]     INTEGER NOT NULL,
    [id_tipo_agua]  INTEGER NOT NULL,
    [id_exportador] INTEGER NOT NULL,
    [id_patogeno]   INTEGER NOT NULL,
    [id_producto]   INTEGER NOT NULL,
    [fecha_aplicacion] DATETIME2(0) NOT NULL,
    [dosis_aplicada] FLOAT NOT NULL,
    [observaciones] VARCHAR(500) NOT NULL,
    CONSTRAINT [PK_CDC_aplicacion] PRIMARY KEY([id_aplicacion])
);
GO

/* =========================
   Mercado / Reglas
========================= */
CREATE TABLE [cdc].[CDC_mercado] (
    [id_mercado] INTEGER IDENTITY(1,1) NOT NULL,
    [nombre] VARCHAR(100) NOT NULL,
    [activo] BIT NOT NULL,
    CONSTRAINT [PK_CDC_mercado] PRIMARY KEY([id_mercado]),
    CONSTRAINT [UQ_CDC_mercado_nombre] UNIQUE([nombre])
);
GO

CREATE TABLE [cdc].[CDC_regla] (
    [id_regla] INTEGER IDENTITY(1,1) NOT NULL,
    [id_producto_especie] BIGINT NOT NULL,
    [id_mercado] INTEGER NOT NULL,
    [ppm] VARCHAR(20) NOT NULL,        -- soporta ST/EX además de valores numéricos
    [dias] INTEGER NOT NULL,
    [activo] BIT NOT NULL,
    [unidad] VARCHAR(20) NOT NULL CONSTRAINT DF_CDC_regla_unidad DEFAULT('ppm'),
    [vigencia_desde] DATETIME2(0) NOT NULL CONSTRAINT DF_CDC_regla_vig DEFAULT(SYSUTCDATETIME()),
    [vigencia_hasta] DATETIME2(0) NULL,
    [fuente] VARCHAR(100) NULL,
    [fecha_fuente] DATETIME2(0) NULL,
    CONSTRAINT [PK_CDC_regla] PRIMARY KEY([id_regla])
);
GO

/* =========================
   Ajustes incrementalmente idempotentes
========================= */
IF COL_LENGTH('cdc.CDC_cuadro', 'superficie') IS NULL
BEGIN
    ALTER TABLE [cdc].[CDC_cuadro]
    ADD [superficie] FLOAT NULL;
END
GO

/* =========================
   FOREIGN KEYS (corregidas)
========================= */
ALTER TABLE [cdc].[CDC_variedad]
ADD CONSTRAINT [FK_CDC_variedad_especie]
FOREIGN KEY([id_especie]) REFERENCES [cdc].[CDC_especie]([id_especie]);
GO

ALTER TABLE [cdc].[CDC_fundo]
ADD CONSTRAINT [FK_CDC_fundo_productor]
FOREIGN KEY([id_productor]) REFERENCES [cdc].[CDC_productor]([id_productor]);
GO

ALTER TABLE [cdc].[CDC_fundo]
ADD CONSTRAINT [FK_CDC_fundo_agronomo]
FOREIGN KEY([id_agronomo]) REFERENCES [cdc].[CDC_agronomo]([id_agronomo]);
GO

ALTER TABLE [cdc].[CDC_predio]
ADD CONSTRAINT [FK_CDC_predio_fundo]
FOREIGN KEY([id_fundo]) REFERENCES [cdc].[CDC_fundo]([id_fundo]);
GO

ALTER TABLE [cdc].[CDC_ingrediente_activo]
ADD CONSTRAINT [FK_CDC_ingrediente_activo_familia]
FOREIGN KEY([id_familia]) REFERENCES [cdc].[CDC_familia_quimico]([id_familia]);
GO

ALTER TABLE [cdc].[CDC_ingrediente_producto]
ADD CONSTRAINT [FK_CDC_ingrediente_producto_ingrediente]
FOREIGN KEY([id_ingrediente]) REFERENCES [cdc].[CDC_ingrediente_activo]([id_ingrediente]);
GO

ALTER TABLE [cdc].[CDC_ingrediente_producto]
ADD CONSTRAINT [FK_CDC_ingrediente_producto_producto]
FOREIGN KEY([id_producto]) REFERENCES [cdc].[CDC_producto]([id_producto]);
GO

ALTER TABLE [cdc].[CDC_producto_especie]
ADD CONSTRAINT [FK_CDC_producto_especie_especie]
FOREIGN KEY([id_especie]) REFERENCES [cdc].[CDC_especie]([id_especie]);
GO

ALTER TABLE [cdc].[CDC_producto_especie]
ADD CONSTRAINT [FK_CDC_producto_especie_producto]
FOREIGN KEY([id_producto]) REFERENCES [cdc].[CDC_producto]([id_producto]);
GO

ALTER TABLE [cdc].[CDC_cuadro]
ADD CONSTRAINT [FK_CDC_cuadro_temporada]
FOREIGN KEY([id_temporada]) REFERENCES [cdc].[CDC_temporada]([id_temporada]);
GO
ALTER TABLE [cdc].[CDC_cuadro]
ADD CONSTRAINT [FK_CDC_cuadro_predio]
FOREIGN KEY([id_predio]) REFERENCES [cdc].[CDC_predio]([id_predio]);
GO
ALTER TABLE [cdc].[CDC_cuadro]
ADD CONSTRAINT [FK_CDC_cuadro_tipo_agua]
FOREIGN KEY([id_tipo_agua]) REFERENCES [cdc].[CDC_tipo_agua]([id_tipo_agua]);
GO
ALTER TABLE [cdc].[CDC_cuadro]
ADD CONSTRAINT [FK_CDC_cuadro_variedad]
FOREIGN KEY([id_variedad]) REFERENCES [cdc].[CDC_variedad]([id_variedad]);
GO
ALTER TABLE [cdc].[CDC_cuadro]
ADD CONSTRAINT [FK_CDC_cuadro_condicion]
FOREIGN KEY([id_condicion]) REFERENCES [cdc].[CDC_condicion_fruta]([id_condicion]);
GO

ALTER TABLE [cdc].[CDC_aplicacion]
ADD CONSTRAINT [FK_CDC_aplicacion_temporada]
FOREIGN KEY([id_temporada]) REFERENCES [cdc].[CDC_temporada]([id_temporada]);
GO
ALTER TABLE [cdc].[CDC_aplicacion]
ADD CONSTRAINT [FK_CDC_aplicacion_cuadro]
FOREIGN KEY([id_cuadro]) REFERENCES [cdc].[CDC_Cuadro]([id_cuadro]);
GO
ALTER TABLE [cdc].[CDC_aplicacion]
ADD CONSTRAINT [FK_CDC_aplicacion_tipo_agua]
FOREIGN KEY([id_tipo_agua]) REFERENCES [cdc].[CDC_tipo_agua]([id_tipo_agua]);
GO
ALTER TABLE [cdc].[CDC_aplicacion]
ADD CONSTRAINT [FK_CDC_aplicacion_exportador]
FOREIGN KEY([id_exportador]) REFERENCES [cdc].[CDC_exportador]([id_exportador]);
GO
ALTER TABLE [cdc].[CDC_aplicacion]
ADD CONSTRAINT [FK_CDC_aplicacion_patogeno]
FOREIGN KEY([id_patogeno]) REFERENCES [cdc].[CDC_patogeno]([id_patogeno]);
GO
ALTER TABLE [cdc].[CDC_aplicacion]
ADD CONSTRAINT [FK_CDC_aplicacion_producto]
FOREIGN KEY([id_producto]) REFERENCES [cdc].[CDC_producto]([id_producto]);
GO

ALTER TABLE [cdc].[CDC_regla]
ADD CONSTRAINT [FK_CDC_regla_producto_especie]
FOREIGN KEY([id_producto_especie]) REFERENCES [cdc].[CDC_producto_especie]([id_producto_especie]);
GO
ALTER TABLE [cdc].[CDC_regla]
ADD CONSTRAINT [FK_CDC_regla_mercado]
FOREIGN KEY([id_mercado]) REFERENCES [cdc].[CDC_mercado]([id_mercado]);
GO
