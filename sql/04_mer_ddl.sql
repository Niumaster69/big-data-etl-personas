/* =====================================================================
   Actividad 4 - Proceso A: modelo relacional (MER) destino del Excel
   Script 04: DDL del MER, catálogos de referencia y bitácora ETL

   Entidades principales
     Persona              -> clave de persona: tipo + número de documento
     Observacion          -> una encuesta: persona + fecha de encuesta
     ObservacionLaboral   -> datos del empleo (solo EMPLEADO / INDEPENDIENTE)
   Catálogos (datos de referencia internos del dataset, no DIVIPOLA)
     TipoDocumento, Departamento, Municipio, NivelEducativo,
     SituacionLaboral, EstadoCivil, TipoVivienda, RegimenSalud,
     TipoContrato, Ocupacion, CanalCaptura, Empleador (lo llena el ETL)
   Staging tipado (entre flujos de datos del paquete)
     stg.ObservacionValida, stg.ObservacionDepurada
   Bitácora
     etl.Ejecucion, etl.Cambio, etl.RegistroNoCargado

   El script es re-ejecutable: borra y crea todo de nuevo.
   ===================================================================== */
USE PersonasETL;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- requerido por la columna calculada persistida
GO

/* ---------- 0. Borrado en orden inverso de dependencias ---------- */
DROP TABLE IF EXISTS dbo.ObservacionLaboral;
DROP TABLE IF EXISTS dbo.Observacion;
DROP TABLE IF EXISTS dbo.Persona;
DROP TABLE IF EXISTS dbo.Empleador;
DROP TABLE IF EXISTS dbo.Municipio;
DROP TABLE IF EXISTS dbo.Departamento;
DROP TABLE IF EXISTS dbo.TipoDocumento;
DROP TABLE IF EXISTS dbo.NivelEducativo;
DROP TABLE IF EXISTS dbo.SituacionLaboral;
DROP TABLE IF EXISTS dbo.EstadoCivil;
DROP TABLE IF EXISTS dbo.TipoVivienda;
DROP TABLE IF EXISTS dbo.RegimenSalud;
DROP TABLE IF EXISTS dbo.TipoContrato;
DROP TABLE IF EXISTS dbo.Ocupacion;
DROP TABLE IF EXISTS dbo.CanalCaptura;
DROP TABLE IF EXISTS stg.PersonasExcel;
DROP TABLE IF EXISTS stg.ObservacionValida;
DROP TABLE IF EXISTS stg.ObservacionDepurada;
DROP TABLE IF EXISTS etl.Cambio;
DROP TABLE IF EXISTS etl.RegistroNoCargado;
DROP TABLE IF EXISTS etl.Ejecucion;
GO

/* =====================================================================
   1. Catálogos
   ===================================================================== */
CREATE TABLE dbo.TipoDocumento (
    TipoDocumentoCodigo  NVARCHAR(2)    NOT NULL CONSTRAINT PK_TipoDocumento PRIMARY KEY,
    Nombre               NVARCHAR(40)  NOT NULL
);
INSERT INTO dbo.TipoDocumento VALUES
 ('CC', N'Cédula de ciudadanía'), ('CE', N'Cédula de extranjería'), ('PA', N'Pasaporte');

CREATE TABLE dbo.Departamento (
    DepartamentoCodigo   NVARCHAR(5)    NOT NULL CONSTRAINT PK_Departamento PRIMARY KEY,
    Nombre               NVARCHAR(60)  NOT NULL CONSTRAINT UQ_Departamento_Nombre UNIQUE
);
INSERT INTO dbo.Departamento VALUES
 ('D01', N'CUNDINAMARCA'), ('D02', N'BOGOTÁ D.C.'), ('D03', N'ANTIOQUIA'),
 ('D04', N'BOYACÁ'), ('D05', N'VALLE DEL CAUCA');

