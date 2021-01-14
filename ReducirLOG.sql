USE [BaseDatos];
GO
-- cambiamos el recovery a nodo simple
ALTER DATABASE BaseDatos
SET RECOVERY SIMPLE;
GO
-- reducirmos el archivo log a 1 MB.
DBCC SHRINKFILE (BaseDatos_Log, 1);
GO
-- devolvemos el nivel de recovery a full
ALTER DATABASE BaseDatos
SET RECOVERY FULL;
GO