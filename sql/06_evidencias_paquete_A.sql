/* =====================================================================
   Actividad 4 - Proceso A: evidencias después de ejecutar
   PA_Excel_Relacional.dtsx

   1. Resumen de la ejecución y cuadre de cantidades
   2. Antes y después de la limpieza (correcciones)
   3. Rechazos y registros en revisión con su motivo
   4. Duplicados: qué versión se conservó y por qué
   5. Carga del modelo: filas por tabla e integridad referencial
   6. Segunda ejecución: no se generan duplicados
   ===================================================================== */
USE PersonasETL;
GO

/* ---------- 1. Resumen de cada ejecución ---------- */
SELECT EjecucionId, FechaInicio, FechaFin, FilasLeidas, FilasValidas, FilasRevision,
       FilasRechazadas, FilasDuplicadas, PersonasInsertadas, PersonasExistentes,
       ObservacionesInsertadas, ObservacionesExistentes
FROM etl.Ejecucion
ORDER BY EjecucionId;

-- Cuadre de la última ejecución:
--   leídas = válidas + revisión + rechazadas
--   válidas = cargadas (depuradas) + duplicados descartados
DECLARE @ult INT = (SELECT MAX(EjecucionId) FROM etl.Ejecucion);
SELECT e.FilasLeidas,
       e.FilasValidas + e.FilasRevision + e.FilasRechazadas AS validas_mas_revision_mas_rechazadas,
       e.FilasValidas,
       (SELECT COUNT(*) FROM stg.ObservacionDepurada) + e.FilasDuplicadas AS depuradas_mas_duplicados,
       (SELECT COUNT(*) FROM stg.ObservacionDepurada) AS observaciones_depuradas,
       (SELECT COUNT(*) FROM dbo.Observacion) AS observaciones_en_el_modelo
FROM etl.Ejecucion e
WHERE e.EjecucionId = @ult;

-- Clasificación final de las 1.000 filas del Excel
SELECT Clasificacion, COUNT(*) AS filas
FROM etl.RegistroNoCargado
WHERE EjecucionId = @ult
GROUP BY Clasificacion
UNION ALL
SELECT 'CARGADO', COUNT(*) FROM stg.ObservacionDepurada;
GO

/* ---------- 2. Antes y después (correcciones) ---------- */
DECLARE @ult INT = (SELECT MAX(EjecucionId) FROM etl.Ejecucion);

-- Cantidad de correcciones por campo
SELECT Campo, COUNT(*) AS filas_corregidas
FROM etl.Cambio
WHERE EjecucionId = @ult
GROUP BY Campo
ORDER BY filas_corregidas DESC;

-- Ejemplos de corrección: nombres, tipo de documento, importe, fecha dd/mm/aaaa, teléfono
SELECT c.SourceRowId, c.Campo, c.ValorOriginal, c.ValorNuevo
FROM etl.Cambio c
WHERE c.EjecucionId = @ult
  AND c.SourceRowId IN (1, 4, 7, 18, 22)
ORDER BY c.SourceRowId, c.Campo;

-- Filas 4 y 18 en el Excel (antes) y en el modelo (después)
-- (la fila 1 también se corrige, pero queda en revisión por la edad)
SELECT 'ANTES (Excel)' AS momento, e.SourceRowId, e.DocumentType AS tipo, e.DocumentNumber AS documento,
       e.FirstName AS nombre, e.LastName AS apellido, e.MonthlyIncome AS ingreso, e.MonthlyExpenses AS gasto,
       e.Phone AS telefono, e.MunicipalityName AS municipio
FROM stg.PersonasExcel e WHERE e.SourceRowId IN ('4', '18');

SELECT 'DESPUÉS (modelo)' AS momento, o.SourceRowId, p.TipoDocumentoCodigo AS tipo, p.NumeroDocumento AS documento,
       p.PrimerNombre AS nombre, p.PrimerApellido AS apellido, o.IngresoMensual AS ingreso, o.GastoMensual AS gasto,
       o.BalanceMensual AS balance, p.Telefono AS telefono, m.Nombre AS municipio
FROM dbo.Observacion o
JOIN dbo.Persona p   ON p.PersonaId = o.PersonaId
JOIN dbo.Municipio m ON m.MunicipioCodigo = o.MunicipioCodigo
WHERE o.SourceRowId IN (4, 18);

-- Importe con formato alterno: fila 18 ("$ 14.700.000,00")
SELECT e.SourceRowId, e.MonthlyIncome AS ingreso_excel, o.IngresoMensual AS ingreso_modelo
FROM stg.PersonasExcel e
JOIN dbo.Observacion o ON o.SourceRowId = TRY_CONVERT(INT, e.SourceRowId)
WHERE e.MonthlyIncome LIKE '$%' OR e.MonthlyExpenses LIKE '%,%'
ORDER BY o.SourceRowId;
GO

/* ---------- 3. Rechazos y revisión ---------- */
DECLARE @ult INT = (SELECT MAX(EjecucionId) FROM etl.Ejecucion);

-- Cantidad por motivo (un registro puede tener varios motivos)
SELECT r.Clasificacion, x.motivo, COUNT(*) AS registros
FROM etl.RegistroNoCargado r
CROSS APPLY STRING_SPLIT(r.Motivo, ';') m
CROSS APPLY (SELECT RTRIM(LTRIM(LEFT(m.value, CHARINDEX('(', m.value + '(') - 1))) AS motivo) x
WHERE r.EjecucionId = @ult AND r.Clasificacion IN ('RECHAZO', 'REVISION')
GROUP BY r.Clasificacion, x.motivo
ORDER BY r.Clasificacion, registros DESC;

