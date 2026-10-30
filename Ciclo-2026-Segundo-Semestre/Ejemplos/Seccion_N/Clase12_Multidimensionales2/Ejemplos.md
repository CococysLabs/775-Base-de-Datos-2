
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


# CONSULTAS AVANZADAS-----------------------------------------

---

## 12. Consultas avanzadas en cubos OLAP

Estas consultas usan operadores OLAP nativos en SQL Server para simular cubos con múltiples niveles de agregación.

### a) CUBE (todas las combinaciones de agregación)
Genera subtotales por año, categoría y región, además del total general.
```sql
-- CUBE genera subtotales por cada combinacion de dimensiones
SELECT
    t.anio,             -- Dimension tiempo
    p.categoria,        -- Dimension producto
    ti.region,          -- Dimension tienda
    SUM(f.monto_total) AS total -- Medida agregada
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto -- Une producto
JOIN dim_tienda ti ON f.id_tienda = ti.id_tienda -- Une tienda
GROUP BY CUBE (t.anio, p.categoria, ti.region) -- Subtotales y total general
ORDER BY t.anio, p.categoria, ti.region; -- Orden de lectura
```
Este bloque devuelve subtotales por todas las combinaciones de anio, categoria y region, ademas del total general.

### b) CUBE con etiquetas de subtotal
Identifica subtotales y total general con `GROUPING`.
```sql
-- GROUPING devuelve 1 cuando la columna es subtotal
SELECT
    CASE WHEN GROUPING(t.anio) = 1 THEN 'TOTAL' ELSE CAST(t.anio AS VARCHAR(10)) END AS anio, -- Etiqueta subtotal de anio
    CASE WHEN GROUPING(p.categoria) = 1 THEN 'TOTAL' ELSE p.categoria END AS categoria, -- Etiqueta subtotal de categoria
    SUM(f.monto_total) AS total -- Medida agregada
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto -- Une producto
GROUP BY CUBE (t.anio, p.categoria) -- Subtotales por anio, categoria y total
ORDER BY anio, categoria; -- Ordena para lectura
```
Este bloque etiqueta los subtotales con 'TOTAL' para distinguirlos de los niveles reales.

### c) GROUPING SETS (agregaciones controladas)
Devuelve solo los niveles que interesan (año, categoría y total general).
```sql
-- GROUPING SETS permite elegir niveles de agregacion
SELECT
    t.anio, -- Nivel tiempo
    p.categoria, -- Nivel producto
    SUM(f.monto_total) AS total -- Medida agregada
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto -- Une producto
GROUP BY GROUPING SETS (
    (t.anio, p.categoria), -- Detalle por anio y categoria
    (t.anio), -- Total por anio
    (p.categoria), -- Total por categoria
    () -- Total general
)
ORDER BY t.anio, p.categoria; -- Orden de lectura
```
Este bloque devuelve solo los niveles definidos en el GROUPING SETS (detalle, parciales y total).

---

## 13. Funciones de agregación y cálculo en OLAP

Además de SUM y AVG, en OLAP se calculan porcentajes, ratios y promedios ponderados para análisis más útil.

### a) Participación porcentual por categoría
Calcula el peso de cada categoría en el total anual.
```sql
-- Porcentaje de ventas por categoria dentro del anio
SELECT
    t.anio, -- Nivel tiempo
    p.categoria, -- Nivel producto
    SUM(f.monto_total) AS total_categoria, -- Total por categoria
    SUM(SUM(f.monto_total)) OVER (PARTITION BY t.anio) AS total_anio, -- Total anual
    CAST(
        100.0 * SUM(f.monto_total) /
        NULLIF(SUM(SUM(f.monto_total)) OVER (PARTITION BY t.anio), 0)
        AS DECIMAL(5,2)
    ) AS pct_anio -- Participacion porcentual
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto -- Une producto
GROUP BY t.anio, p.categoria;
```
Este bloque calcula el porcentaje de ventas de cada categoria dentro del anio.

### b) Precio promedio ponderado por producto
Útil cuando la cantidad vendida varía entre productos.
```sql
-- Precio promedio ponderado por producto
SELECT
    p.nombre_producto, -- Producto
    SUM(f.monto_total) AS ventas, -- Total vendido
    SUM(f.cantidad) AS unidades, -- Unidades vendidas
    CAST(SUM(f.monto_total) / NULLIF(SUM(f.cantidad), 0) AS DECIMAL(12,2)) AS precio_promedio -- Precio ponderado
FROM fact_ventas f
JOIN dim_producto p ON f.id_producto = p.id_producto -- Une producto
GROUP BY p.nombre_producto;
```
Este bloque calcula el precio promedio ponderado dividiendo ventas entre unidades.

