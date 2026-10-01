/* =====================================================================
   Actividad 4 - Proceso B: consultas sobre el DW y verificación
   contra el modelo relacional

   Para cada consulta hay tres bloques:
     a) La consulta sobre el modelo en estrella (el resultado del informe)
     b) Comparación lado a lado DW vs relacional (columna "coincide")
     c) EXCEPT en los dos sentidos: 0 y 0 = los resultados son iguales

   Consultas
     1. Personas distintas por municipio
     2. Ingreso promedio por nivel educativo
     3. Balance promedio por situación laboral
     4. Cantidad de observaciones por año y mes
   ===================================================================== */
USE PersonasDW;
GO

/* =====================================================================
   CONSULTA 1: personas distintas por municipio
   ===================================================================== */
-- a) DW
SELECT u.Departamento, u.Municipio,
       COUNT(DISTINCT f.PersonaKey) AS personas_distintas
FROM dbo.FactObservacion f
JOIN dbo.DimUbicacion u ON u.UbicacionKey = f.UbicacionKey
GROUP BY u.Departamento, u.Municipio
ORDER BY personas_distintas DESC, u.Municipio;

-- b) DW vs relacional
WITH dw AS (
    SELECT u.MunicipioCodigo, u.Municipio, COUNT(DISTINCT f.PersonaKey) AS valor
    FROM dbo.FactObservacion f
    JOIN dbo.DimUbicacion u ON u.UbicacionKey = f.UbicacionKey
    GROUP BY u.MunicipioCodigo, u.Municipio
), rel AS (
    SELECT m.MunicipioCodigo, m.Nombre AS Municipio, COUNT(DISTINCT o.PersonaId) AS valor
    FROM PersonasETL.dbo.Observacion o
    JOIN PersonasETL.dbo.Municipio m ON m.MunicipioCodigo = o.MunicipioCodigo
    GROUP BY m.MunicipioCodigo, m.Nombre
)
SELECT COALESCE(dw.Municipio, rel.Municipio) AS municipio,
       dw.valor AS personas_dw, rel.valor AS personas_relacional,
       CASE WHEN dw.valor = rel.valor THEN 'SI' ELSE 'NO' END AS coincide
FROM dw FULL OUTER JOIN rel ON rel.MunicipioCodigo = dw.MunicipioCodigo
ORDER BY municipio;

-- c) EXCEPT en los dos sentidos
WITH dw AS (
    SELECT u.MunicipioCodigo, COUNT(DISTINCT f.PersonaKey) AS valor
    FROM dbo.FactObservacion f
    JOIN dbo.DimUbicacion u ON u.UbicacionKey = f.UbicacionKey
    GROUP BY u.MunicipioCodigo
), rel AS (
    SELECT o.MunicipioCodigo, COUNT(DISTINCT o.PersonaId) AS valor
    FROM PersonasETL.dbo.Observacion o
    GROUP BY o.MunicipioCodigo
)
SELECT 'Consulta 1' AS consulta,
       (SELECT COUNT(*) FROM (SELECT * FROM dw EXCEPT SELECT * FROM rel) x) AS filas_dw_no_en_relacional,
       (SELECT COUNT(*) FROM (SELECT * FROM rel EXCEPT SELECT * FROM dw) x) AS filas_relacional_no_en_dw;
GO

/* =====================================================================
   CONSULTA 2: ingreso promedio por nivel educativo
   ===================================================================== */
-- a) DW
SELECT e.NivelEducativo,
       SUM(f.CantidadObservaciones)                   AS observaciones,
       CAST(AVG(f.IngresoMensual) AS DECIMAL(18,2))   AS ingreso_promedio
FROM dbo.FactObservacion f
JOIN dbo.DimEducacion e ON e.EducacionKey = f.EducacionKey
GROUP BY e.NivelEducativo, e.Orden
ORDER BY e.Orden;

