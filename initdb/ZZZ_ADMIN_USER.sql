IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'cdc')
BEGIN
    IF OBJECT_ID('cdc.CDC_usuario', 'U') IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM cdc.CDC_usuario WHERE usuario = 'admin')
        BEGIN
            INSERT INTO cdc.CDC_usuario (usuario, nombre, email, password_hash, activo)
            VALUES ('admin', 'Administrador CDC', 'admin@cdc.local', 'admin', 1);
        END
    END
END
GO