-- Ejemplos de rechazo (fila 13: ingreso "dos millones") y de revisión
SELECT TOP (12) SourceRowId, Clasificacion, TipoDocumento, NumeroDocumento, FechaEncuesta, Motivo
FROM etl.RegistroNoCargado
WHERE EjecucionId = @ult AND Clasificacion IN ('RECHAZO', 'REVISION')
ORDER BY SourceRowId;

-- Ningún rechazado quedó en el modelo
SELECT COUNT(*) AS rechazados_en_el_modelo
FROM etl.RegistroNoCargado r
JOIN dbo.Observacion o ON o.SourceRowId = r.SourceRowId
WHERE r.EjecucionId = @ult AND r.Clasificacion IN ('RECHAZO', 'REVISION');
GO

/* ---------- 4. Duplicados ---------- */
DECLARE @ult INT = (SELECT MAX(EjecucionId) FROM etl.Ejecucion);

SELECT CASE WHEN Motivo LIKE '%mismo UpdatedAt%' THEN 'Copia idéntica (mismo UpdatedAt)'
            ELSE 'Versión diferente (UpdatedAt anterior)' END AS tipo_duplicado,
       COUNT(*) AS descartados
FROM etl.RegistroNoCargado
WHERE EjecucionId = @ult AND Clasificacion = 'DUPLICADO'
GROUP BY CASE WHEN Motivo LIKE '%mismo UpdatedAt%' THEN 'Copia idéntica (mismo UpdatedAt)'
              ELSE 'Versión diferente (UpdatedAt anterior)' END;

-- Ejemplo: SIM0000826, dos versiones con distinto ingreso. Se conserva la de UpdatedAt más reciente.
SELECT e.SourceRowId, e.DocumentType, e.DocumentNumber, e.SurveyDate, e.MonthlyIncome, e.UpdatedAt,
       CASE WHEN o.SourceRowId IS NOT NULL THEN 'CONSERVADO' ELSE 'DESCARTADO' END AS resultado,
       r.Motivo
FROM stg.PersonasExcel e
LEFT JOIN dbo.Observacion o ON o.SourceRowId = TRY_CONVERT(INT, e.SourceRowId)
LEFT JOIN etl.RegistroNoCargado r ON r.SourceRowId = TRY_CONVERT(INT, e.SourceRowId)
                                 AND r.EjecucionId = @ult AND r.Clasificacion = 'DUPLICADO'
WHERE e.DocumentNumber IN ('SIM0000826', 'SIM0000801')
ORDER BY e.DocumentNumber, TRY_CONVERT(INT, e.SourceRowId);

-- En el modelo no hay duplicados de persona ni de observación
SELECT (SELECT COUNT(*) FROM (SELECT TipoDocumentoCodigo, NumeroDocumento FROM dbo.Persona
                              GROUP BY TipoDocumentoCodigo, NumeroDocumento HAVING COUNT(*) > 1) x) AS personas_repetidas,
       (SELECT COUNT(*) FROM (SELECT PersonaId, FechaEncuesta FROM dbo.Observacion
                              GROUP BY PersonaId, FechaEncuesta HAVING COUNT(*) > 1) x) AS observaciones_repetidas;
GO

/* ---------- 5. Carga del modelo ---------- */
SELECT 'Persona' AS tabla, COUNT(*) AS filas FROM dbo.Persona
UNION ALL SELECT 'Observacion', COUNT(*) FROM dbo.Observacion
UNION ALL SELECT 'ObservacionLaboral', COUNT(*) FROM dbo.ObservacionLaboral
UNION ALL SELECT 'Empleador', COUNT(*) FROM dbo.Empleador
UNION ALL SELECT 'Municipio', COUNT(*) FROM dbo.Municipio
UNION ALL SELECT 'Departamento', COUNT(*) FROM dbo.Departamento
UNION ALL SELECT 'NivelEducativo', COUNT(*) FROM dbo.NivelEducativo
UNION ALL SELECT 'SituacionLaboral', COUNT(*) FROM dbo.SituacionLaboral;

-- Integridad: las FK están habilitadas y confiables (se validaron en la carga)
SELECT OBJECT_NAME(parent_object_id) AS tabla, name AS fk, is_disabled, is_not_trusted
FROM sys.foreign_keys
WHERE OBJECT_SCHEMA_NAME(parent_object_id) = 'dbo'
ORDER BY tabla, fk;

-- Observaciones por situación laboral y cuántas tienen datos laborales
SELECT o.SituacionLaboralCodigo, COUNT(*) AS observaciones, COUNT(l.ObservacionId) AS con_datos_laborales
FROM dbo.Observacion o
LEFT JOIN dbo.ObservacionLaboral l ON l.ObservacionId = o.ObservacionId
GROUP BY o.SituacionLaboralCodigo
ORDER BY observaciones DESC;
GO

/* ---------- 6. Segunda ejecución ----------
   Ejecutar este bloque, correr otra vez el paquete y volver a ejecutarlo:
   los conteos del modelo deben ser iguales y la nueva ejecución debe
   mostrar 0 personas y 0 observaciones insertadas. */
SELECT (SELECT COUNT(*) FROM dbo.Persona)            AS personas,
       (SELECT COUNT(*) FROM dbo.Observacion)        AS observaciones,
       (SELECT COUNT(*) FROM dbo.ObservacionLaboral) AS laborales,
       (SELECT COUNT(*) FROM dbo.Empleador)          AS empleadores;

SELECT TOP (2) EjecucionId, FechaInicio, PersonasInsertadas, PersonasExistentes,
       ObservacionesInsertadas, ObservacionesExistentes
FROM etl.Ejecucion
ORDER BY EjecucionId DESC;
GO
