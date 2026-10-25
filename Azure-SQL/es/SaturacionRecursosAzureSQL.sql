/*
Saturación de recursos de Azure SQL

Monitor de recursos de solo lectura seleccionado según el motor. En Azure SQL Database devuelve los 100 intervalos más recientes de la base de datos: utilización promedio de CPU, memoria, E/S de datos y escrituras del log, máximos de workers y sesiones y un estado orientativo. En Azure SQL Managed Instance indica que debe utilizarse sys.server_resource_stats en lugar de consultar una DMV de base de datos no compatible. En otros motores devuelve un mensaje informativo.

Ejecutar en la base de datos Azure SQL de destino con VIEW DATABASE STATE. sys.dm_db_resource_stats registra intervalos de 15 segundos y conserva aproximadamente una hora; TOP (100) cubre unos 25 minutos si están disponibles todos los intervalos. CaptureTimeUTC es el final del intervalo, no la hora de ejecución del script. Una conmutación por error puede reducir el histórico disponible. Los porcentajes son relativos a los límites de servicio aplicables; en una base de datos de Elastic Pool se refieren al límite configurado para esa base, no al consumo global del pool.

CRITICO indica que CPU, E/S de datos, escrituras del log o máximo de workers alcanzaron al menos el 90 %; ADVERTENCIA indica que alguno alcanzó al menos el 75 %; NORMAL indica que ninguna de esas métricas alcanzó el 75 %. Son umbrales ilustrativos, no una prueba de saturación ni un diagnóstico de salud de Azure. Memoria y sesiones se muestran, pero no afectan a ResourceStatus. Una memoria alta por sí sola puede reflejar el uso de caché. Correlacionar la presión sostenida con ejecuciones del procedimiento, Query Store y latencia observada antes de atribuirle responsabilidad.

La rama de Managed Instance solo recomienda el monitor de instancia; no lo consulta. sys.server_resource_stats proporciona filas de intervalos de 15 segundos, actualizadas con demora, y aproximadamente 14 días de histórico. Este script no configura alertas, programa monitorización ni cambia recursos. Los nombres de columnas de salida se mantienen en inglés en todas las versiones.

https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-resource-stats-azure-sql-database
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-resource-stats-azure-sql-database
*/

SET NOCOUNT ON;

DECLARE @EngineEdition int = CONVERT(int, SERVERPROPERTY('EngineEdition'));

IF @EngineEdition = 5
BEGIN
    -- Compilar la consulta de la DMV específica solo en Azure SQL Database.
    EXEC sys.sp_executesql N'SELECT TOP (100)
    DB_NAME() AS DatabaseName,
    end_time AS CaptureTimeUTC,
    avg_cpu_percent AS CpuPct,
    avg_memory_usage_percent AS MemoryPct,
    avg_data_io_percent AS DataIOPct,
    avg_log_write_percent AS LogWritePct,
    max_worker_percent AS WorkersPct,
    max_session_percent AS SessionsPct,
    CASE
        WHEN avg_cpu_percent >= 90
          OR avg_data_io_percent >= 90
          OR avg_log_write_percent >= 90
          OR max_worker_percent >= 90
            THEN N''CRITICO''
        WHEN avg_cpu_percent >= 75
          OR avg_data_io_percent >= 75
          OR avg_log_write_percent >= 75
          OR max_worker_percent >= 75
            THEN N''ADVERTENCIA''
        ELSE N''NORMAL''
    END AS ResourceStatus
FROM sys.dm_db_resource_stats
ORDER BY end_time DESC;';
END
ELSE IF @EngineEdition = 8
BEGIN
    SELECT
        N'Azure SQL Managed Instance' AS EngineType,
        N'Utilizar sys.server_resource_stats' AS ResourceMonitor,
        N'Revisar métricas a nivel de instancia' AS Notes;
END
ELSE
BEGIN
    SELECT @EngineEdition AS EngineEdition,
        N'Motor distinto de Azure SQL Database o Managed Instance' AS Notes;
END;