### c) Participación de cada tienda en su región
Comparación relativa dentro de la misma región.
```sql
-- Porcentaje de una tienda dentro de su region
SELECT
    ti.region, -- Region
    ti.nombre_tienda, -- Tienda
    SUM(f.monto_total) AS total_tienda, -- Total tienda
    SUM(SUM(f.monto_total)) OVER (PARTITION BY ti.region) AS total_region, -- Total region
    CAST(
        100.0 * SUM(f.monto_total) /
        NULLIF(SUM(SUM(f.monto_total)) OVER (PARTITION BY ti.region), 0)
        AS DECIMAL(5,2)
    ) AS pct_region -- Participacion porcentual
FROM fact_ventas f
JOIN dim_tienda ti ON f.id_tienda = ti.id_tienda -- Une tienda
GROUP BY ti.region, ti.nombre_tienda;
```
Este bloque calcula la participacion de cada tienda dentro de su region.

---

## 14. Análisis de tendencias y proyecciones en OLAP

Con ventanas analíticas puedes detectar crecimiento y estimar el siguiente periodo.

### a) Tendencia mensual con crecimiento y promedio móvil
```sql
-- Tendencia mensual: crecimiento y promedio movil de 3 meses
WITH ventas_mes AS (
    SELECT
        t.anio, -- Nivel anio
        t.mes, -- Nivel mes
        SUM(f.monto_total) AS total_mes -- Total del mes
    FROM fact_ventas f
    JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une tiempo
    GROUP BY t.anio, t.mes
)
SELECT
    anio, -- Etiqueta anio
    mes, -- Etiqueta mes
    total_mes, -- Total del mes
    LAG(total_mes) OVER (ORDER BY anio, mes) AS total_mes_anterior, -- Total del mes previo
    CASE
        WHEN LAG(total_mes) OVER (ORDER BY anio, mes) IS NULL THEN NULL
        ELSE (total_mes - LAG(total_mes) OVER (ORDER BY anio, mes))
             / NULLIF(LAG(total_mes) OVER (ORDER BY anio, mes), 0)
    END AS crecimiento_mes, -- Variacion relativa mes a mes
    AVG(total_mes) OVER (
        ORDER BY anio, mes
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS promedio_3m -- Promedio movil de 3 meses
FROM ventas_mes
ORDER BY anio, mes;
```
Este bloque resume ventas mensuales, calcula el crecimiento mes a mes y el promedio movil de 3 meses.

### b) Proyección simple del siguiente mes
Usa el promedio de crecimiento de los 2 últimos meses y proyecta el próximo.
```sql
-- Proyeccion simple basada en el crecimiento reciente
WITH ventas_mes AS (
    SELECT
        t.anio, -- Nivel anio
        t.mes, -- Nivel mes
        SUM(f.monto_total) AS total_mes -- Total del mes
    FROM fact_ventas f
    JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une tiempo
    GROUP BY t.anio, t.mes
),
crec AS (
    SELECT
        anio, -- Etiqueta anio
        mes, -- Etiqueta mes
        total_mes, -- Total del mes
        (total_mes - LAG(total_mes) OVER (ORDER BY anio, mes))
            / NULLIF(LAG(total_mes) OVER (ORDER BY anio, mes), 0) AS crecimiento -- Crecimiento relativo
    FROM ventas_mes
),
crec_prom AS (
    SELECT AVG(crecimiento) AS crec_prom -- Promedio de crecimiento reciente
    FROM (
        SELECT TOP (2) crecimiento
        FROM crec
        WHERE crecimiento IS NOT NULL
        ORDER BY anio DESC, mes DESC
    ) ultimos
)
SELECT TOP (1)
    DATEADD(month, 1, DATEFROMPARTS(anio, mes, 1)) AS mes_proyectado, -- Siguiente mes
    total_mes * (1 + (SELECT crec_prom FROM crec_prom)) AS total_proyectado -- Proyeccion simple
FROM crec
ORDER BY anio DESC, mes DESC;
```
Este bloque estima el siguiente mes usando el crecimiento promedio de los dos ultimos meses.

---

## 15. Integración de OLAP con herramientas de BI

La práctica más común es exponer un modelo limpio con vistas y luego conectar Power BI o Tableau.

### a) Vista de consumo para BI
```sql
-- Vista con dimensiones y hechos en un solo dataset para BI
CREATE OR ALTER VIEW vw_ventas_olap AS
SELECT
    DATEFROMPARTS(t.anio, t.mes, t.dia) AS fecha, -- Fecha derivada para calendarios BI
    t.anio, -- Jerarquia tiempo
    t.trimestre, -- Jerarquia tiempo
    t.mes, -- Jerarquia tiempo
    p.id_producto, -- Atributo producto
    p.nombre_producto, -- Atributo producto
    p.categoria, -- Atributo producto
    ti.id_tienda, -- Atributo tienda
    ti.nombre_tienda, -- Atributo tienda
    ti.ciudad, -- Atributo tienda
    ti.region, -- Atributo tienda
    c.id_cliente, -- Atributo cliente
    c.nombre_cliente, -- Atributo cliente
    c.segmento, -- Atributo cliente
    f.cantidad, -- Medida
    f.monto_total -- Medida
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto -- Une producto
JOIN dim_tienda ti ON f.id_tienda = ti.id_tienda -- Une tienda
JOIN dim_cliente c ON f.id_cliente = c.id_cliente; -- Une cliente
GO
```
Este bloque crea una vista plana con dimensiones y medidas para consumo en BI.

