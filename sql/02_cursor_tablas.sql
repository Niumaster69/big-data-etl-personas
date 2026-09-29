/* =====================================================================
   Actividad 4 - Punto 1: ETL mediante cursores
   Script 02: tablas y funciones de apoyo del cursor

   stg.CursorPersonas     -> staging: SourceRowId 1 a 100 tal como vienen
                             del Excel (todas las columnas como texto,
                             sin limpiar nada)
   cur.PersonaValida      -> destino de los registros aceptados
   cur.PersonaRechazada   -> destino de los rechazados, con el motivo
   ===================================================================== */
USE PersonasETL;
GO

/* ---------- 1. Staging con los valores originales ---------- */
DROP TABLE IF EXISTS stg.CursorPersonas;
CREATE TABLE stg.CursorPersonas (
    SourceRowId          NVARCHAR(255) NULL,
    DocumentType         NVARCHAR(255) NULL,
    DocumentNumber       NVARCHAR(255) NULL,
    FirstName            NVARCHAR(255) NULL,
    MiddleName           NVARCHAR(255) NULL,
    LastName             NVARCHAR(255) NULL,
    SecondLastName       NVARCHAR(255) NULL,
    BirthDate            NVARCHAR(255) NULL,
    ReportedAge          NVARCHAR(255) NULL,
    Sex                  NVARCHAR(255) NULL,
    MaritalStatus        NVARCHAR(255) NULL,
    Email                NVARCHAR(255) NULL,
    Phone                NVARCHAR(255) NULL,
    DepartmentCode       NVARCHAR(255) NULL,
    DepartmentName       NVARCHAR(255) NULL,
    MunicipalityCode     NVARCHAR(255) NULL,
    MunicipalityName     NVARCHAR(255) NULL,
    Zone                 NVARCHAR(255) NULL,
    Address              NVARCHAR(255) NULL,
    HousingType          NVARCHAR(255) NULL,
    SocioeconomicStratum NVARCHAR(255) NULL,
    EducationLevel       NVARCHAR(255) NULL,
    EmploymentStatus     NVARCHAR(255) NULL,
    OccupationCode       NVARCHAR(255) NULL,
    OccupationName       NVARCHAR(255) NULL,
    EmployerName         NVARCHAR(255) NULL,
    ContractType         NVARCHAR(255) NULL,
    EmploymentStartDate  NVARCHAR(255) NULL,
    MonthlyIncome        NVARCHAR(255) NULL,
    MonthlyExpenses      NVARCHAR(255) NULL,
    Dependents           NVARCHAR(255) NULL,
    HouseholdSize        NVARCHAR(255) NULL,
    HealthRegime         NVARCHAR(255) NULL,
    Disability           NVARCHAR(255) NULL,
    SurveyDate           NVARCHAR(255) NULL,
    UpdatedAt            NVARCHAR(255) NULL,
    SourceChannel        NVARCHAR(255) NULL
);
GO

/* ---------- 2. Destino de los registros aceptados ---------- */
DROP TABLE IF EXISTS cur.PersonaValida;
CREATE TABLE cur.PersonaValida (
    SourceRowId      INT            NOT NULL CONSTRAINT PK_cur_PersonaValida PRIMARY KEY,
    TipoDocumento    VARCHAR(2)     NOT NULL,
    NumeroDocumento  VARCHAR(20)    NOT NULL,
    PrimerNombre     NVARCHAR(60)   NOT NULL,
    SegundoNombre    NVARCHAR(60)   NULL,
    PrimerApellido   NVARCHAR(60)   NOT NULL,
    SegundoApellido  NVARCHAR(60)   NULL,
    IngresoMensual   DECIMAL(18,2)  NOT NULL,
    GastoMensual     DECIMAL(18,2)  NOT NULL,
    BalanceMensual   DECIMAL(18,2)  NOT NULL,   -- puede ser negativo
    FechaProceso     DATETIME2(0)   NOT NULL CONSTRAINT DF_cur_PersonaValida_Fecha DEFAULT SYSDATETIME()
);
GO

