/*
Azure SQL resource saturation

Read-only resource monitor selected by engine type. In Azure SQL Database, returns the 100 most recent database resource intervals: average CPU, memory, data I/O and log write utilization, peak workers and sessions, and a heuristic status. In Azure SQL Managed Instance, returns guidance to use sys.server_resource_stats instead of querying an unsupported database DMV. Other engines receive an informational message.

Run in the target Azure SQL database with VIEW DATABASE STATE. sys.dm_db_resource_stats records 15-second intervals and retains approximately one hour; TOP (100) covers about 25 minutes when all intervals are available. CaptureTimeUTC is the interval end, not the script execution time. Failover can shorten the available history. Percentages are relative to applicable service limits; for an elastic-pool database they refer to its configured database limit, not overall pool utilization.

CRITICAL means CPU, data I/O, log writes or peak workers reached at least 90%; WARNING means one reached at least 75%; NORMAL means none of those metrics reached 75%. These are illustrative thresholds, not proof of saturation or an Azure health verdict. Memory and sessions are displayed but do not affect ResourceStatus. High memory use alone can reflect buffer caching. Correlate sustained resource pressure with stored procedure executions, Query Store and observed latency before attributing responsibility.

The Managed Instance branch only recommends the instance monitor; it does not query it. sys.server_resource_stats provides 15-second reporting rows, updated with a delay, and approximately 14 days of history. This script does not configure alerts, schedule monitoring or change resources. Output column names remain in English in all language versions.

https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-resource-stats-azure-sql-database
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-resource-stats-azure-sql-database
*/

SET NOCOUNT ON;

DECLARE @EngineEdition int = CONVERT(int, SERVERPROPERTY('EngineEdition'));

IF @EngineEdition = 5
BEGIN
    -- Compile the database-specific DMV query only on Azure SQL Database.
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
            THEN N''CRITICAL''
        WHEN avg_cpu_percent >= 75
          OR avg_data_io_percent >= 75
          OR avg_log_write_percent >= 75
          OR max_worker_percent >= 75
            THEN N''WARNING''
        ELSE N''NORMAL''
    END AS ResourceStatus
FROM sys.dm_db_resource_stats
ORDER BY end_time DESC;';
END
ELSE IF @EngineEdition = 8
BEGIN
    SELECT
        N'Azure SQL Managed Instance' AS EngineType,
        N'Use sys.server_resource_stats' AS ResourceMonitor,
        N'Review instance-level metrics' AS Notes;
END
ELSE
BEGIN
    SELECT @EngineEdition AS EngineEdition,
        N'Engine is not Azure SQL Database or Managed Instance' AS Notes;
END;
