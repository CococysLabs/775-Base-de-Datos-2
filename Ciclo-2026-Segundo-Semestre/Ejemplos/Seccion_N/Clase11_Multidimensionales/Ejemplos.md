
## 1. Preparación del entorno

Este ejemplo muestra cómo construir desde cero un esquema estrella OLAP en SQL Server
Al final tendrás una base de datos OLAP llamada ClaseMultidimensional, con cuatro tablas de dimensiones y una tabla de hechos conectada por llaves foráneas.

Primero, levanta el entorno de SQL Server usando Docker. Ejecuta en la terminal:

```bash
docker compose up -d  # Inicia el contenedor SQL Server en segundo plano
```




## 2. Modelo estrella y granularidad

El modelo estrella OLAP que construiremos tiene una tabla de hechos (fact_ventas) en el centro y cuatro dimensiones: tiempo, producto, tienda y cliente. La granularidad será una venta agregada por combinación de tiempo, producto, tienda y cliente. Esto evita duplicados y asegura análisis correctos.



## 3. Creación de la base de datos OLAP

crea la base de datos OLAP y asegúrate de que solo se cree si no existe:

```sql
USE master;  -- Cambia al contexto del sistema para poder crear bases
GO

IF DB_ID('ClaseMultidimensional') IS NULL  -- Verifica si la base ya existe
BEGIN
    CREATE DATABASE ClaseMultidimensional;  -- Crea la base OLAP solo si no existe
END
GO
```

Puedes comprobar que la base se creó correctamente con:

```sql
SELECT name FROM sys.databases WHERE name = 'ClaseMultidimensional';  -- Debe devolver una fila si existe
```

---

## 4. Selección de la base de datos

Luego, cambia el contexto a la base OLAP para que todas las tablas se creen ahí:

```sql
USE ClaseMultidimensional;  -- Todo lo que crees a partir de aquí queda en esta base
GO
```

---

## 5. Creación de las dimensiones

Ahora crea las tablas de dimensiones. Cada tabla representa un eje de análisis y tiene su propia llave primaria.

```sql
-- Dimensión de tiempo: permite analizar ventas por año, trimestre, mes y día
CREATE TABLE dim_tiempo (
    id_tiempo INT PRIMARY KEY,      -- Formato sugerido: YYYYMMDD
    anio INT NOT NULL,              -- Año de la fecha
    trimestre INT NOT NULL,         -- Trimestre (1-4)
    mes INT NOT NULL,               -- Mes (1-12)
    dia INT NOT NULL                -- Día (1-31)
);
GO

-- Dimensión de producto: clasifica ventas por producto y categoría
CREATE TABLE dim_producto (
    id_producto INT PRIMARY KEY,            -- Identificador único del producto
    nombre_producto VARCHAR(100) NOT NULL,  -- Nombre legible
    categoria VARCHAR(50) NOT NULL,         -- Familia o tipo de producto
    precio_lista DECIMAL(12,2) NOT NULL    -- Precio de referencia
);
GO

-- Dimensión de tienda: permite análisis geográfico y organizacional
CREATE TABLE dim_tienda (
    id_tienda INT PRIMARY KEY,              -- Identificador único de la tienda
    nombre_tienda VARCHAR(100) NOT NULL,    -- Nombre comercial
    ciudad VARCHAR(50) NOT NULL,            -- Ciudad donde está la tienda
    region VARCHAR(50) NOT NULL             -- Región geográfica
);
GO

-- Dimensión de cliente: segmenta resultados por tipo de cliente
CREATE TABLE dim_cliente (
    id_cliente INT PRIMARY KEY,             -- Identificador único del cliente
    nombre_cliente VARCHAR(100) NOT NULL,   -- Nombre del cliente
    segmento VARCHAR(50) NOT NULL           -- Segmento de negocio (ej: Retail, Corporativo)
);
GO
```

---

## 6. Creación de la tabla de hechos

La tabla de hechos es el centro del modelo estrella. Aquí se almacenan las métricas numéricas (cantidad, monto_total) y las llaves foráneas que conectan con cada dimensión.

