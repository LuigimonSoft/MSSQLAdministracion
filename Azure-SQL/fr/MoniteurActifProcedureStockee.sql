/*
Mémoire, blocages et attentes d’une procédure stockée

Capture en lecture seule des requêtes actives visibles attribuables à une procédure SQL de la base actuelle via leurs handles SQL ou de plan. Affiche la durée et le temps processeur en millisecondes, les lectures logiques, les écritures, l’attente et la ressource actuelles, l’identifiant de session bloquante, les allocations mémoire de requête en Ko, l’hôte et l’application cliente et l’instruction actuelle. Les allocations concernent l’espace de travail d’exécution, pas toute la mémoire de la procédure.

Remplacer @Schema et @Procedure. SQL Server 2019 et antérieurs et Azure SQL Managed Instance nécessitent VIEW SERVER STATE pour consulter les autres sessions ; SQL Server 2022 et ultérieurs nécessitent VIEW SERVER PERFORMANCE STATE. Azure SQL Database applique des autorisations et restrictions de visibilité propres à chaque DMV : Microsoft indique que sys.dm_exec_requests se limite à la connexion actuelle, tandis que les allocations mémoire nécessitent VIEW DATABASE STATE. Ne pas supposer que cette requête permet de surveiller les autres connexions dans Azure SQL Database. OBJECT_ID peut renvoyer NULL si la procédure SQL est absente ou si ses métadonnées ne sont pas visibles.

Il s’agit d’une capture ponctuelle, pas d’un historique atomique. Les requêtes terminées avant la capture sont absentes. Les appels imbriqués et le SQL dynamique peuvent ne pas être attribuables via ces handles. Des champs mémoire NULL indiquent l’absence d’allocation visible correspondante, pas une mémoire totale nulle ; MemoryGrantTime peut être NULL pendant l’attente. CurrentStatement peut être NULL lorsque le texte ou les offsets sont indisponibles, notamment pour du texte chiffré. Les attentes par requête ne décrivent pas toutes les tâches parallèles et les compteurs du coordinateur en parallélisme en mode ligne peuvent omettre lectures et écritures. Un blocking_session_id positif identifie une session bloquante ; les valeurs négatives ont des significations particulières et 0/NULL peut indiquer l’absence de bloqueur ou un bloqueur non identifié.

Pour les problèmes intermittents, utiliser Query Store pour les performances historiques, les Extended Events compatibles pour les événements détaillés ou un échantillonnage périodique autorisé séparément. Ce script ne lance aucune capture, ne programme aucun sondage, ne modifie aucune configuration et ne termine aucune session.

https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-memory-grants-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sql-text-transact-sql
*/

SET NOCOUNT ON;

-- Indiquer la procédure SQL de la base de données actuelle.
DECLARE @Schema sysname = N'dbo';
DECLARE @Procedure sysname = N'VotreProcedureStockee';

DECLARE @ObjectId int = OBJECT_ID(
    QUOTENAME(@Schema) + N'.' + QUOTENAME(@Procedure), N'P'
);

IF @ObjectId IS NULL
BEGIN
    THROW 50001, N'Procédure stockée SQL introuvable ou non visible pour cet utilisateur.', 1;
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
