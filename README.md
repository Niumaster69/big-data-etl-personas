# Actividad 4 - Extracción, transformación y limpieza de datos

Big Data - REA 1. Integrantes: Duvan Lozano Romero, Wilder Stiven Ortiz Henao, David Estiven Sánchez Yomayuza.

## Contenido

- `sql/` scripts de SQL Server
  - `01_crear_bd.sql` base de datos PersonasETL y esquemas
  - `02_cursor_tablas.sql`, `03_cursor_etl.sql` ejercicio con cursores (SourceRowId 1 a 100)
  - `04_mer_ddl.sql` modelo relacional, catálogos y tablas de bitácora
  - `05_diagnostico_inicial.sql` diagnóstico de calidad del Excel
  - `06_evidencias_paquete_A.sql` verificación de la carga al modelo relacional
- `ssis/ETL_Personas/` proyecto de Integration Services (abrir `ETL_Personas.sln`)
  - `P0_Staging_Cursor.dtsx` carga el staging del cursor
  - `PA_Excel_Relacional.dtsx` proceso A: Excel a modelo relacional

## Orden de ejecución

1. `01_crear_bd.sql`, `02_cursor_tablas.sql`, `04_mer_ddl.sql`
2. Paquete `P0_Staging_Cursor` y luego `03_cursor_etl.sql`
3. Paquete `PA_Excel_Relacional`, luego `05_diagnostico_inicial.sql` y `06_evidencias_paquete_A.sql`

El Excel se lee desde `C:\ETL_Actividad4\PersonasETLActividad4.xlsx` (variable `RutaExcel` de los paquetes).
Requiere SQL Server 2025, Visual Studio 2022 con SSIS Projects y Microsoft Access Database Engine (ACE 16, 64 bits).