```sql
-- Tabla de hechos: almacena las ventas agregadas y conecta todas las dimensiones
CREATE TABLE fact_ventas (
    id_venta INT IDENTITY(1,1) PRIMARY KEY,   -- Identificador autoincremental de la venta
    id_tiempo INT NOT NULL,                   -- Llave foránea a dim_tiempo
    id_producto INT NOT NULL,                 -- Llave foránea a dim_producto
    id_tienda INT NOT NULL,                   -- Llave foránea a dim_tienda
    id_cliente INT NOT NULL,                  -- Llave foránea a dim_cliente
    cantidad INT NOT NULL,                    -- Medida: cantidad vendida
    monto_total DECIMAL(14,2) NOT NULL,       -- Medida: monto total de la venta
    CONSTRAINT fk_fact_tiempo FOREIGN KEY (id_tiempo) REFERENCES dim_tiempo(id_tiempo),
    CONSTRAINT fk_fact_producto FOREIGN KEY (id_producto) REFERENCES dim_producto(id_producto),
    CONSTRAINT fk_fact_tienda FOREIGN KEY (id_tienda) REFERENCES dim_tienda(id_tienda),
    CONSTRAINT fk_fact_cliente FOREIGN KEY (id_cliente) REFERENCES dim_cliente(id_cliente)
);
GO
```

---

## 7. Verificación de tablas creadas

Para verificar que todas las tablas se crearon correctamente, ejecuta:

```sql
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME;
-- Debes ver: dim_cliente, dim_producto, dim_tienda, dim_tiempo, fact_ventas
```

---

## 8. Verificación de relaciones (llaves foráneas)

Para comprobar que la tabla de hechos está conectada a las dimensiones por llaves foráneas:

```sql
SELECT
    fk.name AS nombre_fk,
    OBJECT_NAME(fk.parent_object_id) AS tabla_hija,
    OBJECT_NAME(fk.referenced_object_id) AS tabla_padre
FROM sys.foreign_keys fk
WHERE OBJECT_NAME(fk.parent_object_id) = 'fact_ventas'
ORDER BY fk.name;
-- Debe listar las 4 relaciones de fact_ventas hacia cada dimensión
```

---

## 9. Inserción de datos de ejemplo

Para poder realizar consultas, primero inserta algunos datos en las dimensiones y la tabla de hechos:
En este bloque se carga un conjunto pequeño de datos para simular ventas reales y luego poder analizar resultados en OLAP.

```sql
-- Insertar datos en la dimensión de tiempo
-- Se crean 3 fechas de ejemplo (enero, febrero y marzo de 2025)
INSERT INTO dim_tiempo (id_tiempo, anio, trimestre, mes, dia) VALUES
    (20250101, 2025, 1, 1, 1),
    (20250201, 2025, 1, 2, 1),
    (20250301, 2025, 1, 3, 1);

-- Insertar datos en la dimensión de producto
-- Se agregan 3 productos en 2 categorias para comparar comportamiento
INSERT INTO dim_producto (id_producto, nombre_producto, categoria, precio_lista) VALUES
    (1, 'Laptop Pro 14', 'Electronica', 12000.00),
    (2, 'Smart TV 50', 'Electronica', 9000.00),
    (3, 'Sofa Compacto', 'Hogar', 3500.00);

-- Insertar datos en la dimensión de tienda
-- Se agregan 2 tiendas en distintas ciudades
INSERT INTO dim_tienda (id_tienda, nombre_tienda, ciudad, region) VALUES
    (1, 'Tienda Central', 'Guatemala', 'Centro'),
    (2, 'Tienda Mixco', 'Mixco', 'Centro');

-- Insertar datos en la dimensión de cliente
-- Se agregan 2 clientes del segmento Retail
INSERT INTO dim_cliente (id_cliente, nombre_cliente, segmento) VALUES
    (1, 'Carlos Perez', 'Retail'),
    (2, 'Ana Gomez', 'Retail');

-- Insertar datos en la tabla de hechos
-- Cada fila representa una venta con su contexto (tiempo, producto, tienda, cliente)
INSERT INTO fact_ventas (id_tiempo, id_producto, id_tienda, id_cliente, cantidad, monto_total) VALUES
    (20250101, 1, 1, 1, 2, 24000.00),  -- 2 laptops vendidas en enero
    (20250201, 2, 2, 2, 1, 9000.00),   -- 1 TV vendida en febrero
    (20250301, 3, 1, 1, 3, 10500.00);  -- 3 sofas vendidos en marzo
```

Con estas inserciones ya puedes probar filtros por tiempo, comparaciones por categoría y resúmenes de ventas.

---

## 10. Consultas multidimensionales

