/*
Audit des autorisations explicites de la procédure

Audit en lecture seule des autorisations explicites visibles au niveau objet d’une procédure SQL et de son contexte d’exécution déclaré. Affiche le schéma et la procédure, l’identifiant et le nom résolu du principal EXECUTE AS, le propriétaire actuel de l’objet, le bénéficiaire et son type, le principal ayant accordé l’autorisation, l’autorisation et son état. Le bénéficiaire peut être un utilisateur, un rôle ou un autre principal de base ; les appartenances ne sont pas développées.

Exécuter dans la base cible et remplacer @Schema et @Procedure. APPELANT laisse ExecuteAsPrincipal à NULL car l’appelant dépend de chaque invocation. PROPRIETAIRE résout le propriétaire actuel de l’objet, ou celui du schéma en l’absence de propriétaire explicite. Un identifiant stocké peut correspondre à EXECUTE AS SELF ou à un utilisateur nommé explicitement ; il ne suffit pas à distinguer la déclaration d’origine. Les noms de colonnes et les descriptions des autorisations et types fournies par le catalogue restent en anglais.

La visibilité des métadonnées s’applique : les résultats peuvent être incomplets si le compte d’audit ne peut pas voir l’objet, le module, les autorisations et les principaux concernés. Utiliser un compte autorisé disposant d’une visibilité suffisante, par exemple le propriétaire de la base, pour un examen complet au niveau objet. OBJECT_ID peut renvoyer NULL si la procédure SQL est absente ou invisible. Une ligne avec des colonnes d’autorisation NULL signifie qu’aucune autorisation explicite n’est visible, pas que personne ne peut exécuter la procédure. Un nom de principal résolu NULL peut indiquer des métadonnées indisponibles.

Ne calcule pas les autorisations effectives issues des appartenances aux rôles, y compris les rôles fixes, de la propriété, des autorisations de schéma, base ou serveur, des chaînes de propriété, des signatures de modules ou d’autres contextes d’exécution. Ne prouve ni n’exclut une injection SQL : cela nécessite l’analyse du code et du traitement des entrées. N’accorde, ne refuse ni ne révoque aucune autorisation et n’usurpe aucun utilisateur. Applicable à Azure SQL Database, Azure SQL Managed Instance et SQL Server 2016 ou ultérieur.

https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql
https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql
*/

SET NOCOUNT ON;

-- Indiquer la procédure SQL de la base de données actuelle.
DECLARE @Schema sysname = N'dbo';
DECLARE @Procedure sysname = N'VotreProcedureStockee';

DECLARE @ObjectId int = OBJECT_ID(
    QUOTENAME(@Schema) + N'.' + QUOTENAME(@Procedure), N'P'
);

IF @ObjectId IS NULL
BEGIN
    THROW 50001, N'Procédure stockée SQL introuvable ou non visible pour cet utilisateur.', 1;
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
        WHEN m.execute_as_principal_id = -2 THEN N'PROPRIETAIRE'
        WHEN m.execute_as_principal_id IS NULL THEN N'APPELANT'
        ELSE N'UTILISATEUR SPECIFIQUE OU SELF'
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