CREATE TABLE dbo.Municipio (
    MunicipioCodigo      NVARCHAR(5)    NOT NULL CONSTRAINT PK_Municipio PRIMARY KEY,
    Nombre               NVARCHAR(60)  NOT NULL,
    DepartamentoCodigo   NVARCHAR(5)    NOT NULL
        CONSTRAINT FK_Municipio_Departamento REFERENCES dbo.Departamento (DepartamentoCodigo)
);
-- M999 "MUNICIPIO DESCONOCIDO" no es un municipio: no se incluye en el catálogo
INSERT INTO dbo.Municipio VALUES
 ('M001', N'CHÍA',        'D01'), ('M002', N'CAJICÁ',   'D01'), ('M003', N'ZIPAQUIRÁ', 'D01'),
 ('M004', N'SOACHA',      'D01'), ('M005', N'BOGOTÁ D.C.', 'D02'), ('M006', N'MEDELLÍN', 'D03'),
 ('M007', N'ENVIGADO',    'D03'), ('M008', N'TUNJA',    'D04'), ('M009', N'DUITAMA',   'D04'),
 ('M010', N'CALI',        'D05');

CREATE TABLE dbo.NivelEducativo (
    NivelEducativoCodigo NVARCHAR(20)   NOT NULL CONSTRAINT PK_NivelEducativo PRIMARY KEY,
    Nombre               NVARCHAR(40)  NOT NULL,
    Orden                TINYINT       NOT NULL
);
INSERT INTO dbo.NivelEducativo VALUES
 ('NINGUNO', N'Ninguno', 1), ('PRIMARIA', N'Primaria', 2), ('SECUNDARIA', N'Secundaria', 3),
 ('TECNICO', N'Técnico', 4), ('TECNOLOGO', N'Tecnólogo', 5), ('UNIVERSITARIO', N'Universitario', 6),
 ('POSGRADO', N'Posgrado', 7);

CREATE TABLE dbo.SituacionLaboral (
    SituacionLaboralCodigo NVARCHAR(20) NOT NULL CONSTRAINT PK_SituacionLaboral PRIMARY KEY,
    Nombre               NVARCHAR(40)  NOT NULL,
    TieneOcupacion       BIT           NOT NULL   -- 1: debe tener ocupación y datos laborales
);
INSERT INTO dbo.SituacionLaboral VALUES
 ('EMPLEADO', N'Empleado', 1), ('INDEPENDIENTE', N'Independiente', 1),
 ('DESEMPLEADO', N'Desempleado', 0), ('ESTUDIANTE', N'Estudiante', 0), ('PENSIONADO', N'Pensionado', 0);

CREATE TABLE dbo.EstadoCivil (
    EstadoCivilCodigo    NVARCHAR(20)   NOT NULL CONSTRAINT PK_EstadoCivil PRIMARY KEY,
    Nombre               NVARCHAR(40)  NOT NULL
);
INSERT INTO dbo.EstadoCivil VALUES
 ('SOLTERO', N'Soltero'), ('CASADO', N'Casado'), ('UNION_LIBRE', N'Unión libre'),
 ('DIVORCIADO', N'Divorciado'), ('VIUDO', N'Viudo');

CREATE TABLE dbo.TipoVivienda (
    TipoViviendaCodigo   NVARCHAR(20)   NOT NULL CONSTRAINT PK_TipoVivienda PRIMARY KEY,
    Nombre               NVARCHAR(40)  NOT NULL
);
INSERT INTO dbo.TipoVivienda VALUES
 ('PROPIA', N'Propia'), ('ARRENDADA', N'Arrendada'), ('FAMILIAR', N'Familiar'), ('OTRA', N'Otra');

CREATE TABLE dbo.RegimenSalud (
    RegimenSaludCodigo   NVARCHAR(20)   NOT NULL CONSTRAINT PK_RegimenSalud PRIMARY KEY,
    Nombre               NVARCHAR(40)  NOT NULL
);
INSERT INTO dbo.RegimenSalud VALUES
 ('CONTRIBUTIVO', N'Contributivo'), ('SUBSIDIADO', N'Subsidiado'),
 ('ESPECIAL', N'Especial'), ('NO_AFILIADO', N'No afiliado');

CREATE TABLE dbo.TipoContrato (
    TipoContratoCodigo   NVARCHAR(20)   NOT NULL CONSTRAINT PK_TipoContrato PRIMARY KEY,
    Nombre               NVARCHAR(40)  NOT NULL
);
-- NO_APLICA no es un contrato: significa que la persona no tiene empleo
INSERT INTO dbo.TipoContrato VALUES
 ('FIJO', N'Término fijo'), ('INDEFINIDO', N'Término indefinido'), ('SERVICIOS', N'Prestación de servicios');

