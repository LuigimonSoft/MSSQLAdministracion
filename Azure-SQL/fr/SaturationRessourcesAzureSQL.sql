/*
Saturation des ressources Azure SQL

Moniteur de ressources en lecture seule sélectionné selon le moteur. Dans Azure SQL Database, renvoie les 100 derniers intervalles de la base : utilisation moyenne du processeur, de la mémoire, des E/S de données et des écritures du journal, maximums de workers et de sessions et état indicatif. Dans Azure SQL Managed Instance, recommande sys.server_resource_stats au lieu d’interroger une DMV de base non compatible. Les autres moteurs reçoivent un message informatif.

Exécuter dans la base Azure SQL cible avec VIEW DATABASE STATE. sys.dm_db_resource_stats enregistre des intervalles de 15 secondes et conserve environ une heure ; TOP (100) couvre environ 25 minutes si tous les intervalles sont disponibles. CaptureTimeUTC correspond à la fin de l’intervalle, pas à l’exécution du script. Un basculement peut réduire l’historique disponible. Les pourcentages sont relatifs aux limites de service applicables ; pour une base dans un Elastic Pool, ils concernent sa limite configurée, pas l’utilisation globale du pool.

CRITIQUE signifie que le processeur, les E/S de données, les écritures du journal ou le maximum de workers ont atteint au moins 90 % ; AVERTISSEMENT indique qu’une de ces mesures a atteint au moins 75 % ; NORMAL signifie qu’aucune n’a atteint 75 %. Ces seuils sont indicatifs, pas une preuve de saturation ni un diagnostic de santé Azure. La mémoire et les sessions sont affichées sans influer sur ResourceStatus. Une mémoire élevée peut simplement refléter le cache. Corréler la pression durable avec les exécutions de la procédure, Query Store et la latence observée avant d’attribuer une responsabilité.

La branche Managed Instance recommande seulement le moniteur d’instance sans l’interroger. sys.server_resource_stats fournit des lignes de 15 secondes, actualisées avec un délai, et environ 14 jours d’historique. Ce script ne configure aucune alerte, ne programme aucune surveillance et ne modifie aucune ressource. Les noms des colonnes de sortie restent en anglais dans toutes les versions.

https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-resource-stats-azure-sql-database
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-resource-stats-azure-sql-database
*/

SET NOCOUNT ON;

DECLARE @EngineEdition int = CONVERT(int, SERVERPROPERTY('EngineEdition'));

IF @EngineEdition = 5
BEGIN
    -- Compiler la requête de la DMV spécifique uniquement dans Azure SQL Database.
    EXEC sys.sp_executesql N'SELECT TOP (100)
    DB_NAME() AS DatabaseName,
    end_time AS CaptureTimeUTC,
    avg_cpu_percent AS CpuPct,
    avg_memory_usage_percent AS MemoryPct,
    avg_data_io_percent AS DataIOPct,
    avg_log_write_percent AS LogWritePct,
    max_worker_percent AS WorkersPct,
    max_session_percent AS SessionsPct,
    CASE
        WHEN avg_cpu_percent >= 90
          OR avg_data_io_percent >= 90
          OR avg_log_write_percent >= 90
          OR max_worker_percent >= 90
            THEN N''CRITIQUE''
        WHEN avg_cpu_percent >= 75
          OR avg_data_io_percent >= 75
          OR avg_log_write_percent >= 75
          OR max_worker_percent >= 75
            THEN N''AVERTISSEMENT''
        ELSE N''NORMAL''
    END AS ResourceStatus
FROM sys.dm_db_resource_stats
ORDER BY end_time DESC;';
END
ELSE IF @EngineEdition = 8
BEGIN
    SELECT
        N'Azure SQL Managed Instance' AS EngineType,
        N'Utiliser sys.server_resource_stats' AS ResourceMonitor,
        N'Examiner les métriques au niveau de l’instance' AS Notes;
END
ELSE
BEGIN
    SELECT @EngineEdition AS EngineEdition,
        N'Moteur autre qu’Azure SQL Database ou Managed Instance' AS Notes;
END;
