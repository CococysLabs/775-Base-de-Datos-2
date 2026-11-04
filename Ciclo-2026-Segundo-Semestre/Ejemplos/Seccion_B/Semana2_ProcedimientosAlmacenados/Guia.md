# Laboratorio de Bases de Datos 2
## Procedimientos almacenados en SQL Server (T-SQL)

**Curso:** Bases de Datos 2 – Ingeniería en Sistemas
**Motor:** Microsoft SQL Server
**Base de datos:** `BD2S22026` (la misma de la sesión anterior)
**Prerrequisito:** haber creado las tablas `cliente`, `productos`, `venta` y `detalle_venta` con sus llaves foráneas.

> **Alcance de esta sesión:** procedimientos con parámetros, consultas, inserción, actualización, eliminación, validaciones y control de flujo. **No se usan transacciones** (`BEGIN TRAN`, `COMMIT`, `ROLLBACK`) ni `TRY...CATCH`: se verán en la siguiente sesión.

---

## 1. Objetivos de aprendizaje

Al finalizar este laboratorio el estudiante será capaz de:

1. Explicar qué es un procedimiento almacenado y qué ventajas ofrece.
2. Crear, ejecutar, modificar y eliminar procedimientos con `CREATE`, `EXEC`, `ALTER` y `DROP`.
3. Usar parámetros de entrada, valores por defecto y parámetros de salida (`OUTPUT`).
4. Validar datos antes de operar y reportar errores con `THROW`.
5. Implementar procedimientos de consulta y de manipulación de datos (`INSERT`, `UPDATE`, `DELETE`).
6. Identificar las limitaciones de ejecutar varios pasos sin transacciones.

---

## 2. Conceptos básicos

Un **procedimiento almacenado** (*stored procedure*) es un conjunto de sentencias T-SQL con nombre, guardado en la base de datos, que se compila y se ejecuta mediante una llamada.

### 2.1 Ventajas

| Ventaja | Explicación |
|---|---|
| **Reutilización** | La lógica se escribe una vez y se invoca desde cualquier aplicación. |
| **Rendimiento** | El plan de ejecución se almacena en caché y se reutiliza. |
| **Seguridad** | Se puede dar permiso de ejecutar el procedimiento sin dar acceso directo a las tablas. |
| **Mantenimiento** | Un cambio en la lógica se hace en un solo lugar. |
| **Menos tráfico** | La aplicación envía una llamada corta en lugar de varias sentencias. |
| **Protección** | Con parámetros se reduce el riesgo de inyección SQL. |

### 2.2 Sintaxis general

```sql
CREATE PROCEDURE nombre_procedimiento
    @parametro1 TIPO,
    @parametro2 TIPO = valor_por_defecto,
    @salida     TIPO OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- sentencias T-SQL
END;
GO
```

### 2.3 Convenciones de nombres usadas en este curso

| Elemento | Convención | Ejemplo |
|---|---|---|
| Procedimiento | prefijo `usp_` + entidad + acción | `usp_cliente_insertar` |
| Parámetro | prefijo `@` + nombre del campo | `@id_cliente` |
| Esquema | siempre explícito | `dbo.usp_cliente_insertar` |

> **Nota del tutor:** **no** use el prefijo `sp_`. SQL Server lo reserva para procedimientos del sistema y busca primero en la base `master`, lo que hace más lenta la resolución y puede causar conflictos.

---

## 3. Preparación

```sql
USE [BD2S22026];
GO
```

Si las tablas están vacías, cargue estos datos de prueba:

```sql
INSERT INTO cliente (id_cliente, nombre) VALUES
(1, 'Ana López'),
(2, 'Luis Pérez');

INSERT INTO productos (id_producto, nombre) VALUES
(1, 'Teclado'),
(2, 'Mouse'),
(3, 'Monitor');

INSERT INTO venta (id_cliente, fecha) VALUES
(1, '2026-03-10 09:15'),
(2, '2026-03-10 11:40'),
(1, '2026-03-11 16:05');

INSERT INTO detalle_venta (id_venta, id_producto, cantidad, sub_total) VALUES
(1, 1, 2,  300),
(1, 2, 1,   80),
(2, 3, 1, 1500),
(3, 2, 3,  240);
GO
```