/* ---------- 3. Destino de los rechazados (con el motivo) ---------- */
DROP TABLE IF EXISTS cur.PersonaRechazada;
CREATE TABLE cur.PersonaRechazada (
    SourceRowId            INT            NOT NULL CONSTRAINT PK_cur_PersonaRechazada PRIMARY KEY,
    DocumentTypeOriginal   NVARCHAR(255)  NULL,
    DocumentNumberOriginal NVARCHAR(255)  NULL,
    FirstNameOriginal      NVARCHAR(255)  NULL,
    LastNameOriginal       NVARCHAR(255)  NULL,
    IncomeOriginal         NVARCHAR(255)  NULL,
    ExpensesOriginal       NVARCHAR(255)  NULL,
    Motivo                 NVARCHAR(1000) NOT NULL,
    FechaProceso           DATETIME2(0)   NOT NULL CONSTRAINT DF_cur_PersonaRechazada_Fecha DEFAULT SYSDATETIME()
);
GO

/* ---------- 4. Funciones de apoyo ---------- */

-- Quita espacios al inicio y al final, y deja un solo espacio entre palabras.
CREATE OR ALTER FUNCTION cur.fn_QuitarEspacios (@texto NVARCHAR(4000))
RETURNS NVARCHAR(4000)
AS
BEGIN
    IF @texto IS NULL RETURN NULL;
    SET @texto = REPLACE(REPLACE(REPLACE(@texto, NCHAR(9), N' '), NCHAR(160), N' '), NCHAR(13) + NCHAR(10), N' ');
    SET @texto = LTRIM(RTRIM(@texto));
    WHILE CHARINDEX(N'  ', @texto) > 0
        SET @texto = REPLACE(@texto, N'  ', N' ');
    RETURN NULLIF(@texto, N'');   -- una cadena vacía se trata como faltante
END;
GO

-- Nombre propio: primera letra de cada palabra en mayúscula y el resto en minúscula.
-- "andrés" -> "Andrés", "GARCÍA" -> "García", "maría  josé" -> "María José"
CREATE OR ALTER FUNCTION cur.fn_NombrePropio (@texto NVARCHAR(4000))
RETURNS NVARCHAR(4000)
AS
BEGIN
    SET @texto = cur.fn_QuitarEspacios(@texto);
    IF @texto IS NULL RETURN NULL;

    DECLARE @resultado NVARCHAR(4000) = N'',
            @i INT = 1,
            @inicioPalabra BIT = 1,
            @c NCHAR(1);
    WHILE @i <= LEN(@texto)
    BEGIN
        SET @c = SUBSTRING(@texto, @i, 1);
        SET @resultado += CASE WHEN @inicioPalabra = 1 THEN UPPER(@c) ELSE LOWER(@c) END;
        SET @inicioPalabra = CASE WHEN @c IN (N' ', N'-') THEN 1 ELSE 0 END;
        SET @i += 1;
    END;
    RETURN @resultado;
END;
GO

-- Deja un importe listo para convertirse a número, sin validarlo:
--   quita $, COP y espacios;
--   formato alterno (punto = miles, coma = decimales): "$ 14.700.000,00" -> "14700000.00"
--   coma decimal sin miles: "8900000,50" -> "8900000.50"
--   si solo trae puntos de miles: "1.200.000" -> "1200000"
-- La validación (faltante, no numérico, negativo) la hace el cursor.
CREATE OR ALTER FUNCTION cur.fn_NormalizarImporte (@texto NVARCHAR(4000))
RETURNS NVARCHAR(4000)
AS
BEGIN
    SET @texto = cur.fn_QuitarEspacios(@texto);
    IF @texto IS NULL RETURN NULL;

    SET @texto = UPPER(@texto);
    SET @texto = REPLACE(@texto, N'COP', N'');
    SET @texto = REPLACE(@texto, N'$', N'');
    SET @texto = REPLACE(@texto, N' ', N'');

    IF CHARINDEX(N',', @texto) > 0
        SET @texto = REPLACE(REPLACE(@texto, N'.', N''), N',', N'.');
    ELSE IF @texto LIKE N'%.[0-9][0-9][0-9]' AND LEN(@texto) - LEN(REPLACE(@texto, N'.', N'')) >= 1
         AND @texto NOT LIKE N'%.[0-9][0-9][0-9][0-9]%'
        SET @texto = REPLACE(@texto, N'.', N'');

    RETURN NULLIF(@texto, N'');
END;
GO

-- Evidencia
SELECT s.name AS esquema, o.name AS objeto, o.type_desc AS tipo
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name IN (N'stg', N'cur') AND o.type IN ('U', 'FN')
ORDER BY s.name, o.type, o.name;
GO