CREATE TABLE dbo.Ocupacion (
    OcupacionCodigo      NVARCHAR(5)    NOT NULL CONSTRAINT PK_Ocupacion PRIMARY KEY,
    Nombre               NVARCHAR(60)  NOT NULL
);
INSERT INTO dbo.Ocupacion VALUES
 ('O01', N'DOCENTE'), ('O02', N'DESARROLLADOR'), ('O03', N'COMERCIANTE'),
 ('O04', N'AUXILIAR ADMINISTRATIVO'), ('O05', N'CONDUCTOR'), ('O06', N'TÉCNICO DE SOPORTE'),
 ('O07', N'CONTADOR'), ('O08', N'OPERARIO'), ('O99', N'SIN CLASIFICAR');

CREATE TABLE dbo.CanalCaptura (
    CanalCodigo          NVARCHAR(20)   NOT NULL CONSTRAINT PK_CanalCaptura PRIMARY KEY,
    Nombre               NVARCHAR(40)  NOT NULL
);
INSERT INTO dbo.CanalCaptura VALUES
 ('WEB', N'Formulario web'), ('TELEFONO', N'Llamada telefónica'), ('PRESENCIAL', N'Entrevista presencial');

CREATE TABLE dbo.Empleador (
    EmpleadorId          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Empleador PRIMARY KEY,
    Nombre               NVARCHAR(100) NOT NULL CONSTRAINT UQ_Empleador_Nombre UNIQUE
);
GO

/* =====================================================================
   2. Entidades principales
   ===================================================================== */
CREATE TABLE dbo.Persona (
    PersonaId            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Persona PRIMARY KEY,
    TipoDocumentoCodigo  NVARCHAR(2)    NOT NULL
        CONSTRAINT FK_Persona_TipoDocumento REFERENCES dbo.TipoDocumento (TipoDocumentoCodigo),
    NumeroDocumento      NVARCHAR(20)   NOT NULL,
    PrimerNombre         NVARCHAR(60)  NOT NULL,
    SegundoNombre        NVARCHAR(60)  NULL,
    PrimerApellido       NVARCHAR(60)  NOT NULL,
    SegundoApellido      NVARCHAR(60)  NULL,
    FechaNacimiento      DATE          NOT NULL,
    Sexo                 NVARCHAR(2)    NULL CONSTRAINT CK_Persona_Sexo CHECK (Sexo IN ('F', 'M', 'ND')),
    Correo               NVARCHAR(120) NULL,
    Telefono             NVARCHAR(10)   NULL,
    SourceRowIdOrigen    INT           NOT NULL,   -- fila del Excel de la que salió
    FechaCarga           DATETIME2(0)  NOT NULL CONSTRAINT DF_Persona_FechaCarga DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_Persona_Documento UNIQUE (TipoDocumentoCodigo, NumeroDocumento)
);

