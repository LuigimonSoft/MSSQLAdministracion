# MSSQLAdministracion
Repositorio de consultas para facilitar la administración y la solución de problemas en bases de datos MS SQL.

Estas consultas ayudan a mejorar el rendimiento de las bases de datos y facilitan su administración.

## Índice

- [MSSQL](#mssql)
  - [ConsultaTiempos.sql](#query-1)
  - [ConsultasBloqueadas.sql](#query-2)
  - [Paginado.sql](#query-3)
  - [ReducirLOG.sql](#query-4)
  - [FechaHoraZonaHorairo.sql](#query-5)
- [Azure SQL](#azure-sql)
  - [Autodescubrimiento del entorno Azure SQL](#query-6)
  - [Rendimiento de un procedimiento almacenado en caché](#query-7)
  - [Histórico de rendimiento con Query Store](#query-8)
  - [Memoria, bloqueos y esperas de un procedimiento almacenado](#query-9)
  - [Revisión de mantenimiento de índices y estadísticas relacionadas](#query-10)
  - [Saturación de recursos de Azure SQL](#query-11)
  - [Auditoría de permisos explícitos del procedimiento](#query-12)
- [Agente DBA](#agente-dba)
- [Fuentes](#fuentes)

## MSSQL

<a id="query-1"></a>

- [ConsultaTiempos.sql](es/ConsultaTiempos.sql)<br>
  Muestra las consultas que tardan más tiempo en ejecutarse, junto con sus lecturas, uso de CPU y planes de ejecución, para facilitar su optimización.

<a id="query-2"></a>

- [ConsultasBloqueadas.sql](es/ConsultasBloqueadas.sql)<br>
  Muestra las sesiones de usuario en espera e identifica las sesiones que las bloquean.

<a id="query-3"></a>

- [Paginado.sql](es/Paginado.sql)<br>
  Consulta para paginar los resultados de una tabla.

<a id="query-4"></a>

- [ReducirLOG.sql](es/ReducirLOG.sql)<br>
  Permite reducir el tamaño del archivo de registro de la base de datos (recuerda realizar una copia de seguridad antes).

<a id="query-5"></a>

- [FechaHoraZonaHorairo.sql](es/FechaHoraZonaHorairo.sql)<br>
  Devuelve la hora exacta de una zona horaria del mundo; este ejemplo utiliza la zona horaria del centro de México.

## Azure SQL

<a id="query-6"></a>

- [Autodescubrimiento del entorno Azure SQL](Azure-SQL/es/AutodescubrimientoAzureSQL.sql)<br>
  Script de diagnóstico de solo lectura para la base de datos actual. Identifica la familia del motor, la edición y la versión, el nivel de compatibilidad, READ_COMMITTED_SNAPSHOT (RCSI), los estados real y deseado de Query Store y los permisos efectivos de diagnóstico. En Azure SQL Database, también muestra el nivel y el objetivo de servicio y la pertenencia a un Elastic Pool.

Ejecutar en la base de datos de destino, en lugar de master. Previsto para Azure SQL Database, Azure SQL Managed Instance y SQL Server 2016 o posterior; otros motores no están validados. Query Store requiere VIEW DATABASE STATE o, cuando se admita, VIEW DATABASE PERFORMANCE STATE. Los metadatos de servicio requieren permisos adecuados de propietario de la base de datos o dbManager en master. Permisos: 1 = concedido, 0 = no concedido, NULL = no válido o evaluación fallida. Si no se pueden leer metadatos opcionales, se imprime el error del motor; los estados NULL de Query Store no significan OFF.

Documentación de Microsoft: [SERVERPROPERTY](https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql), [sys.database_query_store_options](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-query-store-options-transact-sql), [sys.database_service_objectives](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-service-objectives-azure-sql-database), [HAS_PERMS_BY_NAME](https://learn.microsoft.com/en-us/sql/t-sql/functions/has-perms-by-name-transact-sql).

<a id="query-7"></a>

- [Rendimiento de un procedimiento almacenado en caché](Azure-SQL/es/RendimientoProcedimientoAlmacenado.sql)<br>
  Consulta de diagnóstico de solo lectura que muestra el número de ejecuciones, la duración y CPU totales, promedio y de la última ejecución en milisegundos, y las lecturas y escrituras lógicas totales y promedio de un procedimiento SQL de la base de datos actual. Devuelve una fila por plan en caché, ordenada por duración total; no suma varios planes en un único total del procedimiento.

Una duración promedio elevada, junto con CPU y lecturas lógicas altas, ayuda a identificar oportunidades de optimización. Comparar períodos equivalentes y calcular diferencias de contadores solo mientras el mismo plan permanezca en caché. Los contadores incluyen ejecuciones finalizadas desde la compilación y pueden reiniciarse por recompilación, expulsión de caché o reinicio. Un resultado vacío no significa consumo cero: puede no haber un plan en caché. Son estadísticas acumuladas de caché, no una serie histórica. Las lecturas y escrituras lógicas cuentan páginas, no bytes ni operaciones físicas de disco.

Ejecutar en la base de datos de destino y sustituir @Schema y @Procedure. El tipo de objeto P selecciona procedimientos SQL y excluye procedimientos CLR. OBJECT_ID puede devolver NULL si el objeto no existe o no hay visibilidad de sus metadatos. Los procedimientos compilados de forma nativa tienen limitaciones en sus métricas; consultar la documentación de Microsoft.

Permisos: Azure SQL Database Basic/S0/S1 y Elastic Pools requieren el administrador del servidor, el administrador de Microsoft Entra o el rol ##MS_ServerStateReader##. Otros objetivos de servicio requieren VIEW DATABASE STATE o ese rol. SQL Server 2019 y anteriores y Azure SQL Managed Instance requieren VIEW SERVER STATE; SQL Server 2022 y posteriores requieren VIEW SERVER PERFORMANCE STATE.

[sys.dm_exec_procedure_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-procedure-stats-transact-sql).

<a id="query-8"></a>

- [Histórico de rendimiento con Query Store](Azure-SQL/es/HistoricoRendimientoQueryStore.sql)<br>
  Consulta de solo lectura para analizar la evolución del rendimiento de las sentencias de un procedimiento SQL por intervalo de Query Store, consulta y plan. Muestra ejecuciones correctas, duración y CPU promedio ponderadas por número de ejecuciones en milisegundos, lecturas lógicas promedio en páginas de 8 KB y duración máxima en milisegundos. Son métricas por sentencia, no el costo ni el número de invocaciones del procedimiento completo.

Ejecutar en la base de datos de destino y sustituir @Schema, @Procedure y @HoursBack (número positivo de horas; valor inicial 24). El período utiliza una única referencia UTC. Incluye intervalos completos que se solapan con el período; los intervalos de los extremos pueden contener ejecuciones fuera de este. El intervalo actual está incompleto y puede cambiar al finalizar ejecuciones. Las distintas filas de estadísticas de un mismo plan e intervalo se agrupan mediante promedios ponderados por ejecuciones.

Query Store debe haber capturado y conservado el histórico del procedimiento. READ_ONLY permite consultar datos existentes; READ_WRITE es necesario para capturar nuevos datos. La ausencia de filas puede deberse a la política de captura, la retención, la falta de ejecuciones registradas o un histórico no disponible, y no implica consumo cero. Solo incluye ejecuciones regulares finalizadas correctamente (execution_type = 0); excluye ejecuciones canceladas y fallidas. Comparar períodos y cargas equivalentes para investigar regresiones.

Aplicable a Azure SQL Database, Azure SQL Managed Instance y SQL Server 2016 o posterior. Requiere VIEW DATABASE STATE o, cuando se admita, VIEW DATABASE PERFORMANCE STATE (SQL Server 2022 y posteriores). OBJECT_ID puede devolver NULL si el procedimiento SQL no existe o no hay visibilidad de sus metadatos. No modifica la configuración de la base de datos.

[sys.query_store_runtime_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql), [sys.query_store_runtime_stats_interval](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-interval-transact-sql).

<a id="query-9"></a>

- [Memoria, bloqueos y esperas de un procedimiento almacenado](Azure-SQL/es/MonitorActivoProcedimientoAlmacenado.sql)<br>
  Captura de solo lectura de las solicitudes activas visibles atribuibles a un procedimiento SQL de la base de datos actual mediante sus handles de SQL o de plan. Muestra duración y CPU en milisegundos, lecturas lógicas, escrituras, espera y recurso actuales, identificador de la sesión bloqueadora, concesiones de memoria de consulta en KB, equipo y aplicación cliente y sentencia actual. Las concesiones corresponden al espacio de trabajo de ejecución, no a toda la memoria del procedimiento.

Sustituir @Schema y @Procedure. SQL Server 2019 y anteriores y Azure SQL Managed Instance requieren VIEW SERVER STATE para consultar otras sesiones; SQL Server 2022 y posteriores requieren VIEW SERVER PERFORMANCE STATE. Azure SQL Database tiene permisos y restricciones de visibilidad por DMV: Microsoft documenta que sys.dm_exec_requests se limita a la conexión actual, mientras que las concesiones de memoria requieren VIEW DATABASE STATE. No debe suponerse que esta consulta permite monitorizar otras conexiones en Azure SQL Database. OBJECT_ID puede devolver NULL si el procedimiento SQL no existe o sus metadatos no son visibles.

Es una captura puntual, no un histórico atómico. Las solicitudes que terminan antes de la captura no aparecen. Las llamadas anidadas y el SQL dinámico pueden no ser atribuibles mediante estos handles. Los campos de concesión NULL indican que no hay una concesión visible coincidente, no memoria total cero; MemoryGrantTime puede ser NULL mientras se espera. CurrentStatement puede ser NULL si no hay texto u offsets disponibles, incluido texto cifrado. Las esperas por solicitud no describen todas las tareas paralelas y los contadores del coordinador en paralelismo en modo fila pueden omitir lecturas y escrituras. Un blocking_session_id positivo identifica una sesión bloqueadora; los negativos tienen significados especiales del motor y 0/NULL puede indicar ausencia de bloqueador o uno no identificado.

Para problemas intermitentes, utilizar Query Store para el rendimiento histórico, Extended Events compatibles para eventos detallados o un muestreo periódico autorizado por separado. Este script no inicia capturas, programa consultas periódicas, cambia la configuración ni termina sesiones.

[sys.dm_exec_requests](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql), [sys.dm_exec_query_memory_grants](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-memory-grants-transact-sql), [sys.dm_exec_sql_text](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sql-text-transact-sql).

<a id="query-10"></a>

- [Revisión de mantenimiento de índices y estadísticas relacionadas](Azure-SQL/es/RevisionIndicesEstadisticasRelacionadas.sql)<br>
  Evaluación de solo lectura de las estadísticas de tablas referenciadas directamente por un procedimiento SQL mediante dependencias estáticas registradas en la base de datos actual. Muestra índices asociados, definiciones de estadísticas filtradas, última actualización, filas al actualizar, filas muestreadas, contadores de modificaciones y un porcentaje orientativo. Incluye estadísticas independientes de índices y evita escaneos físicos de índices. No mide fragmentación ni ejecuta mantenimiento de índices o estadísticas.

Sustituir @Schema y @Procedure en la base de datos de destino. Las dependencias requieren VIEW DEFINITION sobre la base de datos y SELECT sobre sys.sql_expression_dependencies. Las propiedades de estadísticas requieren SELECT sobre sus columnas, ser propietario de la tabla o un rol administrativo aplicable según la documentación. La visibilidad de metadatos puede limitar los resultados; OBJECT_ID puede devolver NULL si el procedimiento SQL no existe o no es visible. Se distingue entre propiedades no disponibles y ausencia de fecha; una fecha NULL puede aparecer en tablas vacías o estadísticas filtradas sin filas que cumplan el filtro.

La señal de revisión utiliza más de 1.000 filas en la última actualización y más de un 20 % de modificaciones. Es una heurística, no el umbral de actualización automática ni una instrucción para actualizar estadísticas. Relacionarla con errores de estimación, cambios de plan y degradaciones observadas. ModificationPct utiliza las filas de la última actualización, no el tamaño actual de la tabla; puede superar el 100 % y es NULL si el denominador es cero o no está disponible. Normalmente el contador registra cambios en la columna principal del histograma; en tablas optimizadas para memoria registra cambios de la tabla desde la última actualización o reinicio de la base de datos. Las estadísticas filtradas abarcan solo las filas que cumplen su filtro.

Solo incluye dependencias directas y resueltas de tablas locales. No recorre SQL dinámico, dependencias mediante vistas, sinónimos, funciones o procedimientos anidados, ni referencias entre bases de datos. La ausencia de filas no demuestra que no se utilicen tablas ni que no se requiera mantenimiento. Son estadísticas de las tablas, no una prueba de que el procedimiento utilice cada estadística o índice asociado. Las estadísticas incrementales se muestran a nivel global, no por partición. Aplicable a Azure SQL Database, Azure SQL Managed Instance y SQL Server 2016 o posterior.

[sys.sql_expression_dependencies](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-expression-dependencies-transact-sql), [sys.stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-stats-transact-sql), [sys.dm_db_stats_properties](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-stats-properties-transact-sql).

<a id="query-11"></a>

- [Saturación de recursos de Azure SQL](Azure-SQL/es/SaturacionRecursosAzureSQL.sql)<br>
  Monitor de recursos de solo lectura seleccionado según el motor. En Azure SQL Database devuelve los 100 intervalos más recientes de la base de datos: utilización promedio de CPU, memoria, E/S de datos y escrituras del log, máximos de workers y sesiones y un estado orientativo. En Azure SQL Managed Instance indica que debe utilizarse sys.server_resource_stats en lugar de consultar una DMV de base de datos no compatible. En otros motores devuelve un mensaje informativo.

Ejecutar en la base de datos Azure SQL de destino con VIEW DATABASE STATE. sys.dm_db_resource_stats registra intervalos de 15 segundos y conserva aproximadamente una hora; TOP (100) cubre unos 25 minutos si están disponibles todos los intervalos. CaptureTimeUTC es el final del intervalo, no la hora de ejecución del script. Una conmutación por error puede reducir el histórico disponible. Los porcentajes son relativos a los límites de servicio aplicables; en una base de datos de Elastic Pool se refieren al límite configurado para esa base, no al consumo global del pool.

CRITICO indica que CPU, E/S de datos, escrituras del log o máximo de workers alcanzaron al menos el 90 %; ADVERTENCIA indica que alguno alcanzó al menos el 75 %; NORMAL indica que ninguna de esas métricas alcanzó el 75 %. Son umbrales ilustrativos, no una prueba de saturación ni un diagnóstico de salud de Azure. Memoria y sesiones se muestran, pero no afectan a ResourceStatus. Una memoria alta por sí sola puede reflejar el uso de caché. Correlacionar la presión sostenida con ejecuciones del procedimiento, Query Store y latencia observada antes de atribuirle responsabilidad.

La rama de Managed Instance solo recomienda el monitor de instancia; no lo consulta. sys.server_resource_stats proporciona filas de intervalos de 15 segundos, actualizadas con demora, y aproximadamente 14 días de histórico. Este script no configura alertas, programa monitorización ni cambia recursos. Los nombres de columnas de salida se mantienen en inglés en todas las versiones.

[sys.dm_db_resource_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-resource-stats-azure-sql-database), [sys.server_resource_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-resource-stats-azure-sql-database).

<a id="query-12"></a>

- [Auditoría de permisos explícitos del procedimiento](Azure-SQL/es/AuditoriaPermisosProcedimiento.sql)<br>
  Auditoría de solo lectura de los permisos explícitos visibles a nivel de objeto de un procedimiento SQL y de su contexto de ejecución declarado. Muestra esquema y procedimiento, identificador y nombre resuelto del principal de EXECUTE AS, propietario actual del objeto, destinatario y tipo de principal, otorgante, permiso y estado. El destinatario puede ser un usuario, un rol u otro principal de base de datos; no se expande su pertenencia.

Ejecutar en la base de datos de destino y sustituir @Schema y @Procedure. LLAMADOR deja ExecuteAsPrincipal en NULL porque el llamador depende de cada invocación. PROPIETARIO resuelve el propietario actual del objeto y utiliza el del esquema si no hay uno explícito. Un identificador de principal puede corresponder a EXECUTE AS SELF o a un usuario nombrado explícitamente; por sí solo no distingue la declaración original. Los nombres de columnas y las descripciones de permisos y tipos proporcionadas por el catálogo permanecen en inglés.

Se aplican las restricciones de visibilidad de metadatos: los resultados pueden ser incompletos si la cuenta auditora no puede ver el objeto, módulo, permisos y principales pertinentes. Utilizar una cuenta autorizada con visibilidad suficiente, como el propietario de la base de datos, para una revisión completa a nivel de objeto. OBJECT_ID puede devolver NULL si el procedimiento SQL no existe o no es visible. Una fila con columnas de permisos NULL indica que no se ve ningún permiso explícito, no que nadie pueda ejecutar el procedimiento. Un nombre de principal resuelto NULL puede indicar metadatos no disponibles.

No calcula permisos efectivos derivados de pertenencia a roles, incluidos roles fijos, propiedad, permisos de esquema, base de datos o servidor, cadenas de propiedad, firmas de módulos u otros contextos de ejecución. Tampoco demuestra ni descarta SQL Injection: eso requiere analizar el código y el tratamiento de entradas. No concede, deniega ni revoca permisos ni suplanta usuarios. Aplicable a Azure SQL Database, Azure SQL Managed Instance y SQL Server 2016 o posterior.

[sys.sql_modules](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql), [sys.database_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql), [EXECUTE AS](https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql).

## Agente DBA

[Prompt de sistema del agente DBA](Azure-SQL/Agents/es/AgenteDBAStoredProcedure.md)

Prompt en español para crear Azure SQL Stored Procedure Deep Analyzer, un agente experto en diagnóstico, optimización, seguridad, mantenimiento y monitoreo de procedimientos almacenados. Copia el contenido completo del archivo en las instrucciones de sistema del agente. El agente no tiene conexión directa a la base de datos: un DBA humano ejecuta las consultas de diagnóstico y comparte los resultados.

Si recibe un archivo del procedimiento al inicio, el agente lo lee y presenta una evaluación estática preliminar antes del autodescubrimiento y las pruebas diagnósticas dirigidas.

Idiomas disponibles: [English](Azure-SQL/Agents/StoredProcedureDBAAgent.md) · [Español](Azure-SQL/Agents/es/AgenteDBAStoredProcedure.md) · [Français](Azure-SQL/Agents/fr/AgentDBAProcedureStockee.md)

[Perfiles específicos para GitHub Copilot, Codex y Claude Code, con instrucciones de instalación en tres idiomas](Azure-SQL/Agents/Integrations/README.es.md).

## Fuentes

Documentación oficial de Microsoft Learn utilizada para revisar las consultas, métricas, permisos y limitaciones.

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
