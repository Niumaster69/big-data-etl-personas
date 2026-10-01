/* =====================================================================
   Actividad 4 - Segunda ejecución de los paquetes A y B
   Demostrar que volver a ejecutar no genera duplicados.

   Cómo usarlo (todo en la MISMA ventana de consulta de SSMS, porque la
   foto "antes" se guarda en una tabla temporal de la sesión):
     PASO 1. Ejecutar el bloque 1 (conteos ANTES).
     PASO 2. En Visual Studio ejecutar PA_Excel_Relacional.dtsx y después
             PB_Relacional_DW.dtsx.
     PASO 3. Ejecutar el bloque 2 (conteos DESPUÉS y diferencia).
     PASO 4. Ejecutar el bloque 3 (bitácora del paquete A y grano).

   Solo se cuentan las tablas del modelo (dbo). Las tablas etl.* crecen en
   cada ejecución a propósito (es la bitácora) y las stg.* se vacían y se
   vuelven a llenar, por eso no entran en la comparación.
   ===================================================================== */

/* =====================================================================
   BLOQUE 1: conteos ANTES de la segunda ejecución
   ===================================================================== */
DROP TABLE IF EXISTS #conteo_antes;

SELECT modelo, tabla, filas
INTO #conteo_antes
FROM (
              SELECT 'Relacional' AS modelo, 'Persona'            AS tabla, COUNT(*) AS filas FROM PersonasETL.dbo.Persona
    UNION ALL SELECT 'Relacional', 'Observacion',         COUNT(*) FROM PersonasETL.dbo.Observacion
    UNION ALL SELECT 'Relacional', 'ObservacionLaboral',  COUNT(*) FROM PersonasETL.dbo.ObservacionLaboral
    UNION ALL SELECT 'Relacional', 'Empleador',           COUNT(*) FROM PersonasETL.dbo.Empleador
    UNION ALL SELECT 'DW',         'DimTiempo',           COUNT(*) FROM PersonasDW.dbo.DimTiempo
    UNION ALL SELECT 'DW',         'DimUbicacion',        COUNT(*) FROM PersonasDW.dbo.DimUbicacion
    UNION ALL SELECT 'DW',         'DimEducacion',        COUNT(*) FROM PersonasDW.dbo.DimEducacion
    UNION ALL SELECT 'DW',         'DimSituacionLaboral', COUNT(*) FROM PersonasDW.dbo.DimSituacionLaboral
    UNION ALL SELECT 'DW',         'DimPersona',          COUNT(*) FROM PersonasDW.dbo.DimPersona
    UNION ALL SELECT 'DW',         'FactObservacion',     COUNT(*) FROM PersonasDW.dbo.FactObservacion
) c;

SELECT modelo, tabla, filas AS filas_antes, SYSDATETIME() AS momento
FROM #conteo_antes
ORDER BY modelo DESC, tabla;
GO

/* ---------------------------------------------------------------------
   >>> AHORA: ejecutar PA_Excel_Relacional y luego PB_Relacional_DW <<<
   --------------------------------------------------------------------- */

/* =====================================================================
   BLOQUE 2: conteos DESPUÉS y comparación
   ===================================================================== */
WITH despues AS (
              SELECT 'Relacional' AS modelo, 'Persona'            AS tabla, COUNT(*) AS filas FROM PersonasETL.dbo.Persona
    UNION ALL SELECT 'Relacional', 'Observacion',         COUNT(*) FROM PersonasETL.dbo.Observacion
    UNION ALL SELECT 'Relacional', 'ObservacionLaboral',  COUNT(*) FROM PersonasETL.dbo.ObservacionLaboral
    UNION ALL SELECT 'Relacional', 'Empleador',           COUNT(*) FROM PersonasETL.dbo.Empleador
    UNION ALL SELECT 'DW',         'DimTiempo',           COUNT(*) FROM PersonasDW.dbo.DimTiempo
    UNION ALL SELECT 'DW',         'DimUbicacion',        COUNT(*) FROM PersonasDW.dbo.DimUbicacion
    UNION ALL SELECT 'DW',         'DimEducacion',        COUNT(*) FROM PersonasDW.dbo.DimEducacion
    UNION ALL SELECT 'DW',         'DimSituacionLaboral', COUNT(*) FROM PersonasDW.dbo.DimSituacionLaboral
    UNION ALL SELECT 'DW',         'DimPersona',          COUNT(*) FROM PersonasDW.dbo.DimPersona
    UNION ALL SELECT 'DW',         'FactObservacion',     COUNT(*) FROM PersonasDW.dbo.FactObservacion
)
SELECT d.modelo, d.tabla,
       a.filas            AS filas_antes,
       d.filas            AS filas_despues,
       d.filas - a.filas  AS diferencia,
       CASE WHEN d.filas = a.filas THEN 'SIN DUPLICADOS' ELSE 'REVISAR' END AS resultado
FROM despues d
LEFT JOIN #conteo_antes a ON a.modelo = d.modelo AND a.tabla = d.tabla
ORDER BY d.modelo DESC, d.tabla;
GO

/* =====================================================================
   BLOQUE 3: bitácora del paquete A y verificación del grano
   ===================================================================== */
-- Las dos últimas ejecuciones del paquete A: en la segunda,
-- PersonasInsertadas = 0 y ObservacionesInsertadas = 0
SELECT TOP (2) EjecucionId, FechaInicio, FechaFin, FilasLeidas,
       PersonasInsertadas, PersonasExistentes,
       ObservacionesInsertadas, ObservacionesExistentes
FROM PersonasETL.etl.Ejecucion
ORDER BY EjecucionId DESC;

-- Grano en los dos modelos: 0 = ninguna persona tiene dos filas en la misma fecha
SELECT 'Relacional' AS modelo,
       (SELECT COUNT(*) FROM (SELECT PersonaId, FechaEncuesta FROM PersonasETL.dbo.Observacion
                              GROUP BY PersonaId, FechaEncuesta HAVING COUNT(*) > 1) x) AS grupos_repetidos
UNION ALL
SELECT 'DW',
       (SELECT COUNT(*) FROM (SELECT PersonaKey, TiempoKey FROM PersonasDW.dbo.FactObservacion
                              GROUP BY PersonaKey, TiempoKey HAVING COUNT(*) > 1) x);
GO