CREATE TABLE dbo.Observacion (
    ObservacionId        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Observacion PRIMARY KEY,
    PersonaId            INT           NOT NULL
        CONSTRAINT FK_Observacion_Persona REFERENCES dbo.Persona (PersonaId),
    FechaEncuesta        DATE          NOT NULL,
    EdadReportada        TINYINT       NOT NULL,
    EstadoCivilCodigo    NVARCHAR(20)   NULL
        CONSTRAINT FK_Observacion_EstadoCivil REFERENCES dbo.EstadoCivil (EstadoCivilCodigo),
    MunicipioCodigo      NVARCHAR(5)    NOT NULL
        CONSTRAINT FK_Observacion_Municipio REFERENCES dbo.Municipio (MunicipioCodigo),
    Zona                 NVARCHAR(10)   NULL CONSTRAINT CK_Observacion_Zona CHECK (Zona IN ('URBANA', 'RURAL')),
    Direccion            NVARCHAR(120) NULL,
    TipoViviendaCodigo   NVARCHAR(20)   NULL
        CONSTRAINT FK_Observacion_TipoVivienda REFERENCES dbo.TipoVivienda (TipoViviendaCodigo),
    Estrato              TINYINT       NULL CONSTRAINT CK_Observacion_Estrato CHECK (Estrato BETWEEN 1 AND 6),
    NivelEducativoCodigo NVARCHAR(20)   NOT NULL
        CONSTRAINT FK_Observacion_NivelEducativo REFERENCES dbo.NivelEducativo (NivelEducativoCodigo),
    SituacionLaboralCodigo NVARCHAR(20) NOT NULL
        CONSTRAINT FK_Observacion_SituacionLaboral REFERENCES dbo.SituacionLaboral (SituacionLaboralCodigo),
    IngresoMensual       DECIMAL(18,2) NOT NULL CONSTRAINT CK_Observacion_Ingreso CHECK (IngresoMensual >= 0),
    GastoMensual         DECIMAL(18,2) NOT NULL CONSTRAINT CK_Observacion_Gasto CHECK (GastoMensual >= 0),
    BalanceMensual       AS (IngresoMensual - GastoMensual) PERSISTED,   -- puede ser negativo
    PersonasACargo       TINYINT       NULL,
    TamanoHogar          TINYINT       NULL CONSTRAINT CK_Observacion_Hogar CHECK (TamanoHogar >= 1),
    RegimenSaludCodigo   NVARCHAR(20)   NULL
        CONSTRAINT FK_Observacion_RegimenSalud REFERENCES dbo.RegimenSalud (RegimenSaludCodigo),
    Discapacidad         NVARCHAR(2)    NULL CONSTRAINT CK_Observacion_Discapacidad CHECK (Discapacidad IN ('SI', 'NO', 'ND')),
    CanalCodigo          NVARCHAR(20)   NULL
        CONSTRAINT FK_Observacion_Canal REFERENCES dbo.CanalCaptura (CanalCodigo),
    FechaActualizacion   DATETIME2(0)  NULL,
    SourceRowId          INT           NOT NULL CONSTRAINT UQ_Observacion_SourceRowId UNIQUE,
    FechaCarga           DATETIME2(0)  NOT NULL CONSTRAINT DF_Observacion_FechaCarga DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_Observacion_PersonaFecha UNIQUE (PersonaId, FechaEncuesta)
);

CREATE TABLE dbo.ObservacionLaboral (
    ObservacionId        INT           NOT NULL CONSTRAINT PK_ObservacionLaboral PRIMARY KEY
        CONSTRAINT FK_ObservacionLaboral_Observacion REFERENCES dbo.Observacion (ObservacionId),
    OcupacionCodigo      NVARCHAR(5)    NOT NULL
        CONSTRAINT FK_ObservacionLaboral_Ocupacion REFERENCES dbo.Ocupacion (OcupacionCodigo),
    TipoContratoCodigo   NVARCHAR(20)   NOT NULL
        CONSTRAINT FK_ObservacionLaboral_TipoContrato REFERENCES dbo.TipoContrato (TipoContratoCodigo),
    EmpleadorId          INT           NULL
        CONSTRAINT FK_ObservacionLaboral_Empleador REFERENCES dbo.Empleador (EmpleadorId),
    FechaInicioEmpleo    DATE          NULL
);
GO

/* =====================================================================
   3. Staging (lo escribe y lo lee el paquete A)
   stg.PersonasExcel       -> copia de las 1.000 filas tal como vienen del
                              Excel (evidencia del "antes")
   stg.ObservacionValida   -> filas que pasaron todas las reglas (puede
                              haber duplicados)
   stg.ObservacionDepurada -> una sola versión por persona y fecha
   ===================================================================== */
SELECT * INTO stg.PersonasExcel FROM stg.CursorPersonas WHERE 1 = 0;

