/*
Azure SQL environment discovery

Read-only diagnostic script for the current database. Reports the engine family, edition and version, compatibility level, READ_COMMITTED_SNAPSHOT (RCSI), actual and desired Query Store states, and effective diagnostic permissions. In Azure SQL Database, it also reports the service tier, service objective and Elastic Pool membership.

Run in the target database, rather than master. Intended for Azure SQL Database, Azure SQL Managed Instance and SQL Server 2016 or later; other engines are not validated. Query Store requires VIEW DATABASE STATE or, where supported, VIEW DATABASE PERFORMANCE STATE. Service metadata requires appropriate database ownership or master dbManager permissions. Permission results: 1 = granted, 0 = not granted, NULL = invalid or evaluation failed. If optional metadata cannot be read, the script prints the engine error; NULL Query Store states do not mean OFF.
*/

SET NOCOUNT ON;

DECLARE @EngineEdition int = CONVERT(int, SERVERPROPERTY('EngineEdition'));

-- Check effective permissions before reading protected metadata.
-- NULL can indicate an invalid permission on this engine/version.
SELECT
    HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'VIEW DATABASE STATE') AS CanViewDatabaseState,
    HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'VIEW DATABASE PERFORMANCE STATE') AS CanViewDatabasePerformanceState;

DECLARE @QueryStoreState nvarchar(60) = NULL,
        @QueryStoreDesiredState nvarchar(60) = NULL;

-- Dynamic SQL keeps optional catalog queries in a separate compilation scope.
BEGIN TRY
    EXEC sys.sp_executesql
        N'SELECT @Actual = actual_state_desc, @Desired = desired_state_desc
          FROM sys.database_query_store_options;',
        N'@Actual nvarchar(60) OUTPUT, @Desired nvarchar(60) OUTPUT',
        @Actual = @QueryStoreState OUTPUT,
        @Desired = @QueryStoreDesiredState OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'Query Store metadata could not be read: ' + ERROR_MESSAGE();
END CATCH;

SELECT
    @@SERVERNAME AS ServerName,
    DB_NAME() AS DatabaseName,
    @EngineEdition AS EngineEdition,
    CASE @EngineEdition
        WHEN 5 THEN N'Azure SQL Database'
        WHEN 8 THEN N'Azure SQL Managed Instance'
        WHEN 2 THEN N'SQL Server Standard family'
        WHEN 3 THEN N'SQL Server Enterprise family'
        WHEN 4 THEN N'SQL Server Express'
        ELSE N'Other engine'
    END AS EngineType,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    d.compatibility_level AS CompatibilityLevel,
    d.is_read_committed_snapshot_on AS RCSIEnabled,
    @QueryStoreState AS QueryStoreState,
    @QueryStoreDesiredState AS QueryStoreDesiredState
FROM sys.databases AS d
WHERE d.database_id = DB_ID();

-- Service objectives and Elastic Pools apply here only to Azure SQL Database.
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
                    ELSE N''Single Database''
                END AS DeploymentType
            FROM sys.database_service_objectives AS slo
            INNER JOIN sys.databases AS d ON d.database_id = slo.database_id
            WHERE d.name = DB_NAME();';
    END TRY
    BEGIN CATCH
        PRINT N'Service metadata could not be read: ' + ERROR_MESSAGE();
    END CATCH;
END;
