# MSSQLAdministracion

[Español](README.es.md) · [Français](README.fr.md)
Repository of queries to help administer and troubleshoot MS SQL databases.

These queries help improve database performance and support database administration.

## Table of contents

- [MSSQL](#mssql)
  - [QueryExecutionTimes.sql](#query-1)
  - [BlockedQueries.sql](#query-2)
  - [Pagination.sql](#query-3)
  - [ShrinkLog.sql](#query-4)
  - [TimeZoneDateTime.sql](#query-5)
- [Azure SQL](#azure-sql)
  - [Azure SQL environment discovery](#query-6)
  - [Stored procedure cached performance](#query-7)
  - [Performance history with Query Store](#query-8)
  - [Stored procedure memory grants, blocking and waits](#query-9)
  - [Index and statistics maintenance review](#query-10)
  - [Azure SQL resource saturation](#query-11)
  - [Stored procedure explicit permission audit](#query-12)
- [DBA agent](#dba-agent)
- [Sources](#sources)

## MSSQL

<a id="query-1"></a>

- [QueryExecutionTimes.sql](QueryExecutionTimes.sql)<br>
  Shows the queries that take the longest to execute, along with their reads, CPU usage, and execution plans, to help optimize them.

<a id="query-2"></a>

- [BlockedQueries.sql](BlockedQueries.sql)<br>
  Shows waiting user sessions and identifies the sessions blocking them.

<a id="query-3"></a>

- [Pagination.sql](Pagination.sql)<br>
  A query for paginating table results.

<a id="query-4"></a>

- [ShrinkLog.sql](ShrinkLog.sql)<br>
  Helps shrink the database log file (remember to create a backup first).

<a id="query-5"></a>

- [TimeZoneDateTime.sql](TimeZoneDateTime.sql)<br>
  Returns the exact time in a time zone anywhere in the world; this example uses central Mexico's time zone.

## Azure SQL

<a id="query-6"></a>

- [Azure SQL environment discovery](Azure-SQL/AzureSQLDiscovery.sql)<br>
  Read-only diagnostic script for the current database. Reports the engine family, edition and version, compatibility level, READ_COMMITTED_SNAPSHOT (RCSI), actual and desired Query Store states, and effective diagnostic permissions. In Azure SQL Database, it also reports the service tier, service objective and Elastic Pool membership.

Run in the target database, rather than master. Intended for Azure SQL Database, Azure SQL Managed Instance and SQL Server 2016 or later; other engines are not validated. Query Store requires VIEW DATABASE STATE or, where supported, VIEW DATABASE PERFORMANCE STATE. Service metadata requires appropriate database ownership or master dbManager permissions. Permission results: 1 = granted, 0 = not granted, NULL = invalid or evaluation failed. If optional metadata cannot be read, the script prints the engine error; NULL Query Store states do not mean OFF.

Microsoft documentation: [SERVERPROPERTY](https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql), [sys.database_query_store_options](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-query-store-options-transact-sql), [sys.database_service_objectives](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-service-objectives-azure-sql-database), [HAS_PERMS_BY_NAME](https://learn.microsoft.com/en-us/sql/t-sql/functions/has-perms-by-name-transact-sql).

<a id="query-7"></a>

- [Stored procedure cached performance](Azure-SQL/StoredProcedurePerformance.sql)<br>
  Read-only diagnostic query that reports execution counts, total/average/last elapsed time and CPU time in milliseconds, and total/average logical reads and writes for a SQL stored procedure in the current database. Returns one row per cached plan, ordered by total elapsed time; it does not combine multiple plans into a single procedure total.

High average duration together with high CPU and logical reads can highlight optimization opportunities. Compare measurements from equivalent periods and use counter deltas only while the same plan remains cached. Counters cover completed executions since compilation and can reset after recompilation, eviction or restart. An empty result does not mean zero usage: the procedure may have no cached plan. These are cumulative cache statistics, not a historical time series. Logical reads/writes are page counters, not bytes or physical disk I/O.

Run in the target database and replace @Schema and @Procedure. The P object type selects SQL stored procedures, excluding CLR procedures. OBJECT_ID can return NULL for a missing object or insufficient metadata visibility. Natively compiled procedures have metric limitations; see Microsoft documentation.

Permissions: Azure SQL Database Basic/S0/S1 and elastic pools require the server admin, Microsoft Entra admin or ##MS_ServerStateReader## role. Other service objectives require VIEW DATABASE STATE or that role. SQL Server 2019 and earlier and Azure SQL Managed Instance require VIEW SERVER STATE; SQL Server 2022 and later require VIEW SERVER PERFORMANCE STATE.

[sys.dm_exec_procedure_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-procedure-stats-transact-sql).

<a id="query-8"></a>

- [Performance history with Query Store](Azure-SQL/QueryStorePerformanceHistory.sql)<br>
  Read-only query for tracking the performance of statements within a SQL stored procedure by Query Store interval, query and plan. Reports successful execution counts, execution-weighted average duration and CPU in milliseconds, average logical reads in 8 KB pages, and maximum duration in milliseconds. These are statement-level metrics, not the cost or invocation count of the complete procedure.

Run in the target database and replace @Schema, @Procedure and @HoursBack (a positive number of hours; default 24). The time window uses one fixed UTC reference. Includes whole intervals overlapping the window, so boundary intervals may contain executions outside the requested period. The current interval is incomplete and can change as executions finish. Multiple runtime-statistics rows for the same plan and interval are aggregated using execution-weighted averages.

Query Store must have captured and retained runtime history for the procedure. READ_ONLY can expose existing history; READ_WRITE is needed to collect new data. Missing rows can reflect capture policy, retention, no recorded executions or unavailable history, rather than zero usage. Only regular, successfully completed executions are included (execution_type = 0); aborted and failed executions are excluded. Compare equivalent periods and workloads to investigate regressions.

Applies to Azure SQL Database, Azure SQL Managed Instance and SQL Server 2016 or later. Requires VIEW DATABASE STATE or, where supported, VIEW DATABASE PERFORMANCE STATE (SQL Server 2022 and later). OBJECT_ID can return NULL for a missing SQL procedure or insufficient metadata visibility. No database configuration is changed.

[sys.query_store_runtime_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql), [sys.query_store_runtime_stats_interval](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-interval-transact-sql).

<a id="query-9"></a>

- [Stored procedure memory grants, blocking and waits](Azure-SQL/StoredProcedureActiveMonitor.sql)<br>
  Read-only snapshot of visible active requests attributable to a SQL stored procedure in the current database through their SQL or plan handles. Reports elapsed time and CPU in milliseconds, logical reads, writes, current wait and resource, blocking session identifier, query memory grants in KB, client host/application and current statement. Memory grants are query execution workspace memory, not the total memory footprint of the procedure.

Replace @Schema and @Procedure. SQL Server 2019 and earlier and Azure SQL Managed Instance require VIEW SERVER STATE to inspect other sessions; SQL Server 2022 and later require VIEW SERVER PERFORMANCE STATE. Azure SQL Database has DMV-specific permissions and visibility restrictions: Microsoft documents sys.dm_exec_requests as limited to the current connection, while memory grants require VIEW DATABASE STATE. Do not assume this query can monitor other connections in Azure SQL Database. OBJECT_ID may return NULL when the SQL procedure does not exist or its metadata is not visible.

This is a point-in-time snapshot, not an atomic history. Requests that finish before capture are absent. Nested calls and dynamic SQL may not be attributable through these handles. NULL grant columns mean no matching visible grant, not zero total memory; MemoryGrantTime can be NULL while waiting. CurrentStatement may be NULL when text or offsets are unavailable (including encrypted text). Request-level waits do not describe all parallel tasks, and row-mode parallel coordinator counters can omit reads/writes. A positive blocking_session_id identifies a blocking session; negative values have special engine meanings, while 0/NULL can mean no blocker or an unidentified blocker.

For intermittent issues use Query Store for historical performance, supported Extended Events for detailed events, or separately authorized periodic sampling. This script does not start a capture, schedule polling, change configuration or terminate sessions.

[sys.dm_exec_requests](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql), [sys.dm_exec_query_memory_grants](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-memory-grants-transact-sql), [sys.dm_exec_sql_text](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sql-text-transact-sql).

<a id="query-10"></a>

- [Index and statistics maintenance review](Azure-SQL/RelatedIndexStatisticsReview.sql)<br>
  Read-only assessment of statistics on tables directly referenced by a SQL stored procedure through recorded static dependencies in the current database. Reports associated indexes, filtered-statistics definitions, last update, rows at update, sampled rows, modification counters and a review percentage. Includes standalone column statistics and avoids physical index scans. It does not measure fragmentation or perform index or statistics maintenance.

Replace @Schema and @Procedure in the target database. Dependencies require VIEW DEFINITION on the database and SELECT on sys.sql_expression_dependencies. Statistics properties require SELECT on the statistics columns, ownership of the table or an applicable documented administrative role. Metadata visibility can restrict results; OBJECT_ID can return NULL for an absent or invisible SQL procedure. Missing property rows are distinguished from missing update dates; a NULL update date can occur for empty tables or filtered statistics with no qualifying rows.

The review flag uses more than 1,000 rows at the last update and more than 20% modifications. This is a heuristic, not the automatic statistics update threshold or an instruction to update statistics. Correlate it with estimation errors, plan changes and observed performance degradation. ModificationPct uses rows at the last statistics update, not current table size; it can exceed 100% and is NULL when the denominator is zero or unavailable. Normally the counter tracks changes to the leading histogram column; for memory-optimized tables it tracks table changes since the last update or database restart. Filtered statistics cover only their qualifying rows.

Only direct, resolved local table dependencies are included. Dynamic SQL, dependencies through views, synonyms, functions or nested procedures, and cross-database references are not traversed. No rows does not establish that no tables are used or no maintenance is needed. These are table statistics, not proof that the procedure uses each statistic or associated index. Incremental statistics are shown at the global level, not by partition. Applies to Azure SQL Database, Azure SQL Managed Instance and SQL Server 2016 or later.

[sys.sql_expression_dependencies](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-expression-dependencies-transact-sql), [sys.stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-stats-transact-sql), [sys.dm_db_stats_properties](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-stats-properties-transact-sql).

<a id="query-11"></a>

- [Azure SQL resource saturation](Azure-SQL/AzureSQLResourceSaturation.sql)<br>
  Read-only resource monitor selected by engine type. In Azure SQL Database, returns the 100 most recent database resource intervals: average CPU, memory, data I/O and log write utilization, peak workers and sessions, and a heuristic status. In Azure SQL Managed Instance, returns guidance to use sys.server_resource_stats instead of querying an unsupported database DMV. Other engines receive an informational message.

Run in the target Azure SQL database with VIEW DATABASE STATE. sys.dm_db_resource_stats records 15-second intervals and retains approximately one hour; TOP (100) covers about 25 minutes when all intervals are available. CaptureTimeUTC is the interval end, not the script execution time. Failover can shorten the available history. Percentages are relative to applicable service limits; for an elastic-pool database they refer to its configured database limit, not overall pool utilization.

CRITICAL means CPU, data I/O, log writes or peak workers reached at least 90%; WARNING means one reached at least 75%; NORMAL means none of those metrics reached 75%. These are illustrative thresholds, not proof of saturation or an Azure health verdict. Memory and sessions are displayed but do not affect ResourceStatus. High memory use alone can reflect buffer caching. Correlate sustained resource pressure with stored procedure executions, Query Store and observed latency before attributing responsibility.

The Managed Instance branch only recommends the instance monitor; it does not query it. sys.server_resource_stats provides 15-second reporting rows, updated with a delay, and approximately 14 days of history. This script does not configure alerts, schedule monitoring or change resources. Output column names remain in English in all language versions.

[sys.dm_db_resource_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-resource-stats-azure-sql-database), [sys.server_resource_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-resource-stats-azure-sql-database).

<a id="query-12"></a>

- [Stored procedure explicit permission audit](Azure-SQL/StoredProcedurePermissionAudit.sql)<br>
  Read-only audit of visible, explicit object-level permissions on a SQL stored procedure and its declared execution context. Reports schema and procedure, EXECUTE AS principal identifier and resolved name, current object owner, grantee and principal type, grantor, permission and state. The grantee may be a user, role or another database principal; membership is not expanded.

Run in the target database and replace @Schema and @Procedure. CALLER leaves ExecuteAsPrincipal NULL because the caller depends on the invocation. OWNER resolves the current object owner, falling back to the schema owner when no explicit object owner is set. A stored principal identifier can represent EXECUTE AS SELF or an explicitly named user; the identifier alone does not distinguish the original declaration. Output column names and catalog-provided permission/type descriptions remain in English.

Catalog metadata visibility applies: results may be incomplete unless the auditing account can see the object, module, permissions and relevant database principals. Use an appropriately authorized account with sufficient metadata visibility (such as a database owner) for a comprehensive object-level review. OBJECT_ID may return NULL for a missing or invisible SQL procedure. A row with NULL permission columns means no explicit permission row is visible, not that no one can execute the procedure. A NULL resolved principal name can indicate unavailable metadata.

This query does not calculate effective permissions from role membership (including fixed roles), ownership, schema/database/server permissions, ownership chaining, module signatures or other execution contexts. It neither proves nor rules out SQL injection: that requires analysis of code and input handling. The script does not grant, deny or revoke permissions or impersonate users. Applies to Azure SQL Database, Azure SQL Managed Instance and SQL Server 2016 or later.

[sys.sql_modules](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql), [sys.database_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql), [EXECUTE AS](https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql).

## DBA agent

[DBA agent system prompt](Azure-SQL/Agents/StoredProcedureDBAAgent.md)

System prompt in English for creating Azure SQL Stored Procedure Deep Analyzer, an expert agent for stored procedure diagnosis, optimization, security, maintenance and monitoring. Copy the complete file into the agent’s system instructions. The agent has no direct database connection: a human DBA executes the diagnostic queries and shares the results.

Available languages: [English](Azure-SQL/Agents/StoredProcedureDBAAgent.md) · [Español](Azure-SQL/Agents/es/AgenteDBAStoredProcedure.md) · [Français](Azure-SQL/Agents/fr/AgentDBAProcedureStockee.md)

[Platform-specific profiles for GitHub Copilot, Codex and Claude Code, with installation instructions in three languages](Azure-SQL/Agents/Integrations/README.md).

## Sources

Official Microsoft Learn documentation used to review the queries, metrics, permissions and limitations.

- [SERVERPROPERTY](https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql)
- [sys.database_query_store_options](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-query-store-options-transact-sql)
- [sys.database_service_objectives](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-service-objectives-azure-sql-database)
- [HAS_PERMS_BY_NAME](https://learn.microsoft.com/en-us/sql/t-sql/functions/has-perms-by-name-transact-sql)
- [sys.dm_exec_procedure_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-procedure-stats-transact-sql)
- [sys.query_store_runtime_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql)
- [sys.query_store_runtime_stats_interval](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-interval-transact-sql)
- [sys.dm_exec_requests](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql)
- [sys.dm_exec_query_memory_grants](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-memory-grants-transact-sql)
- [sys.dm_exec_sql_text](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sql-text-transact-sql)
- [sys.sql_expression_dependencies](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-expression-dependencies-transact-sql)
- [sys.stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-stats-transact-sql)
- [sys.dm_db_stats_properties](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-stats-properties-transact-sql)
- [sys.dm_db_resource_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-resource-stats-azure-sql-database)
- [sys.server_resource_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-resource-stats-azure-sql-database)
- [sys.sql_modules](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql)
- [sys.database_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql)
- [EXECUTE AS](https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql)
- [GitHub Copilot custom agents](https://docs.github.com/en/copilot/reference/custom-agents-configuration)
- [Codex custom subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Claude Code custom subagents](https://code.claude.com/docs/en/sub-agents)