> Si ya cuenta con los datos de la sesión anterior, omita este paso.

---

## 4. Primer procedimiento: sin parámetros

Lista todos los clientes ordenados por nombre.

```sql
CREATE PROCEDURE dbo.usp_cliente_listar
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_cliente, nombre
    FROM dbo.cliente
    ORDER BY nombre;
END;
GO
```

**Ejecución:**

```sql
EXEC dbo.usp_cliente_listar;
```

### ¿Qué hace `SET NOCOUNT ON`?

Evita que SQL Server envíe el mensaje "(n filas afectadas)" después de cada sentencia. Reduce tráfico de red y evita confusiones en aplicaciones cliente. Es buena práctica ponerlo al inicio de todo procedimiento.

---

## 5. Procedimientos con parámetros de entrada

Cada parámetro se declara con `@nombre TIPO`. Al ejecutar, se pueden pasar **por posición** o **por nombre** (recomendado).

```sql
CREATE PROCEDURE dbo.usp_venta_listar_por_cliente
    @id_cliente INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT v.id_venta,
           v.fecha,
           c.nombre AS cliente
    FROM dbo.venta v
    JOIN dbo.cliente c ON c.id_cliente = v.id_cliente
    WHERE v.id_cliente = @id_cliente
    ORDER BY v.fecha;
END;
GO
```

**Ejecución (dos formas equivalentes):**

```sql
EXEC dbo.usp_venta_listar_por_cliente 1;                    -- por posición
EXEC dbo.usp_venta_listar_por_cliente @id_cliente = 1;      -- por nombre (recomendado)
```

---

## 6. Parámetros con valor por defecto

Si un parámetro tiene valor por defecto, puede omitirse al llamar al procedimiento.

```sql
CREATE PROCEDURE dbo.usp_producto_mas_vendido
    @cantidad_top INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@cantidad_top)
           p.nombre,
           SUM(d.cantidad) AS unidades_vendidas
    FROM dbo.productos p
    JOIN dbo.detalle_venta d ON d.id_producto = p.id_producto
    GROUP BY p.nombre
    ORDER BY unidades_vendidas DESC;
END;
GO
```

```sql
EXEC dbo.usp_producto_mas_vendido;                       -- usa el valor por defecto (3)
EXEC dbo.usp_producto_mas_vendido @cantidad_top = 1;     -- solo el más vendido
```

---

## 7. Variables y control de flujo

Dentro de un procedimiento se pueden declarar variables con `DECLARE` y asignarlas con `SET` o `SELECT`.

```sql
DECLARE @contador INT;
SET @contador = (SELECT COUNT(*) FROM dbo.cliente);
```

### 7.1 Estructuras de control más usadas

| Estructura | Uso |
|---|---|
| `IF ... ELSE` | Decisiones condicionales |
| `IF EXISTS (SELECT ...)` | Verificar si existe al menos una fila |
| `WHILE` | Repetición |
| `CASE` | Valor condicional dentro de una consulta |
| `RETURN` | Terminar el procedimiento (opcionalmente con un código entero) |
| `BEGIN ... END` | Agrupar varias sentencias en un bloque |

### 7.2 Ejemplo con `CASE`: clasificar ventas por monto

```sql
CREATE PROCEDURE dbo.usp_venta_clasificar
AS
BEGIN
    SET NOCOUNT ON;

    SELECT v.id_venta,
           SUM(d.sub_total) AS total,
           CASE
               WHEN SUM(d.sub_total) >= 1000 THEN 'Alta'
               WHEN SUM(d.sub_total) >= 300  THEN 'Media'
               ELSE 'Baja'
           END AS clasificacion
    FROM dbo.venta v
    JOIN dbo.detalle_venta d ON d.id_venta = v.id_venta
    GROUP BY v.id_venta;
END;
GO
```

---

## 8. Parámetros de salida (`OUTPUT`)

Permiten que el procedimiento **devuelva un valor** al que lo llamó, además de (o en lugar de) un conjunto de filas.

