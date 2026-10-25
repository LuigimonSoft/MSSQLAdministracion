/*
Revisión de mantenimiento de índices y estadísticas relacionadas

Evaluación de solo lectura de las estadísticas de tablas referenciadas directamente por un procedimiento SQL mediante dependencias estáticas registradas en la base de datos actual. Muestra índices asociados, definiciones de estadísticas filtradas, última actualización, filas al actualizar, filas muestreadas, contadores de modificaciones y un porcentaje orientativo. Incluye estadísticas independientes de índices y evita escaneos físicos de índices. No mide fragmentación ni ejecuta mantenimiento de índices o estadísticas.

Sustituir @Schema y @Procedure en la base de datos de destino. Las dependencias requieren VIEW DEFINITION sobre la base de datos y SELECT sobre sys.sql_expression_dependencies. Las propiedades de estadísticas requieren SELECT sobre sus columnas, ser propietario de la tabla o un rol administrativo aplicable según la documentación. La visibilidad de metadatos puede limitar los resultados; OBJECT_ID puede devolver NULL si el procedimiento SQL no existe o no es visible. Se distingue entre propiedades no disponibles y ausencia de fecha; una fecha NULL puede aparecer en tablas vacías o estadísticas filtradas sin filas que cumplan el filtro.

La señal de revisión utiliza más de 1.000 filas en la última actualización y más de un 20 % de modificaciones. Es una heurística, no el umbral de actualización automática ni una instrucción para actualizar estadísticas. Relacionarla con errores de estimación, cambios de plan y degradaciones observadas. ModificationPct utiliza las filas de la última actualización, no el tamaño actual de la tabla; puede superar el 100 % y es NULL si el denominador es cero o no está disponible. Normalmente el contador registra cambios en la columna principal del histograma; en tablas optimizadas para memoria registra cambios de la tabla desde la última actualización o reinicio de la base de datos. Las estadísticas filtradas abarcan solo las filas que cumplen su filtro.

Solo incluye dependencias directas y resueltas de tablas locales. No recorre SQL dinámico, dependencias mediante vistas, sinónimos, funciones o procedimientos anidados, ni referencias entre bases de datos. La ausencia de filas no demuestra que no se utilicen tablas ni que no se requiera mantenimiento. Son estadísticas de las tablas, no una prueba de que el procedimiento utilice cada estadística o índice asociado. Las estadísticas incrementales se muestran a nivel global, no por partición. Aplicable a Azure SQL Database, Azure SQL Managed Instance y SQL Server 2016 o posterior.

https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-expression-dependencies-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-stats-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-stats-properties-transact-sql
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
    -- Esta heurística es una señal de revisión, no una regla de mantenimiento automático.
    CASE
        WHEN sp.object_id IS NULL
            THEN N'PROPIEDADES DE ESTADISTICAS NO DISPONIBLES'
        WHEN sp.last_updated IS NULL
            THEN N'SIN FECHA DE ACTUALIZACION DISPONIBLE'
        WHEN sp.rows > 1000
         AND sp.modification_counter > sp.rows * 0.20
            THEN N'REVISAR ESTADISTICAS'
        ELSE N'EVALUAR CON EL PLAN DE EJECUCION'
    END AS ReviewStatus
FROM TablesUsed AS t
INNER JOIN sys.stats AS s ON t.TableObjectId = s.object_id
LEFT JOIN sys.indexes AS i
    ON s.object_id = i.object_id
   AND s.stats_id = i.index_id
OUTER APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
ORDER BY ModificationPct DESC, SchemaName, TableName, StatisticsName;
