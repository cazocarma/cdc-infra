IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'cdc')
BEGIN
    IF OBJECT_ID('cdc.Usuario', 'U') IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM cdc.Usuario WHERE Usuario = 'admin')
        BEGIN
            -- PasswordHash: SHA-256 hex de '123456789' con prefijo soportado por el backend
            INSERT INTO cdc.Usuario (Usuario, Nombre, Email, PasswordHash, Activo)
            VALUES (
                'admin',
                'Administrador',
                'admin@local.test',
                'sha256:15e2b0d3c33891ebb0f1ef609ec419420c20e320ce94c65fbc8c3312448eb225',
                1
            );
        END
    END
END
GO