CREATE TABLE stg.ObservacionValida (
    SourceRowId          INT           NOT NULL,
    TipoDocumento        NVARCHAR(2)    NOT NULL,
    NumeroDocumento      NVARCHAR(20)   NOT NULL,
    PrimerNombre         NVARCHAR(60)  NOT NULL,
    SegundoNombre        NVARCHAR(60)  NULL,
    PrimerApellido       NVARCHAR(60)  NOT NULL,
    SegundoApellido      NVARCHAR(60)  NULL,
    FechaNacimiento      DATE          NOT NULL,
    EdadReportada        INT           NOT NULL,
    Sexo                 NVARCHAR(2)    NULL,
    EstadoCivil          NVARCHAR(20)   NULL,
    Correo               NVARCHAR(120) NULL,
    Telefono             NVARCHAR(10)   NULL,
    MunicipioCodigo      NVARCHAR(5)    NOT NULL,
    Zona                 NVARCHAR(10)   NULL,
    Direccion            NVARCHAR(120) NULL,
    TipoVivienda         NVARCHAR(20)   NULL,
    Estrato              INT           NULL,
    NivelEducativo       NVARCHAR(20)   NOT NULL,
    SituacionLaboral     NVARCHAR(20)   NOT NULL,
    OcupacionCodigo      NVARCHAR(5)    NULL,
    Empleador            NVARCHAR(100) NULL,
    TipoContrato         NVARCHAR(20)   NULL,
    FechaInicioEmpleo    DATE          NULL,
    IngresoMensual       DECIMAL(18,2) NOT NULL,
    GastoMensual         DECIMAL(18,2) NOT NULL,
    PersonasACargo       INT           NULL,
    TamanoHogar          INT           NULL,
    RegimenSalud         NVARCHAR(20)   NULL,
    Discapacidad         NVARCHAR(2)    NULL,
    FechaEncuesta        DATE          NOT NULL,
    FechaActualizacion   DATETIME2(0)  NULL,
    Canal                NVARCHAR(20)   NULL
);

SELECT * INTO stg.ObservacionDepurada FROM stg.ObservacionValida WHERE 1 = 0;
GO

/* =====================================================================
   4. Bitácora del ETL
   ===================================================================== */
CREATE TABLE etl.Ejecucion (
    EjecucionId          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ejecucion PRIMARY KEY,
    Paquete              NVARCHAR(100) NOT NULL,
    FechaInicio          DATETIME2(0)  NOT NULL CONSTRAINT DF_Ejecucion_Inicio DEFAULT SYSDATETIME(),
    FechaFin             DATETIME2(0)  NULL,
    FilasLeidas          INT           NULL,
    FilasValidas         INT           NULL,
    FilasRevision        INT           NULL,
    FilasRechazadas      INT           NULL,
    FilasDuplicadas      INT           NULL,
    PersonasInsertadas   INT           NULL,
    PersonasExistentes   INT           NULL,
    ObservacionesInsertadas INT        NULL,
    ObservacionesExistentes INT        NULL
);

-- Un registro por cada campo que la limpieza modificó (valor antes y después)
CREATE TABLE etl.Cambio (
    CambioId             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Cambio PRIMARY KEY,
    EjecucionId          INT           NOT NULL
        CONSTRAINT FK_Cambio_Ejecucion REFERENCES etl.Ejecucion (EjecucionId),
    SourceRowId          INT           NOT NULL,
    Campo                NVARCHAR(50)  NOT NULL,
    ValorOriginal        NVARCHAR(255) NULL,
    ValorNuevo           NVARCHAR(255) NULL
);

-- Filas que no llegan al modelo: RECHAZO, REVISION o DUPLICADO
CREATE TABLE etl.RegistroNoCargado (
    RegistroId           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RegistroNoCargado PRIMARY KEY,
    EjecucionId          INT           NOT NULL
        CONSTRAINT FK_RegistroNoCargado_Ejecucion REFERENCES etl.Ejecucion (EjecucionId),
    SourceRowId          INT           NOT NULL,
    Clasificacion        NVARCHAR(10)   NOT NULL
        CONSTRAINT CK_RegistroNoCargado_Clasif CHECK (Clasificacion IN ('RECHAZO', 'REVISION', 'DUPLICADO')),
    Motivo               NVARCHAR(1000) NOT NULL,
    TipoDocumento        NVARCHAR(255) NULL,
    NumeroDocumento      NVARCHAR(255) NULL,
    FechaEncuesta        NVARCHAR(255) NULL,
    SourceRowIdConservado INT          NULL,   -- solo DUPLICADO: la versión que sí se cargó
    FechaRegistro        DATETIME2(0)  NOT NULL CONSTRAINT DF_RegistroNoCargado_Fecha DEFAULT SYSDATETIME()
);
GO

-- Evidencia: tablas del modelo
SELECT s.name AS esquema, t.name AS tabla,
       (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS columnas,
       (SELECT COUNT(*) FROM sys.foreign_keys f WHERE f.parent_object_id = t.object_id) AS fks
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name IN ('dbo', 'stg', 'etl')
ORDER BY s.name, t.name;
GO
