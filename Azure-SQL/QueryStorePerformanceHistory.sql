/*
Performance history with Query Store

Read-only query for tracking the performance of statements within a SQL stored procedure by Query Store interval, query and plan. Reports successful execution counts, execution-weighted average duration and CPU in milliseconds, average logical reads in 8 KB pages, and maximum duration in milliseconds. These are statement-level metrics, not the cost or invocation count of the complete procedure.

Run in the target database and replace @Schema, @Procedure and @HoursBack (a positive number of hours; default 24). The time window uses one fixed UTC reference. Includes whole intervals overlapping the window, so boundary intervals may contain executions outside the requested period. The current interval is incomplete and can change as executions finish. Multiple runtime-statistics rows for the same plan and interval are aggregated using execution-weighted averages.

Query Store must have captured and retained runtime history for the procedure. READ_ONLY can expose existing history; READ_WRITE is needed to collect new data. Missing rows can reflect capture policy, retention, no recorded executions or unavailable history, rather than zero usage. Only regular, successfully completed executions are included (execution_type = 0); aborted and failed executions are excluded. Compare equivalent periods and workloads to investigate regressions.

Applies to Azure SQL Database, Azure SQL Managed Instance and SQL Server 2016 or later. Requires VIEW DATABASE STATE or, where supported, VIEW DATABASE PERFORMANCE STATE (SQL Server 2022 and later). OBJECT_ID can return NULL for a missing SQL procedure or insufficient metadata visibility. No database configuration is changed.

https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-interval-transact-sql
*/

SET NOCOUNT ON;

-- Set the target SQL procedure and the lookback period in hours.
DECLARE @Schema sysname = N'dbo';
DECLARE @Procedure sysname = N'YourStoredProcedure';
DECLARE @HoursBack int = 24;

IF @HoursBack IS NULL OR @HoursBack <= 0
BEGIN
    THROW 50002, N'HoursBack must be greater than zero.', 1;
END;

DECLARE @WindowEnd datetimeoffset(7) = TODATETIMEOFFSET(SYSUTCDATETIME(), '+00:00');
DECLARE @WindowStart datetimeoffset(7) = DATEADD(HOUR, -@HoursBack, @WindowEnd);

DECLARE @ObjectId int = OBJECT_ID(
    QUOTENAME(@Schema) + N'.' + QUOTENAME(@Procedure), N'P'
);

IF @ObjectId IS NULL
BEGIN
    THROW 50001, N'SQL stored procedure not found or not visible to the current user.', 1;
END;

SELECT
    OBJECT_SCHEMA_NAME(q.object_id) AS SchemaName,
    OBJECT_NAME(q.object_id) AS ProcedureName,
    q.query_id AS QueryId,
    p.plan_id AS PlanId,
    i.start_time AS IntervalStart,
    i.end_time AS IntervalEnd,
    SUM(rs.count_executions) AS Executions,
    CAST(SUM(rs.avg_duration * rs.count_executions) /
        NULLIF(SUM(rs.count_executions), 0) / 1000.0
        AS decimal(19,2)) AS AvgDurationMs,
    CAST(SUM(rs.avg_cpu_time * rs.count_executions) /
        NULLIF(SUM(rs.count_executions), 0) / 1000.0
        AS decimal(19,2)) AS AvgCpuMs,
    CAST(SUM(rs.avg_logical_io_reads * rs.count_executions) /
        NULLIF(SUM(rs.count_executions), 0)
        AS decimal(19,2)) AS AvgLogicalReads,
    CAST(MAX(rs.max_duration) / 1000.0
        AS decimal(19,2)) AS MaxDurationMs
FROM sys.query_store_query AS q
INNER JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
INNER JOIN sys.query_store_runtime_stats_interval AS i
    ON rs.runtime_stats_interval_id = i.runtime_stats_interval_id
WHERE q.object_id = @ObjectId
  -- Include whole Query Store intervals overlapping the requested UTC window.
  AND i.end_time > @WindowStart
  AND i.start_time < @WindowEnd
  AND rs.execution_type = 0
GROUP BY
    q.object_id,
    q.query_id,
    p.plan_id,
    i.start_time,
    i.end_time
ORDER BY
    i.start_time DESC,
    AvgDurationMs DESC,
    q.query_id,
    p.plan_id;
