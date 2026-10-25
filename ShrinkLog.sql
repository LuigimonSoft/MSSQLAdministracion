USE [ExampleDatabase];
GO
-- Set the recovery model to SIMPLE.
ALTER DATABASE ExampleDatabase
SET RECOVERY SIMPLE;
GO
-- Shrink the log file to 1 MB.
DBCC SHRINKFILE (ExampleDatabase_Log, 1);
GO
-- Restore the recovery model to FULL.
ALTER DATABASE ExampleDatabase
SET RECOVERY FULL;
GO
