/* =====================================================================
   Actividad 4 - Proceso A: diagnóstico inicial de calidad
   Script 05: se ejecuta sobre stg.PersonasExcel, la copia sin tocar de
   las 1.000 filas del Excel que deja el paquete PA_Excel_Relacional
   (primer paso del flujo DFT 1).

   Revisa: valores faltantes, duplicados, formatos inconsistentes y
   datos inválidos. No modifica nada.
   ===================================================================== */
USE PersonasETL;
GO

/* ---------- 1. Filas leídas ---------- */
SELECT COUNT(*) AS filas_excel,
       MIN(TRY_CONVERT(INT, SourceRowId)) AS primer_id,
       MAX(TRY_CONVERT(INT, SourceRowId)) AS ultimo_id
FROM stg.PersonasExcel;

/* ---------- 2. Valores faltantes por columna ---------- */
SELECT columna, faltantes
FROM (
    SELECT
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(DocumentType)), '') IS NULL THEN 1 ELSE 0 END) AS DocumentType,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(DocumentNumber)), '') IS NULL
                  OR DocumentNumber = 'SIN-DATO' THEN 1 ELSE 0 END)                      AS DocumentNumber,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(FirstName)), '') IS NULL THEN 1 ELSE 0 END)     AS FirstName,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(MiddleName)), '') IS NULL THEN 1 ELSE 0 END)    AS MiddleName,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(LastName)), '') IS NULL THEN 1 ELSE 0 END)      AS LastName,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(SecondLastName)), '') IS NULL THEN 1 ELSE 0 END) AS SecondLastName,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(BirthDate)), '') IS NULL THEN 1 ELSE 0 END)     AS BirthDate,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Email)), '') IS NULL THEN 1 ELSE 0 END)         AS Email,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Phone)), '') IS NULL THEN 1 ELSE 0 END)         AS Phone,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(OccupationCode)), '') IS NULL THEN 1 ELSE 0 END) AS OccupationCode,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(EmployerName)), '') IS NULL THEN 1 ELSE 0 END)  AS EmployerName,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(EmploymentStartDate)), '') IS NULL THEN 1 ELSE 0 END) AS EmploymentStartDate,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(MonthlyIncome)), '') IS NULL THEN 1 ELSE 0 END) AS MonthlyIncome,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(MonthlyExpenses)), '') IS NULL THEN 1 ELSE 0 END) AS MonthlyExpenses,
        SUM(CASE WHEN HealthRegime IN ('NULL', 'sin dato', 'N/A') THEN 1 ELSE 0 END)     AS HealthRegime,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM(SurveyDate)), '') IS NULL THEN 1 ELSE 0 END)    AS SurveyDate
    FROM stg.PersonasExcel
) t
UNPIVOT (faltantes FOR columna IN (DocumentType, DocumentNumber, FirstName, MiddleName, LastName,
         SecondLastName, BirthDate, Email, Phone, OccupationCode, EmployerName, EmploymentStartDate,
         MonthlyIncome, MonthlyExpenses, HealthRegime, SurveyDate)) u
ORDER BY faltantes DESC;
-- Nota: MiddleName, SecondLastName y los datos laborales pueden faltar legítimamente.

/* ---------- 3. Duplicados ---------- */
-- 3.1 Clave de persona: tipo + número de documento
SELECT UPPER(DocumentType) AS tipo, DocumentNumber, COUNT(*) AS filas,
       STRING_AGG(SourceRowId, ', ') AS source_row_ids
FROM stg.PersonasExcel
WHERE DocumentNumber IS NOT NULL AND DocumentNumber <> 'SIN-DATO'
GROUP BY UPPER(DocumentType), DocumentNumber
HAVING COUNT(*) > 1
ORDER BY DocumentNumber;

-- 3.2 Clave de observación: persona + fecha de encuesta, y si las versiones son iguales o diferentes
SELECT COUNT(*) AS grupos_duplicados,
       SUM(filas) AS filas_involucradas,
       SUM(CASE WHEN versiones_distintas = 1 THEN 1 ELSE 0 END) AS copias_identicas,
       SUM(CASE WHEN versiones_distintas > 1 THEN 1 ELSE 0 END) AS versiones_diferentes
FROM (
    SELECT UPPER(DocumentType) AS tipo, DocumentNumber, SurveyDate, COUNT(*) AS filas,
           COUNT(DISTINCT CONCAT(MonthlyIncome, '|', MonthlyExpenses, '|', UpdatedAt, '|', Email, '|', Phone)) AS versiones_distintas
    FROM stg.PersonasExcel
    WHERE DocumentNumber IS NOT NULL AND DocumentNumber <> 'SIN-DATO'
    GROUP BY UPPER(DocumentType), DocumentNumber, SurveyDate
    HAVING COUNT(*) > 1
) d;

-- 3.3 Ejemplo de versiones diferentes (cambia el ingreso y UpdatedAt)
SELECT TOP (6) a.SourceRowId, a.DocumentType, a.DocumentNumber, a.SurveyDate,
       a.MonthlyIncome, a.UpdatedAt
