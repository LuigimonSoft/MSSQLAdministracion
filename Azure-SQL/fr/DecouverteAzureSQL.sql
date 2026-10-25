/*
Découverte de l’environnement Azure SQL

Script de diagnostic en lecture seule pour la base de données actuelle. Identifie la famille du moteur, l’édition et la version, le niveau de compatibilité, READ_COMMITTED_SNAPSHOT (RCSI), les états réel et souhaité de Query Store et les autorisations effectives de diagnostic. Dans Azure SQL Database, affiche également le niveau et l’objectif de service ainsi que l’appartenance à un Elastic Pool.

Exécuter dans la base de données cible plutôt que dans master. Prévu pour Azure SQL Database, Azure SQL Managed Instance et SQL Server 2016 ou ultérieur ; les autres moteurs ne sont pas validés. Query Store nécessite VIEW DATABASE STATE ou, si disponible, VIEW DATABASE PERFORMANCE STATE. Les métadonnées de service nécessitent les autorisations appropriées de propriétaire de la base ou dbManager dans master. Autorisations : 1 = accordée, 0 = non accordée, NULL = non valide ou échec de l’évaluation. Si les métadonnées facultatives sont inaccessibles, le script affiche l’erreur du moteur ; les états NULL de Query Store ne signifient pas OFF.
*/

SET NOCOUNT ON;

DECLARE @EngineEdition int = CONVERT(int, SERVERPROPERTY('EngineEdition'));

-- Vérifier les autorisations effectives avant de lire les métadonnées protégées.
-- NULL peut indiquer une autorisation non valide pour ce moteur ou cette version.
SELECT
    HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'VIEW DATABASE STATE') AS CanViewDatabaseState,
    HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'VIEW DATABASE PERFORMANCE STATE') AS CanViewDatabasePerformanceState;

DECLARE @QueryStoreState nvarchar(60) = NULL,
        @QueryStoreDesiredState nvarchar(60) = NULL;

-- Le SQL dynamique isole la compilation des requêtes facultatives du catalogue.
BEGIN TRY
    EXEC sys.sp_executesql
        N'SELECT @Actual = actual_state_desc, @Desired = desired_state_desc
          FROM sys.database_query_store_options;',
        N'@Actual nvarchar(60) OUTPUT, @Desired nvarchar(60) OUTPUT',
        @Actual = @QueryStoreState OUTPUT,
        @Desired = @QueryStoreDesiredState OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'Impossible de lire les métadonnées de Query Store : ' + ERROR_MESSAGE();
END CATCH;

SELECT
    @@SERVERNAME AS ServerName,
    DB_NAME() AS DatabaseName,
    @EngineEdition AS EngineEdition,
    CASE @EngineEdition
        WHEN 5 THEN N'Azure SQL Database'
        WHEN 8 THEN N'Azure SQL Managed Instance'
        WHEN 2 THEN N'Famille SQL Server Standard'
        WHEN 3 THEN N'Famille SQL Server Enterprise'
        WHEN 4 THEN N'SQL Server Express'
        ELSE N'Autre moteur'
    END AS EngineType,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    d.compatibility_level AS CompatibilityLevel,
    d.is_read_committed_snapshot_on AS RCSIEnabled,
    @QueryStoreState AS QueryStoreState,
    @QueryStoreDesiredState AS QueryStoreDesiredState
FROM sys.databases AS d
WHERE d.database_id = DB_ID();

-- Les objectifs de service et Elastic Pools sont consultés uniquement dans Azure SQL Database.
IF @EngineEdition = 5
BEGIN
    BEGIN TRY
        EXEC sys.sp_executesql N'
            SELECT
                d.name AS DatabaseName,
                slo.edition AS ServiceTier,
                slo.service_objective AS ServiceObjective,
                slo.elastic_pool_name AS ElasticPoolName,
                CASE WHEN slo.elastic_pool_name IS NOT NULL
                    THEN N''Elastic Pool''
                    ELSE N''Base de données individuelle''
                END AS DeploymentType
            FROM sys.database_service_objectives AS slo
            INNER JOIN sys.databases AS d ON d.database_id = slo.database_id
            WHERE d.name = DB_NAME();';
    END TRY
    BEGIN CATCH
        PRINT N'Impossible de lire les métadonnées du service : ' + ERROR_MESSAGE();
    END CATCH;
END;
