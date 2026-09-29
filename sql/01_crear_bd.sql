/* =====================================================================
   Actividad 4 - ETL: extracción, transformación y limpieza de datos
   Script 01: base de datos y esquemas

   PersonasETL
     stg  -> tablas de staging (valores originales del Excel, todo texto)
     cur  -> ejercicio del cursor (punto 1)
     dbo  -> modelo relacional (MER) destino del paquete SSIS A
     etl  -> bitácora de ejecuciones, cambios, rechazos y duplicados
   ===================================================================== */
USE master;
GO
IF DB_ID(N'PersonasETL') IS NULL
    CREATE DATABASE PersonasETL COLLATE Modern_Spanish_CI_AS;
GO
USE PersonasETL;
GO
IF SCHEMA_ID(N'stg') IS NULL EXEC (N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'cur') IS NULL EXEC (N'CREATE SCHEMA cur');
IF SCHEMA_ID(N'etl') IS NULL EXEC (N'CREATE SCHEMA etl');
GO

-- Evidencia
SELECT DB_NAME() AS base_datos,
       DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS intercalacion,
       (SELECT STRING_AGG(name, ', ') FROM sys.schemas
         WHERE name IN (N'stg', N'cur', N'etl', N'dbo')) AS esquemas;
GO
