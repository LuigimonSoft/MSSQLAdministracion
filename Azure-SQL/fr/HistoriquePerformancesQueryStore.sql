/*
Historique des performances avec Query Store

Requête en lecture seule pour suivre les performances des instructions d’une procédure SQL par intervalle Query Store, requête et plan. Affiche le nombre d’exécutions réussies, les moyennes de durée et de temps processeur pondérées par les exécutions en millisecondes, les lectures logiques moyennes en pages de 8 Ko et la durée maximale en millisecondes. Ces mesures concernent les instructions, pas le coût ni le nombre d’appels de la procédure complète.

Exécuter dans la base cible et remplacer @Schema, @Procedure et @HoursBack (nombre positif d’heures ; valeur initiale 24). La période utilise une référence UTC fixe. Inclut les intervalles entiers chevauchant la période ; les intervalles aux limites peuvent contenir des exécutions hors période. L’intervalle actuel est incomplet et peut évoluer à la fin des exécutions. Les différentes lignes statistiques d’un même plan et intervalle sont regroupées par moyennes pondérées selon les exécutions.

Query Store doit avoir capturé et conservé l’historique de la procédure. READ_ONLY permet de consulter les données existantes ; READ_WRITE est nécessaire pour en collecter de nouvelles. L’absence de lignes peut résulter de la politique de capture, de la rétention, de l’absence d’exécutions enregistrées ou d’un historique indisponible, sans signifier une consommation nulle. Seules les exécutions normales terminées avec succès sont incluses (execution_type = 0) ; les exécutions annulées et en échec sont exclues. Comparer des périodes et des charges équivalentes pour étudier les régressions.

Applicable à Azure SQL Database, Azure SQL Managed Instance et SQL Server 2016 ou ultérieur. Nécessite VIEW DATABASE STATE ou, si disponible, VIEW DATABASE PERFORMANCE STATE (SQL Server 2022 et ultérieurs). OBJECT_ID peut renvoyer NULL si la procédure SQL est absente ou si ses métadonnées ne sont pas visibles. Ne modifie pas la configuration de la base.

https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-interval-transact-sql
*/

SET NOCOUNT ON;

-- Indiquer la procédure SQL cible et la période en heures.
DECLARE @Schema sysname = N'dbo';
DECLARE @Procedure sysname = N'VotreProcedureStockee';
DECLARE @HoursBack int = 24;

IF @HoursBack IS NULL OR @HoursBack <= 0
BEGIN
    THROW 50002, N'HoursBack doit être supérieur à zéro.', 1;
END;

DECLARE @WindowEnd datetimeoffset(7) = TODATETIMEOFFSET(SYSUTCDATETIME(), '+00:00');
DECLARE @WindowStart datetimeoffset(7) = DATEADD(HOUR, -@HoursBack, @WindowEnd);

DECLARE @ObjectId int = OBJECT_ID(
    QUOTENAME(@Schema) + N'.' + QUOTENAME(@Procedure), N'P'
);

IF @ObjectId IS NULL
BEGIN
    THROW 50001, N'Procédure stockée SQL introuvable ou non visible pour cet utilisateur.', 1;
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
  -- Inclure les intervalles Query Store entiers chevauchant la période UTC demandée.
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
