IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'cdc')
BEGIN
    IF OBJECT_ID('cdc.CDC_usuario', 'U') IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM cdc.CDC_usuario WHERE usuario = 'admin')
        BEGIN
            INSERT INTO cdc.CDC_usuario (usuario, nombre, email, password_hash, activo)
            VALUES ('admin', 'Administrador CDC', 'admin@cdc.local', 'scrypt:7901a8d1bc296aec67800ae59c9a81bb:5836153c2fac32007ce19f175bddb9adc0779226a7dbc5c543d6d0296fe4147d9db9d8fc7a5346e02c81673d81ce19a9f63725eacd1a84966b8c0432913b615b', 1);
        END
    END
END
GO