-- b) DW vs relacional (se compara el promedio con todos sus decimales)
WITH dw AS (
    SELECT e.NivelEducativoCodigo, e.NivelEducativo, e.Orden, AVG(f.IngresoMensual) AS valor
    FROM dbo.FactObservacion f
    JOIN dbo.DimEducacion e ON e.EducacionKey = f.EducacionKey
    GROUP BY e.NivelEducativoCodigo, e.NivelEducativo, e.Orden
), rel AS (
    SELECT n.NivelEducativoCodigo, n.Nombre AS NivelEducativo, n.Orden, AVG(o.IngresoMensual) AS valor
    FROM PersonasETL.dbo.Observacion o
    JOIN PersonasETL.dbo.NivelEducativo n ON n.NivelEducativoCodigo = o.NivelEducativoCodigo
    GROUP BY n.NivelEducativoCodigo, n.Nombre, n.Orden
)
SELECT COALESCE(dw.NivelEducativo, rel.NivelEducativo) AS nivel_educativo,
       CAST(dw.valor  AS DECIMAL(18,2)) AS ingreso_promedio_dw,
       CAST(rel.valor AS DECIMAL(18,2)) AS ingreso_promedio_relacional,
       CASE WHEN dw.valor = rel.valor THEN 'SI' ELSE 'NO' END AS coincide
FROM dw FULL OUTER JOIN rel ON rel.NivelEducativoCodigo = dw.NivelEducativoCodigo
ORDER BY COALESCE(dw.Orden, rel.Orden);

-- c) EXCEPT en los dos sentidos
WITH dw AS (
    SELECT e.NivelEducativoCodigo, AVG(f.IngresoMensual) AS valor
    FROM dbo.FactObservacion f
    JOIN dbo.DimEducacion e ON e.EducacionKey = f.EducacionKey
    GROUP BY e.NivelEducativoCodigo
), rel AS (
    SELECT o.NivelEducativoCodigo, AVG(o.IngresoMensual) AS valor
    FROM PersonasETL.dbo.Observacion o
    GROUP BY o.NivelEducativoCodigo
)
SELECT 'Consulta 2' AS consulta,
       (SELECT COUNT(*) FROM (SELECT * FROM dw EXCEPT SELECT * FROM rel) x) AS filas_dw_no_en_relacional,
       (SELECT COUNT(*) FROM (SELECT * FROM rel EXCEPT SELECT * FROM dw) x) AS filas_relacional_no_en_dw;
GO

/* =====================================================================
   CONSULTA 3: balance promedio por situación laboral
   ===================================================================== */
-- a) DW
SELECT s.SituacionLaboral,
       SUM(f.CantidadObservaciones)                   AS observaciones,
       CAST(AVG(f.BalanceMensual) AS DECIMAL(19,2))   AS balance_promedio
FROM dbo.FactObservacion f
JOIN dbo.DimSituacionLaboral s ON s.SituacionLaboralKey = f.SituacionLaboralKey
GROUP BY s.SituacionLaboral
ORDER BY balance_promedio DESC;

-- b) DW vs relacional
WITH dw AS (
    SELECT s.SituacionLaboralCodigo, s.SituacionLaboral, AVG(f.BalanceMensual) AS valor
    FROM dbo.FactObservacion f
    JOIN dbo.DimSituacionLaboral s ON s.SituacionLaboralKey = f.SituacionLaboralKey
    GROUP BY s.SituacionLaboralCodigo, s.SituacionLaboral
), rel AS (
    SELECT sl.SituacionLaboralCodigo, sl.Nombre AS SituacionLaboral, AVG(o.BalanceMensual) AS valor
    FROM PersonasETL.dbo.Observacion o
    JOIN PersonasETL.dbo.SituacionLaboral sl ON sl.SituacionLaboralCodigo = o.SituacionLaboralCodigo
    GROUP BY sl.SituacionLaboralCodigo, sl.Nombre
)
SELECT COALESCE(dw.SituacionLaboral, rel.SituacionLaboral) AS situacion_laboral,
       CAST(dw.valor  AS DECIMAL(19,2)) AS balance_promedio_dw,
       CAST(rel.valor AS DECIMAL(19,2)) AS balance_promedio_relacional,
       CASE WHEN dw.valor = rel.valor THEN 'SI' ELSE 'NO' END AS coincide
