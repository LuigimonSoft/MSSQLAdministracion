USE [BaseExemple];
GO
-- Passer le mode de récupération à SIMPLE.
ALTER DATABASE BaseExemple
SET RECOVERY SIMPLE;
GO
-- Réduire le fichier journal à 1 Mo.
DBCC SHRINKFILE (BaseExemple_Journal, 1);
GO
-- Rétablir le mode de récupération FULL.
ALTER DATABASE BaseExemple
SET RECOVERY FULL;
GO