```sql
CREATE PROCEDURE dbo.usp_venta_obtener_total
    @id_venta INT,
    @total    DECIMAL(10,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @total = ISNULL(SUM(sub_total), 0)
    FROM dbo.detalle_venta
    WHERE id_venta = @id_venta;
END;
GO
```

**Ejecución:** la variable receptora también debe llevar la palabra `OUTPUT`.

```sql
DECLARE @resultado DECIMAL(10,2);

EXEC dbo.usp_venta_obtener_total
     @id_venta = 1,
     @total    = @resultado OUTPUT;

SELECT @resultado AS total_venta_1;   -- 380
```

---

## 9. Validaciones y manejo de errores simple con `THROW`

Antes de insertar o modificar, se valida con `IF` / `IF EXISTS`. Cuando una regla no se cumple, se lanza un error con `THROW`.

```sql
THROW numero_error, 'mensaje', estado;
```

| Parte | Descripción |
|---|---|
| `numero_error` | Entero **mayor o igual a 50000** (rango de errores definidos por el usuario) |
| `mensaje` | Texto que verá quien ejecuta |
| `estado` | Entero entre 0 y 255 (se usa normalmente `1`) |

> **Importante:** `THROW` termina la ejecución del procedimiento y envía el error al cliente. La sentencia anterior a `THROW` debe terminar con punto y coma (`;`).

### 9.1 Convención de errores para este laboratorio

| Código | Significado |
|---|---|
| 50001 | El registro ya existe |
| 50002 | El registro no existe |
| 50003 | Dato inválido |
| 50004 | Operación no permitida por dependencias |

---

## 10. Procedimientos de inserción (`INSERT`)

### 10.1 Insertar cliente

La llave `id_cliente` **no** es `IDENTITY`, por lo que se recibe como parámetro.

```sql
CREATE PROCEDURE dbo.usp_cliente_insertar
    @id_cliente INT,
    @nombre     VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.cliente WHERE id_cliente = @id_cliente)
    BEGIN
        THROW 50001, 'Ya existe un cliente con ese identificador.', 1;
    END;

    IF EXISTS (SELECT 1 FROM dbo.cliente WHERE nombre = @nombre)
    BEGIN
        THROW 50001, 'Ya existe un cliente con ese nombre.', 1;
    END;

    INSERT INTO dbo.cliente (id_cliente, nombre)
    VALUES (@id_cliente, @nombre);
END;
GO
```

```sql
EXEC dbo.usp_cliente_insertar @id_cliente = 3, @nombre = 'María Gómez';   -- correcto
EXEC dbo.usp_cliente_insertar @id_cliente = 3, @nombre = 'Otro nombre';   -- error 50001
```

### 10.2 Insertar producto

```sql
CREATE PROCEDURE dbo.usp_producto_insertar
    @id_producto INT,
    @nombre      VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.productos
               WHERE id_producto = @id_producto OR nombre = @nombre)
    BEGIN
        THROW 50001, 'El producto ya existe (mismo id o mismo nombre).', 1;
    END;

    INSERT INTO dbo.productos (id_producto, nombre)
    VALUES (@id_producto, @nombre);
END;
GO
```

### 10.3 Insertar venta y devolver el ID generado

Como `id_venta` es `IDENTITY`, el valor lo genera SQL Server. Con `SCOPE_IDENTITY()` se obtiene el último identificador generado **en el ámbito actual** y se devuelve por un parámetro `OUTPUT`.

```sql
CREATE PROCEDURE dbo.usp_venta_insertar
    @id_cliente INT,
    @fecha      DATETIME = NULL,
    @id_venta   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE id_cliente = @id_cliente)
    BEGIN
        THROW 50002, 'El cliente indicado no existe.', 1;
    END;

    -- Si no se envía fecha, se usa la fecha y hora actuales
    IF @fecha IS NULL
        SET @fecha = GETDATE();

    INSERT INTO dbo.venta (id_cliente, fecha)
    VALUES (@id_cliente, @fecha);

    SET @id_venta = SCOPE_IDENTITY();
END;
GO
```

```sql
DECLARE @nueva_venta INT;

EXEC dbo.usp_venta_insertar
     @id_cliente = 2,
     @id_venta   = @nueva_venta OUTPUT;

SELECT @nueva_venta AS id_venta_generada;
```

