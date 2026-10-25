/*
Stored procedure explicit permission audit

Read-only audit of visible, explicit object-level permissions on a SQL stored procedure and its declared execution context. Reports schema and procedure, EXECUTE AS principal identifier and resolved name, current object owner, grantee and principal type, grantor, permission and state. The grantee may be a user, role or another database principal; membership is not expanded.

Run in the target database and replace @Schema and @Procedure. CALLER leaves ExecuteAsPrincipal NULL because the caller depends on the invocation. OWNER resolves the current object owner, falling back to the schema owner when no explicit object owner is set. A stored principal identifier can represent EXECUTE AS SELF or an explicitly named user; the identifier alone does not distinguish the original declaration. Output column names and catalog-provided permission/type descriptions remain in English.

Catalog metadata visibility applies: results may be incomplete unless the auditing account can see the object, module, permissions and relevant database principals. Use an appropriately authorized account with sufficient metadata visibility (such as a database owner) for a comprehensive object-level review. OBJECT_ID may return NULL for a missing or invisible SQL procedure. A row with NULL permission columns means no explicit permission row is visible, not that no one can execute the procedure. A NULL resolved principal name can indicate unavailable metadata.

This query does not calculate effective permissions from role membership (including fixed roles), ownership, schema/database/server permissions, ownership chaining, module signatures or other execution contexts. It neither proves nor rules out SQL injection: that requires analysis of code and input handling. The script does not grant, deny or revoke permissions or impersonate users. Applies to Azure SQL Database, Azure SQL Managed Instance and SQL Server 2016 or later.

https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql
https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql
*/

SET NOCOUNT ON;

-- Set the SQL procedure in the current database.
DECLARE @Schema sysname = N'dbo';
DECLARE @Procedure sysname = N'YourStoredProcedure';

DECLARE @ObjectId int = OBJECT_ID(
    QUOTENAME(@Schema) + N'.' + QUOTENAME(@Procedure), N'P'
);

IF @ObjectId IS NULL
BEGIN
    THROW 50001, N'SQL stored procedure not found or not visible to the current user.', 1;
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
        WHEN m.execute_as_principal_id = -2 THEN N'OWNER'
        WHEN m.execute_as_principal_id IS NULL THEN N'CALLER'
        ELSE N'SPECIFIC USER OR SELF'
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
