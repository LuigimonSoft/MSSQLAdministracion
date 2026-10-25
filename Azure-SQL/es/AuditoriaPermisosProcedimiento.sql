/*
Auditoría de permisos explícitos del procedimiento

Auditoría de solo lectura de los permisos explícitos visibles a nivel de objeto de un procedimiento SQL y de su contexto de ejecución declarado. Muestra esquema y procedimiento, identificador y nombre resuelto del principal de EXECUTE AS, propietario actual del objeto, destinatario y tipo de principal, otorgante, permiso y estado. El destinatario puede ser un usuario, un rol u otro principal de base de datos; no se expande su pertenencia.

Ejecutar en la base de datos de destino y sustituir @Schema y @Procedure. LLAMADOR deja ExecuteAsPrincipal en NULL porque el llamador depende de cada invocación. PROPIETARIO resuelve el propietario actual del objeto y utiliza el del esquema si no hay uno explícito. Un identificador de principal puede corresponder a EXECUTE AS SELF o a un usuario nombrado explícitamente; por sí solo no distingue la declaración original. Los nombres de columnas y las descripciones de permisos y tipos proporcionadas por el catálogo permanecen en inglés.

Se aplican las restricciones de visibilidad de metadatos: los resultados pueden ser incompletos si la cuenta auditora no puede ver el objeto, módulo, permisos y principales pertinentes. Utilizar una cuenta autorizada con visibilidad suficiente, como el propietario de la base de datos, para una revisión completa a nivel de objeto. OBJECT_ID puede devolver NULL si el procedimiento SQL no existe o no es visible. Una fila con columnas de permisos NULL indica que no se ve ningún permiso explícito, no que nadie pueda ejecutar el procedimiento. Un nombre de principal resuelto NULL puede indicar metadatos no disponibles.

No calcula permisos efectivos derivados de pertenencia a roles, incluidos roles fijos, propiedad, permisos de esquema, base de datos o servidor, cadenas de propiedad, firmas de módulos u otros contextos de ejecución. Tampoco demuestra ni descarta SQL Injection: eso requiere analizar el código y el tratamiento de entradas. No concede, deniega ni revoca permisos ni suplanta usuarios. Aplicable a Azure SQL Database, Azure SQL Managed Instance y SQL Server 2016 o posterior.

https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql
https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql
*/

SET NOCOUNT ON;

-- Indicar el procedimiento SQL de la base de datos actual.
DECLARE @Schema sysname = N'dbo';
DECLARE @Procedure sysname = N'TuProcedimientoAlmacenado';

DECLARE @ObjectId int = OBJECT_ID(
    QUOTENAME(@Schema) + N'.' + QUOTENAME(@Procedure), N'P'
);

IF @ObjectId IS NULL
BEGIN
    THROW 50001, N'Procedimiento almacenado SQL no encontrado o no visible para el usuario actual.', 1;
END;

SELECT
    sc.name AS SchemaName,
    o.name AS ProcedureName,
    m.execute_as_principal_id AS ExecuteAsPrincipalId,
    CASE
        WHEN m.execute_as_principal_id = -2 THEN owner_principal.name
        WHEN m.execute_as_principal_id IS NULL THEN NULL
        ELSE execution_principal.name
    END AS ExecuteAsPrincipal,
    CASE
        WHEN m.execute_as_principal_id = -2 THEN N'PROPIETARIO'
        WHEN m.execute_as_principal_id IS NULL THEN N'LLAMADOR'
        ELSE N'USUARIO ESPECIFICO O SELF'
    END AS ExecutionContext,
    owner_principal.name AS ObjectOwner,
    p.name AS PrincipalName,
    p.type_desc AS PrincipalType,
    grantor.name AS GrantorName,
    dp.permission_name AS PermissionName,
    dp.state_desc AS PermissionState
FROM sys.objects AS o
INNER JOIN sys.schemas AS sc ON o.schema_id = sc.schema_id
INNER JOIN sys.sql_modules AS m ON o.object_id = m.object_id
LEFT JOIN sys.database_principals AS execution_principal
    ON m.execute_as_principal_id = execution_principal.principal_id
LEFT JOIN sys.database_principals AS owner_principal
    ON COALESCE(o.principal_id, sc.principal_id) = owner_principal.principal_id
LEFT JOIN sys.database_permissions AS dp
    ON dp.major_id = o.object_id
   AND dp.class = 1
   AND dp.minor_id = 0
LEFT JOIN sys.database_principals AS p
    ON dp.grantee_principal_id = p.principal_id
LEFT JOIN sys.database_principals AS grantor
    ON dp.grantor_principal_id = grantor.principal_id
WHERE o.object_id = @ObjectId
ORDER BY PrincipalName, PermissionName, PermissionState, GrantorName;