> **Nota del tutor:** existen también `@@IDENTITY` e `IDENT_CURRENT('tabla')`. Se prefiere `SCOPE_IDENTITY()` porque no se ve afectado por *triggers* ni por inserciones de otras sesiones.

### 10.4 Agregar una línea de detalle

```sql
CREATE PROCEDURE dbo.usp_detalle_venta_insertar
    @id_venta    INT,
    @id_producto INT,
    @cantidad    INT,
    @sub_total   DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.venta WHERE id_venta = @id_venta)
    BEGIN
        THROW 50002, 'La venta indicada no existe.', 1;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.productos WHERE id_producto = @id_producto)
    BEGIN
        THROW 50002, 'El producto indicado no existe.', 1;
    END;

    IF @cantidad <= 0 OR @sub_total < 0
    BEGIN
        THROW 50003, 'La cantidad debe ser mayor que 0 y el sub total no puede ser negativo.', 1;
    END;

    INSERT INTO dbo.detalle_venta (id_venta, id_producto, cantidad, sub_total)
    VALUES (@id_venta, @id_producto, @cantidad, @sub_total);
END;
GO
```

### 10.5 Registrar una venta completa (usando los procedimientos anteriores)

Un procedimiento puede **llamar a otros procedimientos**.

```sql
DECLARE @id        INT;
DECLARE @resultado DECIMAL(10,2);

EXEC dbo.usp_venta_insertar @id_cliente = 1, @id_venta = @id OUTPUT;

EXEC dbo.usp_detalle_venta_insertar @id_venta = @id, @id_producto = 1, @cantidad = 1, @sub_total = 150;
EXEC dbo.usp_detalle_venta_insertar @id_venta = @id, @id_producto = 3, @cantidad = 1, @sub_total = 1500;

EXEC dbo.usp_venta_obtener_total @id_venta = @id, @total = @resultado OUTPUT;

SELECT @id AS id_venta, @resultado AS total;   -- total = 1650
```

### 10.6 ⚠️ Reflexión: ¿qué pasa si algo falla a la mitad?

Observe el punto 10.5: se ejecutan **tres pasos separados** (la venta y dos líneas de detalle). Si el segundo `usp_detalle_venta_insertar` falla (por ejemplo, un producto inexistente), la venta y la primera línea **ya quedaron guardadas**, dejando una venta incompleta.

Este problema se resuelve con **transacciones**, que garantizan que un grupo de sentencias se guarde completo o no se guarde nada. Se estudiarán en la **siguiente sesión**.

---

## 11. Procedimientos de actualización (`UPDATE`)

```sql
CREATE PROCEDURE dbo.usp_producto_actualizar
    @id_producto INT,
    @nombre      VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.productos WHERE id_producto = @id_producto)
    BEGIN
        THROW 50002, 'El producto indicado no existe.', 1;
    END;

    -- El nuevo nombre no puede pertenecer a OTRO producto (el nombre es UNIQUE)
    IF EXISTS (SELECT 1 FROM dbo.productos
               WHERE nombre = @nombre AND id_producto <> @id_producto)
    BEGIN
        THROW 50001, 'Ya existe otro producto con ese nombre.', 1;
    END;

    UPDATE dbo.productos
    SET nombre = @nombre
    WHERE id_producto = @id_producto;
END;
GO
```

```sql
EXEC dbo.usp_producto_actualizar @id_producto = 2, @nombre = 'Mouse inalámbrico';
```

> **Advertencia:** un `UPDATE` sin `WHERE` modifica **todas** las filas de la tabla. Verifique siempre la condición.

---

## 12. Procedimientos de eliminación (`DELETE`)

Un cliente con ventas registradas **no puede eliminarse** por la llave foránea `fk_cliente_venta`. En lugar de dejar que SQL Server devuelva su error genérico, se valida primero y se informa con un mensaje claro.

