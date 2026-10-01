/* =====================================================================
   Actividad 4 - Proceso B: evidencias después de ejecutar
   PB_Relacional_DW.dtsx

   1. Filas por tabla del DW
   2. Cuadre de la tabla de hechos contra el modelo relacional
   3. El grano se cumple (no hay persona + fecha repetida)
   4. Muestra de la tabla de hechos con sus dimensiones
   ===================================================================== */
USE PersonasDW;
GO

/* ---------- 1. Filas por tabla ---------- */
SELECT 'DimTiempo'           AS tabla, COUNT(*) AS filas FROM dbo.DimTiempo
UNION ALL SELECT 'DimUbicacion',        COUNT(*) FROM dbo.DimUbicacion
UNION ALL SELECT 'DimEducacion',        COUNT(*) FROM dbo.DimEducacion
UNION ALL SELECT 'DimSituacionLaboral', COUNT(*) FROM dbo.DimSituacionLaboral
UNION ALL SELECT 'DimPersona',          COUNT(*) FROM dbo.DimPersona
UNION ALL SELECT 'FactObservacion',     COUNT(*) FROM dbo.FactObservacion;
GO

/* ---------- 2. Cuadre DW vs relacional ----------
   Cada fila compara el mismo indicador en las dos bases.            */
WITH dw AS (
    SELECT SUM(f.CantidadObservaciones)  AS observaciones,
           COUNT(DISTINCT f.PersonaKey)  AS personas,
           COUNT(DISTINCT f.UbicacionKey) AS municipios,
           COUNT(DISTINCT t.Anio * 100 + t.Mes) AS meses,
           SUM(f.IngresoMensual)         AS ingreso_total,
           SUM(f.GastoMensual)           AS gasto_total,
           SUM(f.BalanceMensual)         AS balance_total
    FROM dbo.FactObservacion f
    JOIN dbo.DimTiempo t ON t.TiempoKey = f.TiempoKey
), rel AS (
    SELECT COUNT(*)                          AS observaciones,
           COUNT(DISTINCT o.PersonaId)       AS personas,
           COUNT(DISTINCT o.MunicipioCodigo) AS municipios,
           COUNT(DISTINCT YEAR(o.FechaEncuesta) * 100 + MONTH(o.FechaEncuesta)) AS meses,
           SUM(o.IngresoMensual)             AS ingreso_total,
           SUM(o.GastoMensual)               AS gasto_total,
           SUM(o.BalanceMensual)             AS balance_total
    FROM PersonasETL.dbo.Observacion o
)
SELECT v.indicador, v.dw, v.relacional,
       CASE WHEN v.dw = v.relacional THEN 'SI' ELSE 'NO' END AS coincide
FROM dw CROSS JOIN rel
CROSS APPLY (VALUES
    ('Observaciones',            CAST(dw.observaciones AS DECIMAL(38,2)), CAST(rel.observaciones AS DECIMAL(38,2))),
    ('Personas distintas',       dw.personas,      rel.personas),
    ('Municipios con datos',     dw.municipios,    rel.municipios),
    ('Meses con encuestas',      dw.meses,         rel.meses),
    ('Suma ingreso mensual',     dw.ingreso_total, rel.ingreso_total),
    ('Suma gasto mensual',       dw.gasto_total,   rel.gasto_total),
    ('Suma balance mensual',     dw.balance_total, rel.balance_total)
) v (indicador, dw, relacional);
GO

/* ---------- 3. El grano se cumple: 0 filas = no hay repetidos ---------- */
SELECT PersonaKey, TiempoKey, COUNT(*) AS veces
FROM dbo.FactObservacion
GROUP BY PersonaKey, TiempoKey
HAVING COUNT(*) > 1;
GO

/* ---------- 4. Muestra de hechos con sus dimensiones ---------- */
SELECT TOP (10)
       p.TipoDocumento, p.NumeroDocumento, p.NombreCompleto,
       t.Fecha AS fecha_encuesta, u.Municipio, u.Departamento,
       e.NivelEducativo, s.SituacionLaboral,
       f.IngresoMensual, f.GastoMensual, f.BalanceMensual, f.CantidadObservaciones
FROM dbo.FactObservacion f
JOIN dbo.DimPersona          p ON p.PersonaKey          = f.PersonaKey
JOIN dbo.DimTiempo           t ON t.TiempoKey           = f.TiempoKey
JOIN dbo.DimUbicacion        u ON u.UbicacionKey        = f.UbicacionKey
JOIN dbo.DimEducacion        e ON e.EducacionKey        = f.EducacionKey
JOIN dbo.DimSituacionLaboral s ON s.SituacionLaboralKey = f.SituacionLaboralKey
ORDER BY f.FactObservacionId;
GO
