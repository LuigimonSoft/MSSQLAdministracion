/*
Memoria, bloqueos y esperas de un procedimiento almacenado

Captura de solo lectura de las solicitudes activas visibles atribuibles a un procedimiento SQL de la base de datos actual mediante sus handles de SQL o de plan. Muestra duración y CPU en milisegundos, lecturas lógicas, escrituras, espera y recurso actuales, identificador de la sesión bloqueadora, concesiones de memoria de consulta en KB, equipo y aplicación cliente y sentencia actual. Las concesiones corresponden al espacio de trabajo de ejecución, no a toda la memoria del procedimiento.

Sustituir @Schema y @Procedure. SQL Server 2019 y anteriores y Azure SQL Managed Instance requieren VIEW SERVER STATE para consultar otras sesiones; SQL Server 2022 y posteriores requieren VIEW SERVER PERFORMANCE STATE. Azure SQL Database tiene permisos y restricciones de visibilidad por DMV: Microsoft documenta que sys.dm_exec_requests se limita a la conexión actual, mientras que las concesiones de memoria requieren VIEW DATABASE STATE. No debe suponerse que esta consulta permite monitorizar otras conexiones en Azure SQL Database. OBJECT_ID puede devolver NULL si el procedimiento SQL no existe o sus metadatos no son visibles.

Es una captura puntual, no un histórico atómico. Las solicitudes que terminan antes de la captura no aparecen. Las llamadas anidadas y el SQL dinámico pueden no ser atribuibles mediante estos handles. Los campos de concesión NULL indican que no hay una concesión visible coincidente, no memoria total cero; MemoryGrantTime puede ser NULL mientras se espera. CurrentStatement puede ser NULL si no hay texto u offsets disponibles, incluido texto cifrado. Las esperas por solicitud no describen todas las tareas paralelas y los contadores del coordinador en paralelismo en modo fila pueden omitir lecturas y escrituras. Un blocking_session_id positivo identifica una sesión bloqueadora; los negativos tienen significados especiales del motor y 0/NULL puede indicar ausencia de bloqueador o uno no identificado.

Para problemas intermitentes, utilizar Query Store para el rendimiento histórico, Extended Events compatibles para eventos detallados o un muestreo periódico autorizado por separado. Este script no inicia capturas, programa consultas periódicas, cambia la configuración ni termina sesiones.

https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-memory-grants-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sql-text-transact-sql
*/

SET NOCOUNT ON;

-- Indicar el procedimiento SQL de la base de datos actual.
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