FROM dw FULL OUTER JOIN rel ON rel.SituacionLaboralCodigo = dw.SituacionLaboralCodigo
ORDER BY situacion_laboral;

-- c) EXCEPT en los dos sentidos
WITH dw AS (
    SELECT s.SituacionLaboralCodigo, AVG(f.BalanceMensual) AS valor
    FROM dbo.FactObservacion f
    JOIN dbo.DimSituacionLaboral s ON s.SituacionLaboralKey = f.SituacionLaboralKey
    GROUP BY s.SituacionLaboralCodigo
), rel AS (
    SELECT o.SituacionLaboralCodigo, AVG(o.BalanceMensual) AS valor
    FROM PersonasETL.dbo.Observacion o
    GROUP BY o.SituacionLaboralCodigo
)
SELECT 'Consulta 3' AS consulta,
       (SELECT COUNT(*) FROM (SELECT * FROM dw EXCEPT SELECT * FROM rel) x) AS filas_dw_no_en_relacional,
       (SELECT COUNT(*) FROM (SELECT * FROM rel EXCEPT SELECT * FROM dw) x) AS filas_relacional_no_en_dw;
GO

/* =====================================================================
   CONSULTA 4: cantidad de observaciones por año y mes
   ===================================================================== */
-- a) DW
SELECT t.Anio, t.Mes, t.NombreMes,
       SUM(f.CantidadObservaciones) AS observaciones
FROM dbo.FactObservacion f
JOIN dbo.DimTiempo t ON t.TiempoKey = f.TiempoKey
GROUP BY t.Anio, t.Mes, t.NombreMes
ORDER BY t.Anio, t.Mes;

-- b) DW vs relacional
WITH dw AS (
    SELECT t.Anio, t.Mes, SUM(f.CantidadObservaciones) AS valor
    FROM dbo.FactObservacion f
    JOIN dbo.DimTiempo t ON t.TiempoKey = f.TiempoKey
    GROUP BY t.Anio, t.Mes
), rel AS (
    SELECT YEAR(o.FechaEncuesta) AS Anio, MONTH(o.FechaEncuesta) AS Mes, COUNT(*) AS valor
    FROM PersonasETL.dbo.Observacion o
    GROUP BY YEAR(o.FechaEncuesta), MONTH(o.FechaEncuesta)
)
SELECT COALESCE(dw.Anio, rel.Anio) AS anio, COALESCE(dw.Mes, rel.Mes) AS mes,
       dw.valor AS observaciones_dw, rel.valor AS observaciones_relacional,
       CASE WHEN dw.valor = rel.valor THEN 'SI' ELSE 'NO' END AS coincide
FROM dw FULL OUTER JOIN rel ON rel.Anio = dw.Anio AND rel.Mes = dw.Mes
ORDER BY anio, mes;

-- c) EXCEPT en los dos sentidos
WITH dw AS (
    SELECT t.Anio, t.Mes, SUM(f.CantidadObservaciones) AS valor
    FROM dbo.FactObservacion f
    JOIN dbo.DimTiempo t ON t.TiempoKey = f.TiempoKey
    GROUP BY t.Anio, t.Mes
), rel AS (
    SELECT YEAR(o.FechaEncuesta) AS Anio, MONTH(o.FechaEncuesta) AS Mes, COUNT(*) AS valor
    FROM PersonasETL.dbo.Observacion o
    GROUP BY YEAR(o.FechaEncuesta), MONTH(o.FechaEncuesta)
)
SELECT 'Consulta 4' AS consulta,
       (SELECT COUNT(*) FROM (SELECT * FROM dw EXCEPT SELECT * FROM rel) x) AS filas_dw_no_en_relacional,
       (SELECT COUNT(*) FROM (SELECT * FROM rel EXCEPT SELECT * FROM dw) x) AS filas_relacional_no_en_dw;
GO
