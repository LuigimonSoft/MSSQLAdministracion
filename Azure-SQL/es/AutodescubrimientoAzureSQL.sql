/*
Autodescubrimiento del entorno Azure SQL

Script de diagnóstico de solo lectura para la base de datos actual. Identifica la familia del motor, la edición y la versión, el nivel de compatibilidad, READ_COMMITTED_SNAPSHOT (RCSI), los estados real y deseado de Query Store y los permisos efectivos de diagnóstico. En Azure SQL Database, también muestra el nivel y el objetivo de servicio y la pertenencia a un Elastic Pool.

Ejecutar en la base de datos de destino, en lugar de master. Previsto para Azure SQL Database, Azure SQL Managed Instance y SQL Server 2016 o posterior; otros motores no están validados. Query Store requiere VIEW DATABASE STATE o, cuando se admita, VIEW DATABASE PERFORMANCE STATE. Los metadatos de servicio requieren permisos adecuados de propietario de la base de datos o dbManager en master. Permisos: 1 = concedido, 0 = no concedido, NULL = no válido o evaluación fallida. Si no se pueden leer metadatos opcionales, se imprime el error del motor; los estados NULL de Query Store no significan OFF.
*/

SET NOCOUNT ON;

DECLARE @EngineEdition int = CONVERT(int, SERVERPROPERTY('EngineEdition'));

-- Comprobar los permisos efectivos antes de leer metadatos protegidos.
-- NULL puede indicar un permiso no válido en este motor o versión.
SELECT
    HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'VIEW DATABASE STATE') AS CanViewDatabaseState,
    HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'VIEW DATABASE PERFORMANCE STATE') AS CanViewDatabasePerformanceState;

DECLARE @QueryStoreState nvarchar(60) = NULL,
        @QueryStoreDesiredState nvarchar(60) = NULL;

-- SQL dinámico mantiene las consultas opcionales en un ámbito de compilación separado.
BEGIN TRY
    EXEC sys.sp_executesql
        N'SELECT @Actual = actual_state_desc, @Desired = desired_state_desc
          FROM sys.database_query_store_options;',
        N'@Actual nvarchar(60) OUTPUT, @Desired nvarchar(60) OUTPUT',
        @Actual = @QueryStoreState OUTPUT,
        @Desired = @QueryStoreDesiredState OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'No se pudieron leer los metadatos de Query Store: ' + ERROR_MESSAGE();
END CATCH;

SELECT
    @@SERVERNAME AS ServerName,
    DB_NAME() AS DatabaseName,
    @EngineEdition AS EngineEdition,
    CASE @EngineEdition
        WHEN 5 THEN N'Azure SQL Database'
        WHEN 8 THEN N'Azure SQL Managed Instance'
        WHEN 2 THEN N'Familia SQL Server Standard'
        WHEN 3 THEN N'Familia SQL Server Enterprise'
        WHEN 4 THEN N'SQL Server Express'
        ELSE N'Otro motor'
    END AS EngineType,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    d.compatibility_level AS CompatibilityLevel,
    d.is_read_committed_snapshot_on AS RCSIEnabled,
    @QueryStoreState AS QueryStoreState,
    @QueryStoreDesiredState AS QueryStoreDesiredState
FROM sys.databases AS d
WHERE d.database_id = DB_ID();

-- Los objetivos de servicio y Elastic Pools se consultan solo en Azure SQL Database.
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
                    ELSE N''Base de datos individual''
                END AS DeploymentType
            FROM sys.database_service_objectives AS slo
            INNER JOIN sys.databases AS d ON d.database_id = slo.database_id
            WHERE d.name = DB_NAME();';
    END TRY
    BEGIN CATCH
        PRINT N'No se pudieron leer los metadatos del servicio: ' + ERROR_MESSAGE();
    END CATCH;
END;
