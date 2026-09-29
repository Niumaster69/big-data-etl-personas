/* =====================================================================
   Actividad 4 - Punto 1: ETL mediante cursores
   Script 04: cursor de limpieza y cálculo del balance mensual

   Requisito previo: stg.CursorPersonas cargada con SourceRowId 1 a 100
   (script 03 o paquete SSIS P0_Staging_Cursor).

   Reglas:
   - Textos: sin espacios sobrantes; tipo de documento en mayúsculas;
     nombres y apellidos como nombre propio.
   - Rechazo si falta el documento ("SIN-DATO" también cuenta como
     faltante), el primer nombre o el primer apellido, o si el tipo de
     documento no es CC, CE o PA.
   - MonthlyIncome y MonthlyExpenses: se quitan símbolos y separadores y
     se convierten a DECIMAL(18,2). Rechazo si falta, no es numérico o es
     negativo. Un importe desconocido NUNCA se reemplaza por cero.
   - Balance = ingreso - gasto. Un balance negativo es válido.
   - El script se puede ejecutar varias veces: limpia los destinos al
     inicio.
   ===================================================================== */
USE PersonasETL;
GO
SET NOCOUNT ON;

TRUNCATE TABLE cur.PersonaValida;
TRUNCATE TABLE cur.PersonaRechazada;

/* Variables de lectura: una por columna del cursor (valores originales) */
DECLARE @SourceRowId     NVARCHAR(255),
        @DocumentType    NVARCHAR(255),
        @DocumentNumber  NVARCHAR(255),
        @FirstName       NVARCHAR(255),
        @MiddleName      NVARCHAR(255),
        @LastName        NVARCHAR(255),
        @SecondLastName  NVARCHAR(255),
        @MonthlyIncome   NVARCHAR(255),
        @MonthlyExpenses NVARCHAR(255);

/* Variables de trabajo (valores limpios) */
DECLARE @id              INT,
        @tipoDoc         NVARCHAR(255),
        @numDoc          NVARCHAR(255),
        @nombre1         NVARCHAR(255),
        @nombre2         NVARCHAR(255),
        @apellido1       NVARCHAR(255),
        @apellido2       NVARCHAR(255),
        @ingresoTxt      NVARCHAR(255),
        @gastoTxt        NVARCHAR(255),
        @ingreso         DECIMAL(18,2),
        @gasto           DECIMAL(18,2),
        @motivo          NVARCHAR(1000);

/* Contadores */
DECLARE @procesados INT = 0,
        @aceptados  INT = 0,
        @rechazados INT = 0;

/* 1. DECLARACIÓN del cursor: los 100 registros del staging en orden */
DECLARE cur_personas CURSOR LOCAL FAST_FORWARD FOR
    SELECT SourceRowId, DocumentType, DocumentNumber,
           FirstName, MiddleName, LastName, SecondLastName,
           MonthlyIncome, MonthlyExpenses
    FROM stg.CursorPersonas
    WHERE TRY_CONVERT(INT, SourceRowId) BETWEEN 1 AND 100
    ORDER BY TRY_CONVERT(INT, SourceRowId);

/* 2. APERTURA */
OPEN cur_personas;

/* 3. LECTURA del primer registro */
FETCH NEXT FROM cur_personas
 INTO @SourceRowId, @DocumentType, @DocumentNumber,
      @FirstName, @MiddleName, @LastName, @SecondLastName,
      @MonthlyIncome, @MonthlyExpenses;