Estas consultas muestran cómo analizar los datos desde diferentes perspectivas usando el modelo OLAP.

### a) Slice (corte por una dimensión)
Selecciona solo las ventas del año 2025:
Esta consulta aplica un filtro en una sola dimensión (tiempo) y mantiene visibles las demás dimensiones.
```sql
-- Mostrar ventas filtradas por anio, conservando detalle de mes y producto
SELECT t.anio, t.mes, p.nombre_producto, f.cantidad, f.monto_total
FROM fact_ventas f                              -- Tabla de hechos (medidas)
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une con dimension tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto -- Une con dimension producto
WHERE t.anio = 2025;  -- Filtro por año
```

El resultado muestra únicamente registros del año 2025.

### b) Dice (corte por varias dimensiones)
Ventas de productos electrónicos en la tienda Central:
Esta consulta filtra simultáneamente por categoría de producto y por tienda, creando un subconjunto más específico de análisis.
```sql
-- Resumen de ventas para una combinacion de filtros en 2 dimensiones
SELECT t.anio, ti.nombre_tienda, p.categoria, SUM(f.monto_total) AS total
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto
JOIN dim_tienda ti ON f.id_tienda = ti.id_tienda
WHERE p.categoria = 'Electronica' AND ti.nombre_tienda = 'Tienda Central' -- Filtro en multiples dimensiones
GROUP BY t.anio, ti.nombre_tienda, p.categoria; -- Agrupa para obtener total agregado
```

El resultado devuelve el total acumulado para esa combinación de filtros.

### c) Drill-down (detalle)
Ver ventas por año, mes y producto:
Aquí se baja a un nivel más detallado del resumen, pasando a ver los datos por mes y producto.
```sql
-- Detalle de ventas por jerarquia temporal y producto
SELECT t.anio, t.mes, p.nombre_producto, SUM(f.cantidad) AS total_vendido
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto
GROUP BY t.anio, t.mes, p.nombre_producto  -- Nivel de detalle del reporte
ORDER BY t.anio, t.mes, p.nombre_producto; -- Orden cronologico
```

El resultado permite ver el comportamiento de ventas con más granularidad.

### d) Roll-up (resumen)
Ventas totales por año:
En este caso se sube de nivel de detalle a un resumen general por año.
```sql
-- Resumen anual de ventas (menos detalle, mas sintesis)
SELECT t.anio, SUM(f.monto_total) AS total_anual
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo
GROUP BY t.anio; -- Agrupacion a nivel anual
```

El resultado muestra una fila por año con su total de ventas.

### e) Pivot (rotar vista)
Comparar ventas por producto y mes (meses como columnas):
Esta consulta rota la vista para que los meses aparezcan como columnas y sea más fácil comparar productos.
```sql
-- Pivot manual con CASE para convertir filas (meses) en columnas
SELECT nombre_producto,
    SUM(CASE WHEN t.mes = 1 THEN f.cantidad ELSE 0 END) AS Ene, -- Cantidad de enero
    SUM(CASE WHEN t.mes = 2 THEN f.cantidad ELSE 0 END) AS Feb, -- Cantidad de febrero
    SUM(CASE WHEN t.mes = 3 THEN f.cantidad ELSE 0 END) AS Mar  -- Cantidad de marzo
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto
GROUP BY nombre_producto; -- Una fila por producto
```

El resultado facilita la comparación horizontal entre meses para cada producto.

---

## 11. Agregación de datos

Las funciones de agregación permiten resumir información rápidamente. Ejemplos:

### a) Suma total de ventas
Esta consulta devuelve el monto acumulado de todas las ventas registradas.
```sql
SELECT SUM(monto_total) AS ventas_totales FROM fact_ventas;
```

### b) Promedio de monto por venta
Esta consulta calcula el valor promedio por registro de venta.
```sql
SELECT AVG(monto_total) AS promedio_venta FROM fact_ventas;
```

### c) Número de ventas registradas
Esta consulta cuenta cuántas filas existen en la tabla de hechos.
```sql
SELECT COUNT(*) AS cantidad_ventas FROM fact_ventas;
```

### d) Venta máxima y mínima
Esta consulta identifica el mayor y el menor monto registrados.
```sql
SELECT MAX(monto_total) AS venta_maxima, MIN(monto_total) AS venta_minima FROM fact_ventas;
```

Con estas funciones ya puedes construir indicadores básicos como total facturado, ticket promedio y extremos de venta.

---