FROM stg.PersonasExcel a
WHERE EXISTS (SELECT 1 FROM stg.PersonasExcel b
              WHERE b.DocumentNumber = a.DocumentNumber AND b.SurveyDate = a.SurveyDate
                AND b.SourceRowId <> a.SourceRowId AND b.UpdatedAt <> a.UpdatedAt)
ORDER BY a.DocumentNumber, TRY_CONVERT(INT, a.SourceRowId);

/* ---------- 4. Formatos inconsistentes ---------- */
-- 4.1 Mayúsculas/minúsculas en categorías (agrupando con distinción de mayúsculas)
SELECT 'DocumentType' AS columna, DocumentType COLLATE Latin1_General_CS_AS AS valor, COUNT(*) AS filas FROM stg.PersonasExcel GROUP BY DocumentType COLLATE Latin1_General_CS_AS
UNION ALL SELECT 'MaritalStatus', MaritalStatus COLLATE Latin1_General_CS_AS, COUNT(*) FROM stg.PersonasExcel GROUP BY MaritalStatus COLLATE Latin1_General_CS_AS
UNION ALL SELECT 'EducationLevel', EducationLevel COLLATE Latin1_General_CS_AS, COUNT(*) FROM stg.PersonasExcel GROUP BY EducationLevel COLLATE Latin1_General_CS_AS
UNION ALL SELECT 'Disability', Disability COLLATE Latin1_General_CS_AS, COUNT(*) FROM stg.PersonasExcel GROUP BY Disability COLLATE Latin1_General_CS_AS
UNION ALL SELECT 'HealthRegime', HealthRegime COLLATE Latin1_General_CS_AS, COUNT(*) FROM stg.PersonasExcel GROUP BY HealthRegime COLLATE Latin1_General_CS_AS
UNION ALL SELECT 'Sex', Sex COLLATE Latin1_General_CS_AS, COUNT(*) FROM stg.PersonasExcel GROUP BY Sex COLLATE Latin1_General_CS_AS
UNION ALL SELECT 'Zone', Zone COLLATE Latin1_General_CS_AS, COUNT(*) FROM stg.PersonasExcel GROUP BY Zone COLLATE Latin1_General_CS_AS
UNION ALL SELECT 'SourceChannel', SourceChannel COLLATE Latin1_General_CS_AS, COUNT(*) FROM stg.PersonasExcel GROUP BY SourceChannel COLLATE Latin1_General_CS_AS
UNION ALL SELECT 'SocioeconomicStratum', SocioeconomicStratum COLLATE Latin1_General_CS_AS, COUNT(*) FROM stg.PersonasExcel GROUP BY SocioeconomicStratum COLLATE Latin1_General_CS_AS
ORDER BY columna, filas DESC;

SELECT
    SUM(CASE WHEN FirstName COLLATE Latin1_General_CS_AS = LOWER(FirstName) AND FirstName <> '' THEN 1 ELSE 0 END) AS nombres_en_minuscula,
    SUM(CASE WHEN LastName  COLLATE Latin1_General_CS_AS = UPPER(LastName) THEN 1 ELSE 0 END)                    AS apellidos_en_mayuscula,
    SUM(CASE WHEN MunicipalityName COLLATE Latin1_General_CS_AS = LOWER(MunicipalityName) THEN 1 ELSE 0 END)     AS municipios_en_minuscula,
    SUM(CASE WHEN FirstName <> LTRIM(RTRIM(FirstName)) OR LastName <> LTRIM(RTRIM(LastName)) THEN 1 ELSE 0 END)  AS nombres_con_espacios
FROM stg.PersonasExcel;

-- 4.2 Formato de importes (9 = dígito)
SELECT 'MonthlyIncome' AS columna, formato, COUNT(*) AS filas, MIN(valor) AS ejemplo
FROM (SELECT MonthlyIncome AS valor,
             TRANSLATE(ISNULL(MonthlyIncome, 'NULL'), '0123456789', '9999999999') AS formato
      FROM stg.PersonasExcel) x
GROUP BY formato
UNION ALL
SELECT 'MonthlyExpenses', formato, COUNT(*), MIN(valor)
FROM (SELECT MonthlyExpenses AS valor,
             TRANSLATE(ISNULL(MonthlyExpenses, 'NULL'), '0123456789', '9999999999') AS formato
      FROM stg.PersonasExcel) x
GROUP BY formato
ORDER BY columna, filas DESC;