/* 4. RECORRIDO: mientras la última lectura haya sido exitosa */
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @procesados += 1;
    SET @motivo = N'';
    SET @id = TRY_CONVERT(INT, @SourceRowId);

    /* --- Limpieza de textos --- */
    SET @tipoDoc   = UPPER(cur.fn_QuitarEspacios(@DocumentType));
    SET @numDoc    = UPPER(cur.fn_QuitarEspacios(@DocumentNumber));
    SET @nombre1   = cur.fn_NombrePropio(@FirstName);
    SET @nombre2   = cur.fn_NombrePropio(@MiddleName);
    SET @apellido1 = cur.fn_NombrePropio(@LastName);
    SET @apellido2 = cur.fn_NombrePropio(@SecondLastName);

    IF @numDoc IN (N'SIN-DATO', N'SIN DATO', N'ND', N'N/A', N'NULL')
        SET @numDoc = NULL;                     -- marcador de "sin dato"

    /* --- Campos obligatorios --- */
    IF @tipoDoc IS NULL
        SET @motivo += N'Tipo de documento faltante; ';
    ELSE IF @tipoDoc NOT IN (N'CC', N'CE', N'PA')
        SET @motivo += N'Tipo de documento no válido (' + @tipoDoc + N'); ';
    IF @numDoc IS NULL
        SET @motivo += N'Documento faltante; ';
    IF @nombre1 IS NULL
        SET @motivo += N'Primer nombre faltante; ';
    IF @apellido1 IS NULL
        SET @motivo += N'Primer apellido faltante; ';

    /* --- Importes: normalizar, convertir y validar --- */
    SET @ingresoTxt = cur.fn_NormalizarImporte(@MonthlyIncome);
    SET @gastoTxt   = cur.fn_NormalizarImporte(@MonthlyExpenses);
    SET @ingreso    = CASE WHEN @ingresoTxt NOT LIKE N'%[^0-9.-]%'
                           THEN TRY_CONVERT(DECIMAL(18,2), @ingresoTxt) END;
    SET @gasto      = CASE WHEN @gastoTxt NOT LIKE N'%[^0-9.-]%'
                           THEN TRY_CONVERT(DECIMAL(18,2), @gastoTxt) END;

    IF @ingresoTxt IS NULL
        SET @motivo += N'MonthlyIncome faltante; ';
    ELSE IF @ingreso IS NULL
        SET @motivo += N'MonthlyIncome no numérico (' + @MonthlyIncome + N'); ';
    ELSE IF @ingreso < 0
        SET @motivo += N'MonthlyIncome negativo (' + @MonthlyIncome + N'); ';

    IF @gastoTxt IS NULL
        SET @motivo += N'MonthlyExpenses faltante; ';
    ELSE IF @gasto IS NULL
        SET @motivo += N'MonthlyExpenses no numérico (' + @MonthlyExpenses + N'); ';
    ELSE IF @gasto < 0
        SET @motivo += N'MonthlyExpenses negativo (' + @MonthlyExpenses + N'); ';

    /* --- Carga: válido o rechazado --- */
    IF @motivo = N''
    BEGIN
        INSERT INTO cur.PersonaValida
            (SourceRowId, TipoDocumento, NumeroDocumento, PrimerNombre, SegundoNombre,
             PrimerApellido, SegundoApellido, IngresoMensual, GastoMensual, BalanceMensual)
        VALUES
            (@id, @tipoDoc, @numDoc, @nombre1, @nombre2,
             @apellido1, @apellido2, @ingreso, @gasto, @ingreso - @gasto);
        SET @aceptados += 1;
    END
    ELSE
    BEGIN
        INSERT INTO cur.PersonaRechazada
            (SourceRowId, DocumentTypeOriginal, DocumentNumberOriginal, FirstNameOriginal,
             LastNameOriginal, IncomeOriginal, ExpensesOriginal, Motivo)
        VALUES
            (@id, @DocumentType, @DocumentNumber, @FirstName,
             @LastName, @MonthlyIncome, @MonthlyExpenses,
             LEFT(@motivo, LEN(@motivo) - 1));   -- sin el último ";"
        SET @rechazados += 1;
    END;

    /* Siguiente registro */
    FETCH NEXT FROM cur_personas
     INTO @SourceRowId, @DocumentType, @DocumentNumber,
          @FirstName, @MiddleName, @LastName, @SecondLastName,
          @MonthlyIncome, @MonthlyExpenses;
END;

/* 5. CIERRE */
CLOSE cur_personas;

/* 6. LIBERACIÓN */
DEALLOCATE cur_personas;

/* --- Resumen --- */
PRINT CONCAT(N'Procesados: ', @procesados, N' | Aceptados: ', @aceptados, N' | Rechazados: ', @rechazados);

SELECT @procesados AS procesados,
       @aceptados  AS aceptados,
       @rechazados AS rechazados;
GO

/* =====================================================================
   Resultados
   ===================================================================== */

-- Antes y después de la limpieza (registros con correcciones visibles)
SELECT s.SourceRowId,
       s.DocumentType   AS tipo_original,    v.TipoDocumento  AS tipo_limpio,
       s.FirstName      AS nombre_original,  v.PrimerNombre   AS nombre_limpio,
       s.LastName       AS apellido_original,v.PrimerApellido AS apellido_limpio,
       s.MonthlyIncome  AS ingreso_original, v.IngresoMensual AS ingreso_limpio,
       s.MonthlyExpenses AS gasto_original,  v.GastoMensual   AS gasto_limpio,
       v.BalanceMensual
FROM stg.CursorPersonas s
JOIN cur.PersonaValida v ON v.SourceRowId = TRY_CONVERT(INT, s.SourceRowId)
WHERE s.DocumentType COLLATE Latin1_General_CS_AS <> v.TipoDocumento
   OR s.FirstName    COLLATE Latin1_General_CS_AS <> v.PrimerNombre
   OR s.LastName     COLLATE Latin1_General_CS_AS <> v.PrimerApellido
   OR s.MonthlyIncome   LIKE N'%[^0-9]%'
   OR s.MonthlyExpenses LIKE N'%[^0-9]%'
ORDER BY v.SourceRowId;

-- Rechazados con su motivo
SELECT SourceRowId, DocumentTypeOriginal, DocumentNumberOriginal, FirstNameOriginal,
       LastNameOriginal, IncomeOriginal, ExpensesOriginal, Motivo
FROM cur.PersonaRechazada
ORDER BY SourceRowId;

-- Balances negativos: válidos, no se rechazan
SELECT TOP (10) SourceRowId, PrimerNombre, PrimerApellido,
       IngresoMensual, GastoMensual, BalanceMensual
FROM cur.PersonaValida
WHERE BalanceMensual < 0
ORDER BY BalanceMensual;

-- Conteo por motivo
SELECT x.motivo, COUNT(*) AS registros
FROM cur.PersonaRechazada r
CROSS APPLY STRING_SPLIT(r.Motivo, N';') m
CROSS APPLY (SELECT RTRIM(LTRIM(LEFT(m.value, CHARINDEX(N'(', m.value + N'(') - 1))) AS motivo) x
GROUP BY x.motivo
ORDER BY registros DESC;
GO
