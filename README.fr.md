# MSSQLAdministracion
Dépôt de requêtes pour faciliter l’administration et le dépannage des bases de données MS SQL.

Ces requêtes permettent d’améliorer les performances des bases de données et facilitent leur administration.

## Sommaire

- [MSSQL](#mssql)
  - [TempsExecutionRequetes.sql](#query-1)
  - [RequetesBloquees.sql](#query-2)
  - [Pagination.sql](#query-3)
  - [ReduireJournal.sql](#query-4)
  - [DateHeureFuseauHoraire.sql](#query-5)
- [Azure SQL](#azure-sql)
  - [Découverte de l’environnement Azure SQL](#query-6)
  - [Performances d’une procédure stockée en cache](#query-7)
  - [Historique des performances avec Query Store](#query-8)
  - [Mémoire, blocages et attentes d’une procédure stockée](#query-9)
  - [Examen de la maintenance des index et statistiques associés](#query-10)
  - [Saturation des ressources Azure SQL](#query-11)
  - [Audit des autorisations explicites de la procédure](#query-12)
- [Agent DBA](#agent-dba)
- [Sources](#sources)

## MSSQL

<a id="query-1"></a>

- [TempsExecutionRequetes.sql](fr/TempsExecutionRequetes.sql)<br>
  Affiche les requêtes dont l’exécution est la plus longue, ainsi que leurs lectures, leur utilisation du processeur et leurs plans d’exécution, afin de faciliter leur optimisation.

<a id="query-2"></a>

- [RequetesBloquees.sql](fr/RequetesBloquees.sql)<br>
  Affiche les sessions utilisateur en attente et identifie les sessions qui les bloquent.

<a id="query-3"></a>

- [Pagination.sql](fr/Pagination.sql)<br>
  Requête permettant de paginer les résultats d’une table.

<a id="query-4"></a>

- [ReduireJournal.sql](fr/ReduireJournal.sql)<br>
  Permet de réduire la taille du fichier journal de la base de données (penser à effectuer une sauvegarde au préalable).

<a id="query-5"></a>

- [DateHeureFuseauHoraire.sql](fr/DateHeureFuseauHoraire.sql)<br>
  Renvoie l’heure exacte d’un fuseau horaire dans le monde ; cet exemple utilise le fuseau horaire du centre du Mexique.

## Azure SQL

<a id="query-6"></a>

- [Découverte de l’environnement Azure SQL](Azure-SQL/fr/DecouverteAzureSQL.sql)<br>
  Script de diagnostic en lecture seule pour la base de données actuelle. Identifie la famille du moteur, l’édition et la version, le niveau de compatibilité, READ_COMMITTED_SNAPSHOT (RCSI), les états réel et souhaité de Query Store et les autorisations effectives de diagnostic. Dans Azure SQL Database, affiche également le niveau et l’objectif de service ainsi que l’appartenance à un Elastic Pool.

Exécuter dans la base de données cible plutôt que dans master. Prévu pour Azure SQL Database, Azure SQL Managed Instance et SQL Server 2016 ou ultérieur ; les autres moteurs ne sont pas validés. Query Store nécessite VIEW DATABASE STATE ou, si disponible, VIEW DATABASE PERFORMANCE STATE. Les métadonnées de service nécessitent les autorisations appropriées de propriétaire de la base ou dbManager dans master. Autorisations : 1 = accordée, 0 = non accordée, NULL = non valide ou échec de l’évaluation. Si les métadonnées facultatives sont inaccessibles, le script affiche l’erreur du moteur ; les états NULL de Query Store ne signifient pas OFF.

Documentation Microsoft: [SERVERPROPERTY](https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql), [sys.database_query_store_options](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-query-store-options-transact-sql), [sys.database_service_objectives](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-service-objectives-azure-sql-database), [HAS_PERMS_BY_NAME](https://learn.microsoft.com/en-us/sql/t-sql/functions/has-perms-by-name-transact-sql).

<a id="query-7"></a>

- [Performances d’une procédure stockée en cache](Azure-SQL/fr/PerformancesProcedureStockee.sql)<br>
  Requête de diagnostic en lecture seule indiquant le nombre d’exécutions, la durée et le temps processeur totaux, moyens et de la dernière exécution en millisecondes, ainsi que les lectures et écritures logiques totales et moyennes d’une procédure SQL de la base actuelle. Renvoie une ligne par plan en cache, triée par durée totale ; ne regroupe pas plusieurs plans dans un total unique pour la procédure.

Une durée moyenne élevée, associée à un temps processeur et à des lectures logiques élevés, peut révéler des possibilités d’optimisation. Comparer des périodes équivalentes et calculer les différences de compteurs uniquement tant que le même plan reste en cache. Les compteurs concernent les exécutions terminées depuis la compilation et peuvent être réinitialisés après recompilation, éviction ou redémarrage. Un résultat vide ne signifie pas une consommation nulle : aucun plan ne se trouve peut-être en cache. Ces statistiques cumulées ne constituent pas un historique. Les lectures et écritures logiques comptent des pages, pas des octets ni des opérations physiques sur disque.

Exécuter dans la base cible et remplacer @Schema et @Procedure. Le type d’objet P sélectionne les procédures SQL et exclut les procédures CLR. OBJECT_ID peut renvoyer NULL si l’objet est absent ou si ses métadonnées ne sont pas visibles. Les procédures compilées nativement présentent des limites de mesure ; consulter la documentation Microsoft.

Autorisations : Azure SQL Database Basic/S0/S1 et les Elastic Pools nécessitent l’administrateur du serveur, l’administrateur Microsoft Entra ou le rôle ##MS_ServerStateReader##. Les autres objectifs de service nécessitent VIEW DATABASE STATE ou ce rôle. SQL Server 2019 et antérieurs et Azure SQL Managed Instance nécessitent VIEW SERVER STATE ; SQL Server 2022 et ultérieurs nécessitent VIEW SERVER PERFORMANCE STATE.

[sys.dm_exec_procedure_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-procedure-stats-transact-sql).

<a id="query-8"></a>

- [Historique des performances avec Query Store](Azure-SQL/fr/HistoriquePerformancesQueryStore.sql)<br>
  Requête en lecture seule pour suivre les performances des instructions d’une procédure SQL par intervalle Query Store, requête et plan. Affiche le nombre d’exécutions réussies, les moyennes de durée et de temps processeur pondérées par les exécutions en millisecondes, les lectures logiques moyennes en pages de 8 Ko et la durée maximale en millisecondes. Ces mesures concernent les instructions, pas le coût ni le nombre d’appels de la procédure complète.

Exécuter dans la base cible et remplacer @Schema, @Procedure et @HoursBack (nombre positif d’heures ; valeur initiale 24). La période utilise une référence UTC fixe. Inclut les intervalles entiers chevauchant la période ; les intervalles aux limites peuvent contenir des exécutions hors période. L’intervalle actuel est incomplet et peut évoluer à la fin des exécutions. Les différentes lignes statistiques d’un même plan et intervalle sont regroupées par moyennes pondérées selon les exécutions.

Query Store doit avoir capturé et conservé l’historique de la procédure. READ_ONLY permet de consulter les données existantes ; READ_WRITE est nécessaire pour en collecter de nouvelles. L’absence de lignes peut résulter de la politique de capture, de la rétention, de l’absence d’exécutions enregistrées ou d’un historique indisponible, sans signifier une consommation nulle. Seules les exécutions normales terminées avec succès sont incluses (execution_type = 0) ; les exécutions annulées et en échec sont exclues. Comparer des périodes et des charges équivalentes pour étudier les régressions.

Applicable à Azure SQL Database, Azure SQL Managed Instance et SQL Server 2016 ou ultérieur. Nécessite VIEW DATABASE STATE ou, si disponible, VIEW DATABASE PERFORMANCE STATE (SQL Server 2022 et ultérieurs). OBJECT_ID peut renvoyer NULL si la procédure SQL est absente ou si ses métadonnées ne sont pas visibles. Ne modifie pas la configuration de la base.

[sys.query_store_runtime_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql), [sys.query_store_runtime_stats_interval](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-interval-transact-sql).

<a id="query-9"></a>

- [Mémoire, blocages et attentes d’une procédure stockée](Azure-SQL/fr/MoniteurActifProcedureStockee.sql)<br>
  Capture en lecture seule des requêtes actives visibles attribuables à une procédure SQL de la base actuelle via leurs handles SQL ou de plan. Affiche la durée et le temps processeur en millisecondes, les lectures logiques, les écritures, l’attente et la ressource actuelles, l’identifiant de session bloquante, les allocations mémoire de requête en Ko, l’hôte et l’application cliente et l’instruction actuelle. Les allocations concernent l’espace de travail d’exécution, pas toute la mémoire de la procédure.

Remplacer @Schema et @Procedure. SQL Server 2019 et antérieurs et Azure SQL Managed Instance nécessitent VIEW SERVER STATE pour consulter les autres sessions ; SQL Server 2022 et ultérieurs nécessitent VIEW SERVER PERFORMANCE STATE. Azure SQL Database applique des autorisations et restrictions de visibilité propres à chaque DMV : Microsoft indique que sys.dm_exec_requests se limite à la connexion actuelle, tandis que les allocations mémoire nécessitent VIEW DATABASE STATE. Ne pas supposer que cette requête permet de surveiller les autres connexions dans Azure SQL Database. OBJECT_ID peut renvoyer NULL si la procédure SQL est absente ou si ses métadonnées ne sont pas visibles.

Il s’agit d’une capture ponctuelle, pas d’un historique atomique. Les requêtes terminées avant la capture sont absentes. Les appels imbriqués et le SQL dynamique peuvent ne pas être attribuables via ces handles. Des champs mémoire NULL indiquent l’absence d’allocation visible correspondante, pas une mémoire totale nulle ; MemoryGrantTime peut être NULL pendant l’attente. CurrentStatement peut être NULL lorsque le texte ou les offsets sont indisponibles, notamment pour du texte chiffré. Les attentes par requête ne décrivent pas toutes les tâches parallèles et les compteurs du coordinateur en parallélisme en mode ligne peuvent omettre lectures et écritures. Un blocking_session_id positif identifie une session bloquante ; les valeurs négatives ont des significations particulières et 0/NULL peut indiquer l’absence de bloqueur ou un bloqueur non identifié.

Pour les problèmes intermittents, utiliser Query Store pour les performances historiques, les Extended Events compatibles pour les événements détaillés ou un échantillonnage périodique autorisé séparément. Ce script ne lance aucune capture, ne programme aucun sondage, ne modifie aucune configuration et ne termine aucune session.

[sys.dm_exec_requests](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql), [sys.dm_exec_query_memory_grants](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-memory-grants-transact-sql), [sys.dm_exec_sql_text](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sql-text-transact-sql).

<a id="query-10"></a>

- [Examen de la maintenance des index et statistiques associés](Azure-SQL/fr/ExamenIndexStatistiquesAssocies.sql)<br>
  Évaluation en lecture seule des statistiques des tables directement référencées par une procédure SQL via les dépendances statiques enregistrées dans la base actuelle. Affiche les index associés, les définitions des statistiques filtrées, la dernière mise à jour, les lignes lors de cette mise à jour, les lignes échantillonnées, les compteurs de modifications et un pourcentage indicatif. Inclut les statistiques indépendantes des index et évite les analyses physiques des index. Ne mesure pas la fragmentation et ne réalise aucune maintenance.

Remplacer @Schema et @Procedure dans la base cible. Les dépendances nécessitent VIEW DEFINITION sur la base et SELECT sur sys.sql_expression_dependencies. Les propriétés statistiques nécessitent SELECT sur leurs colonnes, la propriété de la table ou un rôle administratif applicable selon la documentation. La visibilité des métadonnées peut limiter les résultats ; OBJECT_ID peut renvoyer NULL si la procédure SQL est absente ou invisible. Les propriétés indisponibles sont distinguées des dates absentes ; une date NULL peut concerner une table vide ou des statistiques filtrées sans lignes correspondantes.

Le signal de révision utilise plus de 1 000 lignes lors de la dernière mise à jour et plus de 20 % de modifications. Il s’agit d’une heuristique, pas du seuil de mise à jour automatique ni d’une instruction de maintenance. La rapprocher des erreurs d’estimation, changements de plan et dégradations observées. ModificationPct utilise les lignes de la dernière mise à jour, pas la taille actuelle ; il peut dépasser 100 % et vaut NULL si le dénominateur est nul ou indisponible. Le compteur suit normalement les changements de la première colonne de l’histogramme ; pour les tables optimisées en mémoire, il suit les changements de la table depuis la dernière mise à jour ou le redémarrage de la base. Les statistiques filtrées ne couvrent que les lignes satisfaisant le filtre.

Seules les dépendances directes et résolues vers des tables locales sont incluses. Le SQL dynamique, les dépendances via vues, synonymes, fonctions ou procédures imbriquées et les références entre bases ne sont pas parcourus. Aucune ligne ne prouve pas l’absence de tables utilisées ou de besoin de maintenance. Ces statistiques de tables ne prouvent pas que la procédure utilise chaque statistique ou index associé. Les statistiques incrémentales sont présentées globalement, pas par partition. Applicable à Azure SQL Database, Azure SQL Managed Instance et SQL Server 2016 ou ultérieur.

[sys.sql_expression_dependencies](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-expression-dependencies-transact-sql), [sys.stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-stats-transact-sql), [sys.dm_db_stats_properties](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-stats-properties-transact-sql).

<a id="query-11"></a>

- [Saturation des ressources Azure SQL](Azure-SQL/fr/SaturationRessourcesAzureSQL.sql)<br>
  Moniteur de ressources en lecture seule sélectionné selon le moteur. Dans Azure SQL Database, renvoie les 100 derniers intervalles de la base : utilisation moyenne du processeur, de la mémoire, des E/S de données et des écritures du journal, maximums de workers et de sessions et état indicatif. Dans Azure SQL Managed Instance, recommande sys.server_resource_stats au lieu d’interroger une DMV de base non compatible. Les autres moteurs reçoivent un message informatif.

Exécuter dans la base Azure SQL cible avec VIEW DATABASE STATE. sys.dm_db_resource_stats enregistre des intervalles de 15 secondes et conserve environ une heure ; TOP (100) couvre environ 25 minutes si tous les intervalles sont disponibles. CaptureTimeUTC correspond à la fin de l’intervalle, pas à l’exécution du script. Un basculement peut réduire l’historique disponible. Les pourcentages sont relatifs aux limites de service applicables ; pour une base dans un Elastic Pool, ils concernent sa limite configurée, pas l’utilisation globale du pool.

CRITIQUE signifie que le processeur, les E/S de données, les écritures du journal ou le maximum de workers ont atteint au moins 90 % ; AVERTISSEMENT indique qu’une de ces mesures a atteint au moins 75 % ; NORMAL signifie qu’aucune n’a atteint 75 %. Ces seuils sont indicatifs, pas une preuve de saturation ni un diagnostic de santé Azure. La mémoire et les sessions sont affichées sans influer sur ResourceStatus. Une mémoire élevée peut simplement refléter le cache. Corréler la pression durable avec les exécutions de la procédure, Query Store et la latence observée avant d’attribuer une responsabilité.

La branche Managed Instance recommande seulement le moniteur d’instance sans l’interroger. sys.server_resource_stats fournit des lignes de 15 secondes, actualisées avec un délai, et environ 14 jours d’historique. Ce script ne configure aucune alerte, ne programme aucune surveillance et ne modifie aucune ressource. Les noms des colonnes de sortie restent en anglais dans toutes les versions.

[sys.dm_db_resource_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-resource-stats-azure-sql-database), [sys.server_resource_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-resource-stats-azure-sql-database).

<a id="query-12"></a>

- [Audit des autorisations explicites de la procédure](Azure-SQL/fr/AuditAutorisationsProcedure.sql)<br>
  Audit en lecture seule des autorisations explicites visibles au niveau objet d’une procédure SQL et de son contexte d’exécution déclaré. Affiche le schéma et la procédure, l’identifiant et le nom résolu du principal EXECUTE AS, le propriétaire actuel de l’objet, le bénéficiaire et son type, le principal ayant accordé l’autorisation, l’autorisation et son état. Le bénéficiaire peut être un utilisateur, un rôle ou un autre principal de base ; les appartenances ne sont pas développées.

Exécuter dans la base cible et remplacer @Schema et @Procedure. APPELANT laisse ExecuteAsPrincipal à NULL car l’appelant dépend de chaque invocation. PROPRIETAIRE résout le propriétaire actuel de l’objet, ou celui du schéma en l’absence de propriétaire explicite. Un identifiant stocké peut correspondre à EXECUTE AS SELF ou à un utilisateur nommé explicitement ; il ne suffit pas à distinguer la déclaration d’origine. Les noms de colonnes et les descriptions des autorisations et types fournies par le catalogue restent en anglais.

La visibilité des métadonnées s’applique : les résultats peuvent être incomplets si le compte d’audit ne peut pas voir l’objet, le module, les autorisations et les principaux concernés. Utiliser un compte autorisé disposant d’une visibilité suffisante, par exemple le propriétaire de la base, pour un examen complet au niveau objet. OBJECT_ID peut renvoyer NULL si la procédure SQL est absente ou invisible. Une ligne avec des colonnes d’autorisation NULL signifie qu’aucune autorisation explicite n’est visible, pas que personne ne peut exécuter la procédure. Un nom de principal résolu NULL peut indiquer des métadonnées indisponibles.

Ne calcule pas les autorisations effectives issues des appartenances aux rôles, y compris les rôles fixes, de la propriété, des autorisations de schéma, base ou serveur, des chaînes de propriété, des signatures de modules ou d’autres contextes d’exécution. Ne prouve ni n’exclut une injection SQL : cela nécessite l’analyse du code et du traitement des entrées. N’accorde, ne refuse ni ne révoque aucune autorisation et n’usurpe aucun utilisateur. Applicable à Azure SQL Database, Azure SQL Managed Instance et SQL Server 2016 ou ultérieur.

[sys.sql_modules](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql), [sys.database_permissions](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql), [EXECUTE AS](https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql).

## Agent DBA

[Prompt système de l’agent DBA](Azure-SQL/Agents/fr/AgentDBAProcedureStockee.md)

Prompt en français pour créer Azure SQL Stored Procedure Deep Analyzer, un agent expert en diagnostic, optimisation, sécurité, maintenance et surveillance des procédures stockées. Copier le contenu complet du fichier dans les instructions système de l’agent. L’agent ne dispose pas de connexion directe à la base : un DBA humain exécute les requêtes de diagnostic et partage les résultats.

Lorsqu’un fichier de procédure est fourni au démarrage, l’agent le lit et présente une évaluation statique préliminaire avant la découverte de l’environnement et les tests diagnostiques ciblés.

Langues disponibles: [English](Azure-SQL/Agents/StoredProcedureDBAAgent.md) · [Español](Azure-SQL/Agents/es/AgenteDBAStoredProcedure.md) · [Français](Azure-SQL/Agents/fr/AgentDBAProcedureStockee.md)

[Profils spécifiques pour GitHub Copilot, Codex et Claude Code, avec instructions d’installation en trois langues](Azure-SQL/Agents/Integrations/README.fr.md).

## Sources

Documentation officielle Microsoft Learn utilisée pour vérifier les requêtes, les mesures, les autorisations et les limites.

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
