/*
Examen de la maintenance des index et statistiques associés

Évaluation en lecture seule des statistiques des tables directement référencées par une procédure SQL via les dépendances statiques enregistrées dans la base actuelle. Affiche les index associés, les définitions des statistiques filtrées, la dernière mise à jour, les lignes lors de cette mise à jour, les lignes échantillonnées, les compteurs de modifications et un pourcentage indicatif. Inclut les statistiques indépendantes des index et évite les analyses physiques des index. Ne mesure pas la fragmentation et ne réalise aucune maintenance.

Remplacer @Schema et @Procedure dans la base cible. Les dépendances nécessitent VIEW DEFINITION sur la base et SELECT sur sys.sql_expression_dependencies. Les propriétés statistiques nécessitent SELECT sur leurs colonnes, la propriété de la table ou un rôle administratif applicable selon la documentation. La visibilité des métadonnées peut limiter les résultats ; OBJECT_ID peut renvoyer NULL si la procédure SQL est absente ou invisible. Les propriétés indisponibles sont distinguées des dates absentes ; une date NULL peut concerner une table vide ou des statistiques filtrées sans lignes correspondantes.

Le signal de révision utilise plus de 1 000 lignes lors de la dernière mise à jour et plus de 20 % de modifications. Il s’agit d’une heuristique, pas du seuil de mise à jour automatique ni d’une instruction de maintenance. La rapprocher des erreurs d’estimation, changements de plan et dégradations observées. ModificationPct utilise les lignes de la dernière mise à jour, pas la taille actuelle ; il peut dépasser 100 % et vaut NULL si le dénominateur est nul ou indisponible. Le compteur suit normalement les changements de la première colonne de l’histogramme ; pour les tables optimisées en mémoire, il suit les changements de la table depuis la dernière mise à jour ou le redémarrage de la base. Les statistiques filtrées ne couvrent que les lignes satisfaisant le filtre.

Seules les dépendances directes et résolues vers des tables locales sont incluses. Le SQL dynamique, les dépendances via vues, synonymes, fonctions ou procédures imbriquées et les références entre bases ne sont pas parcourus. Aucune ligne ne prouve pas l’absence de tables utilisées ou de besoin de maintenance. Ces statistiques de tables ne prouvent pas que la procédure utilise chaque statistique ou index associé. Les statistiques incrémentales sont présentées globalement, pas par partition. Applicable à Azure SQL Database, Azure SQL Managed Instance et SQL Server 2016 ou ultérieur.

https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-expression-dependencies-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-stats-transact-sql
https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-stats-properties-transact-sql
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
    -- Cette heuristique est un signal de révision, pas une règle de maintenance automatique.
    CASE
        WHEN sp.object_id IS NULL
            THEN N'PROPRIÉTÉS STATISTIQUES INDISPONIBLES'
        WHEN sp.last_updated IS NULL
            THEN N'AUCUNE DATE DE MISE À JOUR DISPONIBLE'
        WHEN sp.rows > 1000
         AND sp.modification_counter > sp.rows * 0.20
            THEN N'EXAMINER LES STATISTIQUES'
        ELSE N'ÉVALUER AVEC LE PLAN D’EXÉCUTION'
    END AS ReviewStatus
FROM TablesUsed AS t
INNER JOIN sys.stats AS s ON t.TableObjectId = s.object_id
LEFT JOIN sys.indexes AS i
    ON s.object_id = i.object_id
   AND s.stats_id = i.index_id
OUTER APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
ORDER BY ModificationPct DESC, SchemaName, TableName, StatisticsName;
