/*
Index and statistics maintenance review

Read-only assessment of statistics on tables directly referenced by a SQL stored procedure through recorded static dependencies in the current database. Reports associated indexes, filtered-statistics definitions, last update, rows at update, sampled rows, modification counters and a review percentage. Includes standalone column statistics and avoids physical index scans. It does not measure fragmentation or perform index or statistics maintenance.

Replace @Schema and @Procedure in the target database. Dependencies require VIEW DEFINITION on the database and SELECT on sys.sql_expression_dependencies. Statistics properties require SELECT on the statistics columns, ownership of the table or an applicable documented administrative role. Metadata visibility can restrict results; OBJECT_ID can return NULL for an absent or invisible SQL procedure. Missing property rows are distinguished from missing update dates; a NULL update date can occur for empty tables or filtered statistics with no qualifying rows.

The review flag uses more than 1,000 rows at the last update and more than 20% modifications. This is a heuristic, not the automatic statistics update threshold or an instruction to update statistics. Correlate it with estimation errors, plan changes and observed performance degradation. ModificationPct uses rows at the last statistics update, not current table size; it can exceed 100% and is NULL when the denominator is zero or unavailable. Normally the counter tracks changes to the leading histogram column; for memory-optimized tables it tracks table changes since the last update or database restart. Filtered statistics cover only their qualifying rows.

Only direct, resolved local table dependencies are included. Dynamic SQL, dependencies through views, synonyms, functions or nested procedures, and cross-database references are not traversed. No rows does not establish that no tables are used or no maintenance is needed. These are table statistics, not proof that the procedure uses each statistic or associated index. Incremental statistics are shown at the global level, not by partition. Applies to Azure SQL Database, Azure SQL Managed Instance and SQL Server 2016 or later.

https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-expression-dependencies-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-stats-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-stats-properties-transact-sql
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

;WITH TablesUsed AS
(
    SELECT DISTINCT d.referenced_id AS TableObjectId
    FROM sys.sql_expression_dependencies AS d
    INNER JOIN sys.tables AS t ON d.referenced_id = t.object_id
    WHERE d.referencing_id = @ObjectId
      AND d.referenced_class = 1
)
SELECT
    OBJECT_SCHEMA_NAME(s.object_id) AS SchemaName,
    OBJECT_NAME(s.object_id) AS TableName,
    s.name AS StatisticsName,
    i.name AS AssociatedIndex,
    s.has_filter AS HasFilter,
    s.filter_definition AS FilterDefinition,
    sp.last_updated AS LastStatsUpdate,
    sp.rows AS RowsAtUpdate,
    sp.rows_sampled AS RowsSampled,
    sp.modification_counter AS Modifications,
    CAST(100.0 * sp.modification_counter /
        NULLIF(sp.rows, 0) AS decimal(28,2)) AS ModificationPct,
    -- This heuristic is a review signal, not an automatic maintenance rule.
    CASE
        WHEN sp.object_id IS NULL
            THEN N'STATISTICS PROPERTIES UNAVAILABLE'
        WHEN sp.last_updated IS NULL
            THEN N'NO UPDATE DATE AVAILABLE'
        WHEN sp.rows > 1000
         AND sp.modification_counter > sp.rows * 0.20
            THEN N'REVIEW STATISTICS'
        ELSE N'EVALUATE WITH EXECUTION PLAN'
    END AS ReviewStatus
FROM TablesUsed AS t
INNER JOIN sys.stats AS s ON t.TableObjectId = s.object_id
LEFT JOIN sys.indexes AS i
    ON s.object_id = i.object_id
   AND s.stats_id = i.index_id
OUTER APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
ORDER BY ModificationPct DESC, SchemaName, TableName, StatisticsName;