```sql
CREATE PROCEDURE dbo.usp_cliente_eliminar
    @id_cliente INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE id_cliente = @id_cliente)
    BEGIN
        THROW 50002, 'El cliente indicado no existe.', 1;
    END;

    IF EXISTS (SELECT 1 FROM dbo.venta WHERE id_cliente = @id_cliente)
    BEGIN
        THROW 50004, 'No se puede eliminar: el cliente tiene ventas registradas.', 1;
    END;

    DELETE FROM dbo.cliente
    WHERE id_cliente = @id_cliente;
END;
GO
```

```sql
EXEC dbo.usp_cliente_insertar @id_cliente = 10, @nombre = 'Cliente temporal';
EXEC dbo.usp_cliente_eliminar @id_cliente = 10;   -- se elimina
EXEC dbo.usp_cliente_eliminar @id_cliente = 1;    -- error 50004: tiene ventas
```

---

## 13. Códigos de retorno con `RETURN`

Además de `OUTPUT`, un procedimiento puede devolver un **entero** con `RETURN`. Por convención, `0` significa éxito.

```sql
CREATE PROCEDURE dbo.usp_cliente_existe
    @id_cliente INT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.cliente WHERE id_cliente = @id_cliente)
        RETURN 1;   -- existe

    RETURN 0;       -- no existe
END;
GO
```

```sql
DECLARE @codigo INT;
EXEC @codigo = dbo.usp_cliente_existe @id_cliente = 1;

IF @codigo = 1
    PRINT 'El cliente existe.';
ELSE
    PRINT 'El cliente NO existe.';
```

### Comparación: `OUTPUT` vs `RETURN` vs `SELECT`

| Mecanismo | Qué devuelve | Uso típico |
|---|---|---|
| `SELECT` | Un conjunto de filas | Consultas y reportes |
| `OUTPUT` | Valores de cualquier tipo | ID generado, totales, textos |
| `RETURN` | Un solo entero | Código de estado (éxito / tipo de resultado) |

---

## 14. Administración de procedimientos

### 14.1 Modificar con `ALTER`

```sql
ALTER PROCEDURE dbo.usp_cliente_listar
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_cliente, nombre
    FROM dbo.cliente
    ORDER BY id_cliente;     -- cambio: ahora ordena por id
END;
GO
```

> **Alternativa:** `CREATE OR ALTER PROCEDURE` (SQL Server 2016 SP1 o posterior) crea el procedimiento si no existe o lo modifica si ya existe. Es muy útil en scripts que se ejecutan varias veces.

### 14.2 Eliminar con `DROP`

```sql
DROP PROCEDURE dbo.usp_cliente_existe;

-- Versión segura (SQL Server 2016 o posterior)
DROP PROCEDURE IF EXISTS dbo.usp_cliente_existe;
```

### 14.3 Consultar los procedimientos existentes

```sql
-- Listar los procedimientos creados por el usuario
SELECT name, create_date, modify_date
FROM sys.procedures
ORDER BY name;

-- Ver el código fuente de un procedimiento
EXEC sp_helptext 'dbo.usp_cliente_insertar';

-- Ver los parámetros de un procedimiento
SELECT name, TYPE_NAME(user_type_id) AS tipo, is_output
FROM sys.parameters
WHERE object_id = OBJECT_ID('dbo.usp_venta_insertar');
```

### 14.4 Permisos

```sql
-- Permitir a un usuario ejecutar el procedimiento sin acceder a las tablas
GRANT EXECUTE ON dbo.usp_cliente_listar TO nombre_usuario;
```

---

## 15. Buenas prácticas

1. Iniciar siempre con `SET NOCOUNT ON;`.
2. Usar el **esquema explícito** (`dbo.tabla`) en todas las referencias.
3. **Validar antes de operar** y devolver mensajes claros.
4. Nombrar los parámetros igual que las columnas que representan.
5. Declarar el **tamaño** de los tipos (`VARCHAR(50)`, `DECIMAL(10,2)`), nunca `VARCHAR` o `DECIMAL` a secas.
6. No usar `SELECT *`; listar las columnas necesarias.
7. Evitar el prefijo `sp_`.
8. Comentar el propósito, los parámetros y el autor de cada procedimiento.
9. Cada procedimiento debe hacer **una sola cosa** y hacerla bien.
10. Probar los casos exitosos **y** los casos de error.