Puedes validar la vista con:
```sql
SELECT TOP (10) * FROM vw_ventas_olap ORDER BY fecha; -- Muestra un sample para validar
```
Este bloque valida la vista con un muestreo rapido.

### b) Medidas típicas en Power BI (DAX)
```DAX
-- Suma total de ventas
Total Ventas = SUM(vw_ventas_olap[monto_total])
-- Ticket promedio por unidad
Ticket Promedio = DIVIDE([Total Ventas], SUM(vw_ventas_olap[cantidad]))
-- Ventas acumuladas en el anio
Ventas YTD = TOTALYTD([Total Ventas], vw_ventas_olap[fecha])
```
Estas medidas definen el total de ventas, el ticket promedio y el acumulado anual (YTD).

---

## 16. Optimización del rendimiento de cubos OLAP

Aquí tienes ejemplos de ajustes comunes para acelerar consultas analíticas.

### a) Indices para claves de dimensiones
```sql
-- Indice para mejorar joins con dimensiones
CREATE NONCLUSTERED INDEX ix_fact_ventas_fk
ON fact_ventas (id_tiempo, id_producto, id_tienda, id_cliente); -- Llaves usadas en joins
GO
```
Este bloque crea un indice para acelerar los joins con las dimensiones.

### b) Indice columnstore para agregaciones
Ideal cuando hay muchas consultas de suma y promedio.
```sql
-- Columnstore para acelerar agregaciones en la tabla de hechos
CREATE NONCLUSTERED COLUMNSTORE INDEX ix_fact_ventas_cs
ON fact_ventas (id_tiempo, id_producto, id_tienda, id_cliente, cantidad, monto_total); -- Columnas mas consultadas
GO
```
Este bloque crea un indice columnstore para acelerar agregaciones sobre la tabla de hechos.

### c) Tabla de agregados (precalculo)
```sql
-- Agregado mensual por categoria para consultas rapidas
IF OBJECT_ID('agg_ventas_mes_categoria', 'U') IS NULL
BEGIN
    SELECT
        t.anio, -- Nivel anio
        t.mes, -- Nivel mes
        p.categoria, -- Nivel categoria
        SUM(f.monto_total) AS total_mes -- Medida agregada
    INTO agg_ventas_mes_categoria
    FROM fact_ventas f
    JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une tiempo
    JOIN dim_producto p ON f.id_producto = p.id_producto -- Une producto
    GROUP BY t.anio, t.mes, p.categoria;

    CREATE INDEX ix_agg_ventas_mes_categoria
        ON agg_ventas_mes_categoria (anio, mes, categoria); -- Indice para consultas por periodo
END
GO
```
Este bloque crea una tabla de agregados mensuales por categoria y su indice si no existe.

---

## 17. Estrategias de almacenamiento en bases de datos multidimensionales

Estas estrategias definen donde y como se guardan los datos y agregados del cubo.

### a) ROLAP (Relational OLAP)
Los datos viven en tablas relacionales y se consultan con SQL (es el modelo que ya construiste).
```sql
-- Detalle a nivel transaccion (ROLAP)
SELECT t.anio, t.mes, p.nombre_producto, f.cantidad, f.monto_total -- Detalle con medidas
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto; -- Une producto
```
Este bloque muestra el detalle transaccional del modelo relacional (ROLAP).

### b) MOLAP (Multidimensional OLAP)
Los agregados se guardan precomputados en estructuras optimizadas (simulado aqui con una tabla resumen).
```sql
-- Resumen rapido (MOLAP simulado con tabla agregada)
SELECT anio, mes, categoria, total_mes -- Consulta sobre agregado precalculado
FROM agg_ventas_mes_categoria
ORDER BY anio, mes, categoria; -- Orden cronologico
```
Este bloque consulta el agregado precalculado para respuestas rapidas (MOLAP simulado).

### c) HOLAP (Hybrid OLAP)
Combina detalle relacional con agregados precalculados para velocidad y drill-down.
```sql
-- HOLAP: usar resumen para dashboards
SELECT anio, mes, categoria, total_mes -- Agregado rapido para BI
FROM agg_ventas_mes_categoria
WHERE anio = 2025;

-- HOLAP: usar detalle para bajar al nivel de producto
SELECT t.anio, t.mes, p.nombre_producto, SUM(f.cantidad) AS total_vendido -- Detalle para drill-down
FROM fact_ventas f
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo -- Une tiempo
JOIN dim_producto p ON f.id_producto = p.id_producto -- Une producto
WHERE t.anio = 2025 AND t.mes = 1
GROUP BY t.anio, t.mes, p.nombre_producto;
```
Este bloque usa primero el agregado para dashboards y luego el detalle para drill-down.

---

