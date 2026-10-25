/*
Histórico de rendimiento con Query Store

Consulta de solo lectura para analizar la evolución del rendimiento de las sentencias de un procedimiento SQL por intervalo de Query Store, consulta y plan. Muestra ejecuciones correctas, duración y CPU promedio ponderadas por número de ejecuciones en milisegundos, lecturas lógicas promedio en páginas de 8 KB y duración máxima en milisegundos. Son métricas por sentencia, no el costo ni el número de invocaciones del procedimiento completo.

Ejecutar en la base de datos de destino y sustituir @Schema, @Procedure y @HoursBack (número positivo de horas; valor inicial 24). El período utiliza una única referencia UTC. Incluye intervalos completos que se solapan con el período; los intervalos de los extremos pueden contener ejecuciones fuera de este. El intervalo actual está incompleto y puede cambiar al finalizar ejecuciones. Las distintas filas de estadísticas de un mismo plan e intervalo se agrupan mediante promedios ponderados por ejecuciones.

Query Store debe haber capturado y conservado el histórico del procedimiento. READ_ONLY permite consultar datos existentes; READ_WRITE es necesario para capturar nuevos datos. La ausencia de filas puede deberse a la política de captura, la retención, la falta de ejecuciones registradas o un histórico no disponible, y no implica consumo cero. Solo incluye ejecuciones regulares finalizadas correctamente (execution_type = 0); excluye ejecuciones canceladas y fallidas. Comparar períodos y cargas equivalentes para investigar regresiones.

Aplicable a Azure SQL Database, Azure SQL Managed Instance y SQL Server 2016 o posterior. Requiere VIEW DATABASE STATE o, cuando se admita, VIEW DATABASE PERFORMANCE STATE (SQL Server 2022 y posteriores). OBJECT_ID puede devolver NULL si el procedimiento SQL no existe o no hay visibilidad de sus metadatos. No modifica la configuración de la base de datos.

https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-interval-transact-sql
*/

SET NOCOUNT ON;

-- Indicar el procedimiento SQL de destino y el período en horas.
DECLARE @Schema sysname = N'dbo';
DECLARE @Procedure sysname = N'TuProcedimientoAlmacenado';
DECLARE @HoursBack int = 24;

IF @HoursBack IS NULL OR @HoursBack <= 0
BEGIN
    THROW 50002, N'HoursBack debe ser mayor que cero.', 1;
END;

DECLARE @WindowEnd datetimeoffset(7) = TODATETIMEOFFSET(SYSUTCDATETIME(), '+00:00');
DECLARE @WindowStart datetimeoffset(7) = DATEADD(HOUR, -@HoursBack, @WindowEnd);

DECLARE @ObjectId int = OBJECT_ID(
    QUOTENAME(@Schema) + N'.' + QUOTENAME(@Procedure), N'P'
);

IF @ObjectId IS NULL
BEGIN
    THROW 50001, N'Procedimiento almacenado SQL no encontrado o no visible para el usuario actual.', 1;
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
  -- Incluir intervalos completos de Query Store que se solapan con el período UTC solicitado.
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