### Plantilla de documentación sugerida

```sql
/*
  Procedimiento : dbo.usp_cliente_insertar
  Descripción   : Registra un nuevo cliente validando que no esté duplicado.
  Parámetros    : @id_cliente INT        - identificador del cliente
                  @nombre     VARCHAR(50) - nombre del cliente
  Errores       : 50001 si el id o el nombre ya existen
  Autor / Fecha : (nombre del estudiante) / 2026-03-15
*/
```

---

## 16. Errores comunes de los estudiantes

| Error | Causa | Solución |
|---|---|---|
| `Must declare the scalar variable "@x"` | Variable usada sin `DECLARE` | Declararla antes de usarla |
| `Procedure expects parameter '@x'` | Falta un parámetro obligatorio | Enviarlo o darle valor por defecto |
| `There is already an object named...` | El procedimiento ya existe | Usar `ALTER` o `CREATE OR ALTER` |
| `Incorrect syntax near 'THROW'` | La línea anterior no termina en `;` | Agregar `;` |
| El `OUTPUT` regresa `NULL` | No se escribió `OUTPUT` al ejecutar | Poner `OUTPUT` también en la llamada |
| `UPDATE` o `DELETE` afecta todas las filas | Se olvidó el `WHERE` | Revisar siempre la condición |
| Total con decimales truncados | `DECIMAL` sin precisión | Usar `DECIMAL(10,2)` |

---

## 17. Ejercicios propuestos

**Nivel básico**

1. Cree `usp_producto_listar` que muestre todos los productos ordenados por nombre.
2. Cree `usp_cliente_buscar` que reciba un texto y devuelva los clientes cuyo nombre lo contenga (`LIKE`). Si el parámetro es `NULL`, debe devolver todos.
3. Cree `usp_producto_eliminar` que impida eliminar un producto que aparezca en algún detalle de venta.

**Nivel intermedio**

4. Cree `usp_venta_detalle` que reciba un `@id_venta` y muestre cada línea con el nombre del producto, la cantidad y el sub total, además del nombre del cliente y la fecha.
5. Cree `usp_ventas_por_rango` que reciba `@fecha_inicio` y `@fecha_fin` y devuelva las ventas con su total. Valide que la fecha de inicio no sea mayor que la final (error 50003).
6. Cree `usp_cliente_resumen` con un parámetro `OUTPUT` que devuelva la **cantidad de ventas** del cliente y otro que devuelva el **monto total** gastado.

**Nivel avanzado**

7. Cree `usp_detalle_venta_actualizar` que modifique la cantidad y el sub total de una línea, validando que la línea exista.
8. Cree un procedimiento que reciba un `@id_cliente` y una **lista de dos productos** (`@id_producto1`, `@cantidad1`, `@id_producto2`, `@cantidad2`) y registre la venta completa llamando a los procedimientos de la sección 10. Pruebe qué sucede cuando el segundo producto no existe y **anote qué datos quedaron en las tablas**. Esa observación será el punto de partida de la siguiente sesión.

---

## 18. Resumen

| Elemento | Sintaxis clave |
|---|---|
| Crear | `CREATE PROCEDURE` / `CREATE OR ALTER PROCEDURE` |
| Ejecutar | `EXEC nombre @p1 = valor` |
| Modificar | `ALTER PROCEDURE` |
| Eliminar | `DROP PROCEDURE [IF EXISTS]` |
| Parámetro de entrada | `@p INT` |
| Valor por defecto | `@p INT = 10` |
| Parámetro de salida | `@p INT OUTPUT` |
| Código de retorno | `RETURN n` |
| Error personalizado | `THROW 50001, 'mensaje', 1;` |
| Último ID generado | `SCOPE_IDENTITY()` |
| Evitar mensajes extra | `SET NOCOUNT ON;` |

### Adelanto de la próxima sesión

> Ya sabemos **crear** procedimientos que validan y modifican datos. Pero cuando una operación requiere **varios pasos que deben cumplirse todos o ninguno** (como registrar una venta con su detalle), necesitamos **transacciones**, `TRY...CATCH`, y el control de `COMMIT` y `ROLLBACK`.