-- 4.3 Formato de fechas, documento y teléfono
SELECT 'BirthDate' AS columna, TRANSLATE(BirthDate, '0123456789', '9999999999') AS formato, COUNT(*) AS filas
FROM stg.PersonasExcel GROUP BY TRANSLATE(BirthDate, '0123456789', '9999999999')
UNION ALL
SELECT 'SurveyDate', TRANSLATE(SurveyDate, '0123456789', '9999999999'), COUNT(*)
FROM stg.PersonasExcel GROUP BY TRANSLATE(SurveyDate, '0123456789', '9999999999')
UNION ALL
SELECT 'DocumentNumber', TRANSLATE(ISNULL(DocumentNumber, 'NULL'), '0123456789', '9999999999'), COUNT(*)
FROM stg.PersonasExcel GROUP BY TRANSLATE(ISNULL(DocumentNumber, 'NULL'), '0123456789', '9999999999')
UNION ALL
SELECT 'Phone', TRANSLATE(Phone, '0123456789', '9999999999'), COUNT(*)
FROM stg.PersonasExcel GROUP BY TRANSLATE(Phone, '0123456789', '9999999999')
ORDER BY columna, filas DESC;

/* ---------- 5. Datos inválidos ---------- */
WITH d AS (
    SELECT *,
           CASE WHEN BirthDate LIKE '__/__/____'
                THEN TRY_CONVERT(DATE, BirthDate, 103) ELSE TRY_CONVERT(DATE, BirthDate, 23) END AS fnac,
           TRY_CONVERT(DATE, SurveyDate, 23) AS fenc
    FROM stg.PersonasExcel
)
SELECT regla, COUNT(*) AS filas
FROM d
CROSS APPLY (VALUES
    ('Fecha de nacimiento imposible',              CASE WHEN fnac IS NULL THEN 1 END),
    ('Nacimiento posterior a la encuesta',         CASE WHEN fnac > fenc THEN 1 END),
    ('Fecha de encuesta imposible',                CASE WHEN fenc IS NULL THEN 1 END),
    ('Edad reportada distinta a la calculada',     CASE WHEN fnac <= fenc AND TRY_CONVERT(INT, ReportedAge) <>
                                                         DATEDIFF(YEAR, fnac, fenc) - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, fnac, fenc), fnac) > fenc THEN 1 ELSE 0 END THEN 1 END),
    ('Ingreso en texto (no numérico)',             CASE WHEN MonthlyIncome LIKE '%[a-z]%' THEN 1 END),
    ('Ingreso negativo',                           CASE WHEN MonthlyIncome LIKE '-%' THEN 1 END),
    ('Correo sin @',                               CASE WHEN Email NOT LIKE '%@%' THEN 1 END),
    ('Teléfono con menos de 10 dígitos',           CASE WHEN LEN(REPLACE(Phone, '-', '')) <> 10 THEN 1 END),
    ('Sexo fuera de F/M/ND',                       CASE WHEN Sex NOT IN ('F', 'M', 'ND') THEN 1 END),
    ('Zona fuera de URBANA/RURAL',                 CASE WHEN Zone NOT IN ('URBANA', 'RURAL') THEN 1 END),
    ('Estrato fuera de 1 a 6',                     CASE WHEN TRY_CONVERT(INT, SocioeconomicStratum) NOT BETWEEN 1 AND 6
                                                          OR TRY_CONVERT(INT, SocioeconomicStratum) IS NULL THEN 1 END),
    ('Personas a cargo no entero o negativo',      CASE WHEN TRY_CONVERT(INT, Dependents) IS NULL OR TRY_CONVERT(INT, Dependents) < 0 THEN 1 END),
    ('Tamaño del hogar menor que 1',               CASE WHEN TRY_CONVERT(INT, HouseholdSize) < 1 THEN 1 END),
    ('Municipio desconocido (M999)',               CASE WHEN MunicipalityCode = 'M999' THEN 1 END),
    ('Canal no estándar (FAX)',                    CASE WHEN SourceChannel NOT IN ('WEB', 'TELEFONO', 'PRESENCIAL') THEN 1 END),
    ('Empleado sin tipo de contrato',              CASE WHEN EmploymentStatus = 'EMPLEADO' AND ContractType = 'NO_APLICA' THEN 1 END),
    ('Inicio de empleo posterior a la encuesta',   CASE WHEN TRY_CONVERT(DATE, EmploymentStartDate, 23) > fenc THEN 1 END),
    ('UpdatedAt anterior a la encuesta',           CASE WHEN TRY_CONVERT(DATETIME2, UpdatedAt) < fenc THEN 1 END)
) r(regla, marca)
WHERE marca = 1
GROUP BY regla
ORDER BY filas DESC;

/* ---------- 6. Coherencia municipio - departamento ---------- */
SELECT e.DepartmentCode, e.DepartmentName, e.MunicipalityCode, e.MunicipalityName,
       m.DepartamentoCodigo AS depto_segun_catalogo, COUNT(*) AS filas
FROM stg.PersonasExcel e
LEFT JOIN dbo.Municipio m ON m.MunicipioCodigo = e.MunicipalityCode
WHERE m.MunicipioCodigo IS NULL OR m.DepartamentoCodigo <> e.DepartmentCode
GROUP BY e.DepartmentCode, e.DepartmentName, e.MunicipalityCode, e.MunicipalityName, m.DepartamentoCodigo
ORDER BY e.MunicipalityCode, e.DepartmentCode;
GO
