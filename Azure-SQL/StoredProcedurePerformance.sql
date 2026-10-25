/*
Stored procedure cached performance

Read-only diagnostic query that reports execution counts, total/average/last elapsed time and CPU time in milliseconds, and total/average logical reads and writes for a SQL stored procedure in the current database. Returns one row per cached plan, ordered by total elapsed time; it does not combine multiple plans into a single procedure total.

High average duration together with high CPU and logical reads can highlight optimization opportunities. Compare measurements from equivalent periods and use counter deltas only while the same plan remains cached. Counters cover completed executions since compilation and can reset after recompilation, eviction or restart. An empty result does not mean zero usage: the procedure may have no cached plan. These are cumulative cache statistics, not a historical time series. Logical reads/writes are page counters, not bytes or physical disk I/O.

Run in the target database and replace @Schema and @Procedure. The P object type selects SQL stored procedures, excluding CLR procedures. OBJECT_ID can return NULL for a missing object or insufficient metadata visibility. Natively compiled procedures have metric limitations; see Microsoft documentation.

Permissions: Azure SQL Database Basic/S0/S1 and elastic pools require the server admin, Microsoft Entra admin or ##MS_ServerStateReader## role. Other service objectives require VIEW DATABASE STATE or that role. SQL Server 2019 and earlier and Azure SQL Managed Instance require VIEW SERVER STATE; SQL Server 2022 and later require VIEW SERVER PERFORMANCE STATE.

https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-procedure-stats-transact-sql
*/

SET NOCOUNT ON;

-- Set the schema and procedure name in the current database.
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
    OBJECT_SCHEMA_NAME(object_id, database_id) AS SchemaName,
    OBJECT_NAME(object_id, database_id) AS ProcedureName,
    cached_time AS CachedTime,
    last_execution_time AS LastExecutionTime,
    execution_count AS ExecutionCount,
    CAST(total_elapsed_time / 1000.0 AS decimal(19,2)) AS TotalDurationMs,
    CAST(total_elapsed_time / 1000.0 /
        NULLIF(execution_count, 0) AS decimal(19,2)) AS AvgDurationMs,
    CAST(last_elapsed_time / 1000.0 AS decimal(19,2)) AS LastDurationMs,
    CAST(total_worker_time / 1000.0 AS decimal(19,2)) AS TotalCpuMs,
    CAST(total_worker_time / 1000.0 /
        NULLIF(execution_count, 0) AS decimal(19,2)) AS AvgCpuMs,
    CAST(last_worker_time / 1000.0 AS decimal(19,2)) AS LastCpuMs,
    total_logical_reads AS TotalLogicalReads,
    CAST(CAST(total_logical_reads AS decimal(38,4)) /
        NULLIF(execution_count, 0) AS decimal(19,2)) AS AvgLogicalReads,
    total_logical_writes AS TotalLogicalWrites,
    CAST(CAST(total_logical_writes AS decimal(38,4)) /
        NULLIF(execution_count, 0) AS decimal(19,2)) AS AvgLogicalWrites,
    plan_handle AS PlanHandle
FROM sys.dm_exec_procedure_stats
WHERE database_id = DB_ID()
  AND object_id = @ObjectId
ORDER BY total_elapsed_time DESC;
