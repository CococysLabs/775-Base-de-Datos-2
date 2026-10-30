USE master;
GO

IF DB_ID('ClaseMultidimensional') IS NULL
BEGIN
    CREATE DATABASE ClaseMultidimensional;
END
GO

USE ClaseMultidimensional;
GO

IF OBJECT_ID('fact_ventas', 'U') IS NOT NULL DROP TABLE fact_ventas;
IF OBJECT_ID('dim_cliente', 'U') IS NOT NULL DROP TABLE dim_cliente;
IF OBJECT_ID('dim_tienda', 'U') IS NOT NULL DROP TABLE dim_tienda;
IF OBJECT_ID('dim_producto', 'U') IS NOT NULL DROP TABLE dim_producto;
IF OBJECT_ID('dim_tiempo', 'U') IS NOT NULL DROP TABLE dim_tiempo;
GO

CREATE TABLE dim_tiempo (
    id_tiempo INT PRIMARY KEY,      -- formato YYYYMMDD
    anio INT NOT NULL,
    trimestre INT NOT NULL,
    mes INT NOT NULL,
    dia INT NOT NULL
);
GO

CREATE TABLE dim_producto (
    id_producto INT PRIMARY KEY,
    nombre_producto VARCHAR(100) NOT NULL,
    categoria VARCHAR(50) NOT NULL,
    precio_lista DECIMAL(12,2) NOT NULL
);
GO

CREATE TABLE dim_tienda (
    id_tienda INT PRIMARY KEY,
    nombre_tienda VARCHAR(100) NOT NULL,
    ciudad VARCHAR(50) NOT NULL,
    region VARCHAR(50) NOT NULL
);
GO

CREATE TABLE dim_cliente (
    id_cliente INT PRIMARY KEY,
    nombre_cliente VARCHAR(100) NOT NULL,
    segmento VARCHAR(50) NOT NULL
);
GO

CREATE TABLE fact_ventas (
    id_venta INT IDENTITY(1,1) PRIMARY KEY,
    id_tiempo INT NOT NULL,
    id_producto INT NOT NULL,
    id_tienda INT NOT NULL,
    id_cliente INT NOT NULL,
    cantidad INT NOT NULL,
    monto_total DECIMAL(14,2) NOT NULL,
    CONSTRAINT fk_fact_tiempo FOREIGN KEY (id_tiempo) REFERENCES dim_tiempo(id_tiempo),
    CONSTRAINT fk_fact_producto FOREIGN KEY (id_producto) REFERENCES dim_producto(id_producto),
    CONSTRAINT fk_fact_tienda FOREIGN KEY (id_tienda) REFERENCES dim_tienda(id_tienda),
    CONSTRAINT fk_fact_cliente FOREIGN KEY (id_cliente) REFERENCES dim_cliente(id_cliente)
);
GO

SELECT 'Esquema OLAP creado: dimensiones y tabla de hechos.' AS estado;
GO
