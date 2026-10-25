/*
Rendimiento de un procedimiento almacenado en caché

Consulta de diagnóstico de solo lectura que muestra el número de ejecuciones, la duración y CPU totales, promedio y de la última ejecución en milisegundos, y las lecturas y escrituras lógicas totales y promedio de un procedimiento SQL de la base de datos actual. Devuelve una fila por plan en caché, ordenada por duración total; no suma varios planes en un único total del procedimiento.

Una duración promedio elevada, junto con CPU y lecturas lógicas altas, ayuda a identificar oportunidades de optimización. Comparar períodos equivalentes y calcular diferencias de contadores solo mientras el mismo plan permanezca en caché. Los contadores incluyen ejecuciones finalizadas desde la compilación y pueden reiniciarse por recompilación, expulsión de caché o reinicio. Un resultado vacío no significa consumo cero: puede no haber un plan en caché. Son estadísticas acumuladas de caché, no una serie histórica. Las lecturas y escrituras lógicas cuentan páginas, no bytes ni operaciones físicas de disco.

Ejecutar en la base de datos de destino y sustituir @Schema y @Procedure. El tipo de objeto P selecciona procedimientos SQL y excluye procedimientos CLR. OBJECT_ID puede devolver NULL si el objeto no existe o no hay visibilidad de sus metadatos. Los procedimientos compilados de forma nativa tienen limitaciones en sus métricas; consultar la documentación de Microsoft.

Permisos: Azure SQL Database Basic/S0/S1 y Elastic Pools requieren el administrador del servidor, el administrador de Microsoft Entra o el rol ##MS_ServerStateReader##. Otros objetivos de servicio requieren VIEW DATABASE STATE o ese rol. SQL Server 2019 y anteriores y Azure SQL Managed Instance requieren VIEW SERVER STATE; SQL Server 2022 y posteriores requieren VIEW SERVER PERFORMANCE STATE.

https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-procedure-stats-transact-sql
*/

SET NOCOUNT ON;

-- Indicar el esquema y el procedimiento de la base de datos actual.
DECLARE @Schema sysname = N'dbo';
DECLARE @Procedure sysname = N'TuProcedimientoAlmacenado';

DECLARE @ObjectId int = OBJECT_ID(
    QUOTENAME(@Schema) + N'.' + QUOTENAME(@Procedure), N'P'
);

IF @ObjectId IS NULL
BEGIN
    THROW 50001, N'Procedimiento almacenado SQL no encontrado o no visible para el usuario actual.', 1;
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
