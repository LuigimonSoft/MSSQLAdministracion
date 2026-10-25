/*
Stored procedure memory grants, blocking and waits

Read-only snapshot of visible active requests attributable to a SQL stored procedure in the current database through their SQL or plan handles. Reports elapsed time and CPU in milliseconds, logical reads, writes, current wait and resource, blocking session identifier, query memory grants in KB, client host/application and current statement. Memory grants are query execution workspace memory, not the total memory footprint of the procedure.

Replace @Schema and @Procedure. SQL Server 2019 and earlier and Azure SQL Managed Instance require VIEW SERVER STATE to inspect other sessions; SQL Server 2022 and later require VIEW SERVER PERFORMANCE STATE. Azure SQL Database has DMV-specific permissions and visibility restrictions: Microsoft documents sys.dm_exec_requests as limited to the current connection, while memory grants require VIEW DATABASE STATE. Do not assume this query can monitor other connections in Azure SQL Database. OBJECT_ID may return NULL when the SQL procedure does not exist or its metadata is not visible.

This is a point-in-time snapshot, not an atomic history. Requests that finish before capture are absent. Nested calls and dynamic SQL may not be attributable through these handles. NULL grant columns mean no matching visible grant, not zero total memory; MemoryGrantTime can be NULL while waiting. CurrentStatement may be NULL when text or offsets are unavailable (including encrypted text). Request-level waits do not describe all parallel tasks, and row-mode parallel coordinator counters can omit reads/writes. A positive blocking_session_id identifies a blocking session; negative values have special engine meanings, while 0/NULL can mean no blocker or an unidentified blocker.

For intermittent issues use Query Store for historical performance, supported Extended Events for detailed events, or separately authorized periodic sampling. This script does not start a capture, schedule polling, change configuration or terminate sessions.

https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-memory-grants-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sql-text-transact-sql
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
    r.session_id,
    r.request_id,
    r.status,
    r.start_time,
    r.total_elapsed_time AS DurationMs,
    r.cpu_time AS CpuMs,
    r.logical_reads,
    r.writes,
    r.wait_type,
    r.wait_time AS WaitMs,
    r.wait_resource,
    r.blocking_session_id,
    mg.requested_memory_kb,
    mg.granted_memory_kb,
    mg.used_memory_kb,
    mg.max_used_memory_kb,
    mg.wait_time_ms AS MemoryWaitMs,
    mg.grant_time AS MemoryGrantTime,
    s.host_name,
    s.program_name,
    CASE
        WHEN st.text IS NOT NULL
         AND r.statement_start_offset >= 0
         AND (r.statement_end_offset = -1
              OR r.statement_end_offset >= r.statement_start_offset)
        THEN SUBSTRING(
            st.text,
            r.statement_start_offset / 2 + 1,
            ((CASE WHEN r.statement_end_offset = -1
                   THEN DATALENGTH(st.text)
                   ELSE r.statement_end_offset END
              - r.statement_start_offset) / 2) + 1
        )
    END AS CurrentStatement
FROM sys.dm_exec_requests AS r
INNER JOIN sys.dm_exec_sessions AS s ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
OUTER APPLY sys.dm_exec_sql_text(r.plan_handle) AS pt
LEFT JOIN sys.dm_exec_query_memory_grants AS mg
    ON r.session_id = mg.session_id
   AND r.request_id = mg.request_id
WHERE r.database_id = DB_ID()
  AND (
      (st.dbid = DB_ID() AND st.objectid = @ObjectId)
      OR (pt.dbid = DB_ID() AND pt.objectid = @ObjectId)
  )
ORDER BY r.total_elapsed_time DESC, r.session_id, r.request_id;
