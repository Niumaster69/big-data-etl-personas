/* =====================================================================
   Actividad 4 - Proceso B: modelo multidimensional (data warehouse)
   Script 07: base PersonasDW y modelo en estrella

   Grano de la tabla de hechos: UNA observación por persona y fecha de
   encuesta (restricción única PersonaKey + TiempoKey).

   Dimensiones (clave sustituta + clave natural del relacional)
     DimTiempo            -> TiempoKey aaaammdd, año, mes, trimestre
     DimUbicacion         -> municipio y departamento
     DimEducacion         -> nivel educativo
     DimSituacionLaboral  -> situación laboral
     DimPersona           -> persona (para contar personas distintas)
   Hechos
     FactObservacion      -> ingreso, gasto, balance y cantidad de
                             observaciones (= 1 por fila)

   Las claves naturales usan NVARCHAR con la misma longitud que en
   PersonasETL, para que los Lookup de SSIS comparen el mismo tipo.
   La base usa la misma intercalación que PersonasETL, así las consultas
   de verificación entre las dos bases no dan conflicto de collation.

   El script es re-ejecutable: borra y crea todo de nuevo (el DW queda
   vacío y se llena con el paquete PB_Relacional_DW.dtsx).
   ===================================================================== */
USE master;
GO
IF DB_ID(N'PersonasDW') IS NULL
    CREATE DATABASE PersonasDW COLLATE Modern_Spanish_CI_AS;
GO
USE PersonasDW;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------- 0. Borrado (primero hechos, luego dimensiones) ---------- */
DROP TABLE IF EXISTS dbo.FactObservacion;
DROP TABLE IF EXISTS dbo.DimTiempo;
DROP TABLE IF EXISTS dbo.DimUbicacion;
DROP TABLE IF EXISTS dbo.DimEducacion;
DROP TABLE IF EXISTS dbo.DimSituacionLaboral;
DROP TABLE IF EXISTS dbo.DimPersona;
GO

/* =====================================================================
   1. Dimensiones
   ===================================================================== */

-- Tiempo: una fila por cada fecha de encuesta que exista en el relacional.
-- La clave es "inteligente" (aaaammdd) y la calcula el paquete con un
-- Derived Column, por eso no es IDENTITY.
CREATE TABLE dbo.DimTiempo (
    TiempoKey            INT           NOT NULL CONSTRAINT PK_DimTiempo PRIMARY KEY,
    Fecha                DATE          NOT NULL CONSTRAINT UQ_DimTiempo_Fecha UNIQUE,
    Anio                 INT           NOT NULL,
    Trimestre            INT           NOT NULL,
    Mes                  INT           NOT NULL,
    NombreMes            NVARCHAR(15)  NOT NULL,
    Dia                  INT           NOT NULL
);

CREATE TABLE dbo.DimUbicacion (
    UbicacionKey         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimUbicacion PRIMARY KEY,
    MunicipioCodigo      NVARCHAR(5)   NOT NULL CONSTRAINT UQ_DimUbicacion_Municipio UNIQUE,  -- clave natural
    Municipio            NVARCHAR(60)  NOT NULL,
    DepartamentoCodigo   NVARCHAR(5)   NOT NULL,
    Departamento         NVARCHAR(60)  NOT NULL
);

CREATE TABLE dbo.DimEducacion (
    EducacionKey         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimEducacion PRIMARY KEY,
    NivelEducativoCodigo NVARCHAR(20)  NOT NULL CONSTRAINT UQ_DimEducacion_Codigo UNIQUE,     -- clave natural
    NivelEducativo       NVARCHAR(40)  NOT NULL,
    Orden                TINYINT       NOT NULL   -- 1 Ninguno ... 7 Posgrado (para ordenar)
);

CREATE TABLE dbo.DimSituacionLaboral (
    SituacionLaboralKey  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimSituacionLaboral PRIMARY KEY,
    SituacionLaboralCodigo NVARCHAR(20) NOT NULL CONSTRAINT UQ_DimSituacionLaboral_Codigo UNIQUE, -- clave natural
    SituacionLaboral     NVARCHAR(40)  NOT NULL,
    TieneOcupacion       BIT           NOT NULL
);

CREATE TABLE dbo.DimPersona (
    PersonaKey           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimPersona PRIMARY KEY,
    TipoDocumento        NVARCHAR(2)   NOT NULL,   -- clave natural (1/2)
    NumeroDocumento      NVARCHAR(20)  NOT NULL,   -- clave natural (2/2)
    NombreCompleto       NVARCHAR(130) NOT NULL,   -- primer nombre + primer apellido (Derived Column)
    Sexo                 NVARCHAR(2)   NULL,
    FechaNacimiento      DATE          NOT NULL,
    CONSTRAINT UQ_DimPersona_Documento UNIQUE (TipoDocumento, NumeroDocumento)
);
GO

/* =====================================================================
   2. Tabla de hechos
   ===================================================================== */
CREATE TABLE dbo.FactObservacion (
    FactObservacionId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactObservacion PRIMARY KEY,
    TiempoKey            INT           NOT NULL
        CONSTRAINT FK_Fact_DimTiempo REFERENCES dbo.DimTiempo (TiempoKey),
    UbicacionKey         INT           NOT NULL
        CONSTRAINT FK_Fact_DimUbicacion REFERENCES dbo.DimUbicacion (UbicacionKey),
    EducacionKey         INT           NOT NULL
        CONSTRAINT FK_Fact_DimEducacion REFERENCES dbo.DimEducacion (EducacionKey),
    SituacionLaboralKey  INT           NOT NULL
        CONSTRAINT FK_Fact_DimSituacionLaboral REFERENCES dbo.DimSituacionLaboral (SituacionLaboralKey),
    PersonaKey           INT           NOT NULL
        CONSTRAINT FK_Fact_DimPersona REFERENCES dbo.DimPersona (PersonaKey),
    -- Medidas
    IngresoMensual       DECIMAL(18,2) NOT NULL,
    GastoMensual         DECIMAL(18,2) NOT NULL,
    BalanceMensual       DECIMAL(19,2) NOT NULL,   -- mismo tipo que la columna calculada del relacional
    CantidadObservaciones INT          NOT NULL CONSTRAINT DF_Fact_Cantidad DEFAULT 1,
    FechaCarga           DATETIME2(0)  NOT NULL CONSTRAINT DF_Fact_FechaCarga DEFAULT SYSDATETIME(),
    -- El grano: una observación por persona y fecha de encuesta
    CONSTRAINT UQ_FactObservacion_Grano UNIQUE (PersonaKey, TiempoKey)
);
GO

/* ---------- Evidencia: tablas del DW, columnas y llaves foráneas ---------- */
SELECT t.name AS tabla,
       CASE WHEN t.name LIKE 'Fact%' THEN 'Hechos' ELSE 'Dimensión' END AS tipo,
       (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS columnas,
       (SELECT COUNT(*) FROM sys.foreign_keys f WHERE f.parent_object_id = t.object_id) AS fks
FROM sys.tables t
ORDER BY tipo DESC, t.name;
GO
