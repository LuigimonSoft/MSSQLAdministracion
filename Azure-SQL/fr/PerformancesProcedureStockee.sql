/*
Performances d’une procédure stockée en cache

Requête de diagnostic en lecture seule indiquant le nombre d’exécutions, la durée et le temps processeur totaux, moyens et de la dernière exécution en millisecondes, ainsi que les lectures et écritures logiques totales et moyennes d’une procédure SQL de la base actuelle. Renvoie une ligne par plan en cache, triée par durée totale ; ne regroupe pas plusieurs plans dans un total unique pour la procédure.

Une durée moyenne élevée, associée à un temps processeur et à des lectures logiques élevés, peut révéler des possibilités d’optimisation. Comparer des périodes équivalentes et calculer les différences de compteurs uniquement tant que le même plan reste en cache. Les compteurs concernent les exécutions terminées depuis la compilation et peuvent être réinitialisés après recompilation, éviction ou redémarrage. Un résultat vide ne signifie pas une consommation nulle : aucun plan ne se trouve peut-être en cache. Ces statistiques cumulées ne constituent pas un historique. Les lectures et écritures logiques comptent des pages, pas des octets ni des opérations physiques sur disque.

Exécuter dans la base cible et remplacer @Schema et @Procedure. Le type d’objet P sélectionne les procédures SQL et exclut les procédures CLR. OBJECT_ID peut renvoyer NULL si l’objet est absent ou si ses métadonnées ne sont pas visibles. Les procédures compilées nativement présentent des limites de mesure ; consulter la documentation Microsoft.

Autorisations : Azure SQL Database Basic/S0/S1 et les Elastic Pools nécessitent l’administrateur du serveur, l’administrateur Microsoft Entra ou le rôle ##MS_ServerStateReader##. Les autres objectifs de service nécessitent VIEW DATABASE STATE ou ce rôle. SQL Server 2019 et antérieurs et Azure SQL Managed Instance nécessitent VIEW SERVER STATE ; SQL Server 2022 et ultérieurs nécessitent VIEW SERVER PERFORMANCE STATE.

https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-procedure-stats-transact-sql
*/

SET NOCOUNT ON;

-- Indiquer le schéma et la procédure de la base de données actuelle.
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
