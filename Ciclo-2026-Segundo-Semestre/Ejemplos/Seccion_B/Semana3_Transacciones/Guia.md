# Laboratorio de Bases de Datos 2
## Transacciones en SQL Server (T-SQL)

**Curso:** Bases de Datos 2 – Ingeniería en Sistemas
**Motor:** Microsoft SQL Server
**Base de datos:** `BD2S22026` (continuación de las sesiones de normalización y procedimientos almacenados)
**Prerrequisito:** tener creadas las tablas `cliente`, `productos`, `venta`, `detalle_venta` y los procedimientos `usp_venta_insertar`, `usp_detalle_venta_insertar` y `usp_venta_obtener_total` de la sesión anterior.

---

## 1. Objetivos de aprendizaje

Al finalizar este laboratorio el estudiante será capaz de:

1. Explicar qué es una transacción y las propiedades **ACID**.
2. Controlar transacciones explícitas con `BEGIN TRANSACTION`, `COMMIT` y `ROLLBACK`.
3. Manejar errores con `TRY...CATCH` y `SET XACT_ABORT ON`.
4. Usar `@@TRANCOUNT`, `XACT_STATE()` y puntos de guardado (`SAVE TRANSACTION`).
5. Incorporar transacciones dentro de procedimientos almacenados.
6. Describir los problemas de concurrencia, los niveles de aislamiento, los bloqueos y los *deadlocks*.

---

## 2. Retomando el problema de la sesión anterior

En la sesión de procedimientos se dejó este ejercicio: registrar una venta con dos productos, donde el segundo **no existe**.

```sql
DECLARE @id INT;

EXEC dbo.usp_venta_insertar @id_cliente = 1, @id_venta = @id OUTPUT;
EXEC dbo.usp_detalle_venta_insertar @id_venta = @id, @id_producto = 1,  @cantidad = 1, @sub_total = 150;
EXEC dbo.usp_detalle_venta_insertar @id_venta = @id, @id_producto = 99, @cantidad = 1, @sub_total = 500;  -- falla
```

Verifique lo que quedó guardado:

```sql
SELECT * FROM dbo.venta ORDER BY id_venta DESC;
SELECT * FROM dbo.detalle_venta WHERE id_venta = (SELECT MAX(id_venta) FROM dbo.venta);
```

**Resultado:** existe una venta con **una sola línea de detalle**. Los pasos 1 y 2 se guardaron y solo el 3 falló. La base de datos quedó en un estado **inconsistente**: se registró una compra incompleta.

> **Idea central de esta sesión:** necesitamos que un grupo de sentencias se comporte como **una sola unidad de trabajo**: o se ejecutan **todas**, o no se ejecuta **ninguna**.

### Limpieza antes de continuar

```sql
-- Eliminar la venta incompleta generada en la demostración
DELETE FROM dbo.detalle_venta WHERE id_venta = (SELECT MAX(id_venta) FROM dbo.venta);
DELETE FROM dbo.venta         WHERE id_venta = (SELECT MAX(id_venta) FROM dbo.venta);
```

---

## 3. ¿Qué es una transacción?

Una **transacción** es una unidad lógica de trabajo formada por una o más operaciones sobre la base de datos que se tratan como un bloque indivisible.

**Ejemplo clásico:** en una transferencia bancaria se resta dinero de la cuenta A y se suma a la cuenta B. Si solo ocurre una de las dos operaciones, el dinero desaparece o se duplica.

### 3.1 Propiedades ACID

| Propiedad | Significado | Ejemplo en nuestro modelo |
|---|---|---|
| **A**tomicidad | Todo o nada | La venta y todas sus líneas se guardan juntas o no se guarda ninguna. |
| **C**onsistencia | La base pasa de un estado válido a otro válido | Nunca queda una venta sin detalle ni un detalle sin venta. |
| **A**islamiento (*Isolation*) | Las transacciones simultáneas no se interfieren | Dos cajeros vendiendo al mismo tiempo no corrompen los datos. |
| **D**urabilidad | Lo confirmado persiste aunque el servidor falle | Tras `COMMIT`, la venta sobrevive a un apagón (gracias al registro de transacciones). |

### 3.2 Modos de transacción en SQL Server

| Modo | Cómo funciona |
|---|---|
| **Autocommit** (por defecto) | Cada sentencia es su propia transacción: se confirma sola. Es lo que veníamos usando. |
| **Explícita** | El programador define el inicio y el fin con `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK`. **Es el foco de esta sesión.** |
| **Implícita** | Con `SET IMPLICIT_TRANSACTIONS ON`, la primera sentencia abre una transacción que debe cerrarse manualmente. Se usa poco en SQL Server. |

---

## 4. Sentencias básicas

| Sentencia | Función |
|---|---|
| `BEGIN TRANSACTION` (o `BEGIN TRAN`) | Inicia una transacción explícita. |
| `COMMIT TRANSACTION` | Confirma los cambios de forma permanente. |
| `ROLLBACK TRANSACTION` | Deshace todos los cambios desde el inicio de la transacción. |
| `SAVE TRANSACTION nombre` | Crea un punto de guardado dentro de la transacción. |
| `@@TRANCOUNT` | Función que devuelve el nivel de anidamiento de transacciones abiertas. |

### 4.1 Ejemplo 1: `ROLLBACK`

```sql
SELECT COUNT(*) AS clientes_antes FROM dbo.cliente;

BEGIN TRANSACTION;

    INSERT INTO dbo.cliente (id_cliente, nombre) VALUES (50, 'Cliente de prueba');

    SELECT COUNT(*)     AS clientes_dentro FROM dbo.cliente;   -- ve el nuevo cliente
    SELECT @@TRANCOUNT  AS transacciones_abiertas;             -- 1

ROLLBACK TRANSACTION;

SELECT COUNT(*) AS clientes_despues FROM dbo.cliente;          -- igual que "antes"
SELECT @@TRANCOUNT AS transacciones_abiertas;                  -- 0
```

### 4.2 Ejemplo 2: `COMMIT`

```sql
BEGIN TRANSACTION;

    INSERT INTO dbo.cliente (id_cliente, nombre) VALUES (50, 'Cliente de prueba');

COMMIT TRANSACTION;

SELECT * FROM dbo.cliente WHERE id_cliente = 50;   -- el registro permanece

-- Limpieza
DELETE FROM dbo.cliente WHERE id_cliente = 50;
```

> **Advertencia del tutor:** si ejecuta `BEGIN TRANSACTION` y **olvida** el `COMMIT` o el `ROLLBACK`, la transacción queda abierta, mantiene **bloqueos** sobre las tablas y otros usuarios quedarán esperando. En el laboratorio, si una consulta "se queda pegada", revise `SELECT @@TRANCOUNT;` y cierre con `ROLLBACK`.

---

## 5. Manejo de errores con `TRY...CATCH`

Aprendimos que un error dentro de un procedimiento detiene la ejecución, pero **no deshace automáticamente** lo que ya se hizo. `TRY...CATCH` permite interceptar el error y decidir qué hacer.

### 5.1 Estructura

```sql
BEGIN TRY
    -- sentencias que pueden fallar
END TRY
BEGIN CATCH
    -- qué hacer si ocurre un error
END CATCH;
```

Si algo dentro de `TRY` produce un error, la ejecución salta de inmediato al bloque `CATCH`.

### 5.2 Funciones para obtener información del error

Solo funcionan dentro de un bloque `CATCH`.

| Función | Devuelve |
|---|---|
| `ERROR_NUMBER()` | Número del error (por ejemplo 547 para violación de FK, 50001 para uno propio) |
| `ERROR_MESSAGE()` | Texto del error |
| `ERROR_SEVERITY()` | Nivel de gravedad |
| `ERROR_STATE()` | Estado del error |
| `ERROR_PROCEDURE()` | Procedimiento donde ocurrió |
| `ERROR_LINE()` | Línea donde ocurrió |

### 5.3 Patrón estándar: transacción + `TRY...CATCH`

```sql
BEGIN TRY
    BEGIN TRANSACTION;

        -- operaciones de modificación

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;   -- vuelve a lanzar el error original hacia quien llamó
END CATCH;
```

**Puntos clave del patrón:**

1. El `BEGIN TRANSACTION` va **dentro** del `TRY`.
2. En el `CATCH` se pregunta `IF @@TRANCOUNT > 0` antes de hacer `ROLLBACK` (puede que no haya transacción abierta).
3. `THROW;` (sin parámetros) **relanza** el error original. Solo puede usarse dentro de `CATCH`.

### 5.4 Ejemplo 3: inserción doble con error

```sql
BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO dbo.cliente (id_cliente, nombre) VALUES (60, 'Carlos Ruiz');
        INSERT INTO dbo.cliente (id_cliente, nombre) VALUES (61, 'Carlos Ruiz');  -- error: nombre UNIQUE duplicado

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT ERROR_NUMBER()  AS numero,
           ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT * FROM dbo.cliente WHERE id_cliente IN (60, 61);   -- 0 filas: el primer INSERT también se deshizo
```

La primera inserción era válida, pero como la segunda falló, `ROLLBACK` deshizo ambas: **atomicidad en acción**.

---

## 6. `SET XACT_ABORT ON`

Algunos errores de ejecución no cancelan la transacción por sí solos; el proceso puede continuar con la transacción abierta y a medias. Con `XACT_ABORT ON`, **cualquier error de ejecución cancela la transacción completa** y la deja lista para el `ROLLBACK`.

```sql
SET XACT_ABORT ON;
```

**Recomendación para el curso:** use `SET XACT_ABORT ON;` al inicio de todo procedimiento que maneje transacciones, junto con `TRY...CATCH`.

### 6.1 `XACT_STATE()`

Dentro del `CATCH`, indica si la transacción todavía puede confirmarse.

| Valor | Significado | Qué hacer |
|---|---|---|
| `1` | Hay transacción activa y confirmable | Puede hacer `COMMIT` o `ROLLBACK` |
| `0` | No hay transacción activa | No hacer nada |
| `-1` | Hay transacción, pero está **condenada** (*uncommittable*) | Solo se puede hacer `ROLLBACK` |

```sql
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

> Para este curso, `IF @@TRANCOUNT > 0` y `IF XACT_STATE() <> 0` son equivalentes en la práctica. Usaremos `@@TRANCOUNT` por claridad.

---

## 7. Transacciones anidadas y `@@TRANCOUNT`

Cuando se ejecuta `BEGIN TRANSACTION` dentro de otra transacción, SQL Server no crea una nueva transacción independiente: solo **incrementa un contador**.

```sql
SELECT @@TRANCOUNT AS nivel;          -- 0

BEGIN TRANSACTION;                    -- nivel 1
    SELECT @@TRANCOUNT AS nivel;      -- 1

    BEGIN TRANSACTION;                -- nivel 2
        SELECT @@TRANCOUNT AS nivel;  -- 2
    COMMIT TRANSACTION;               -- baja a nivel 1 (aún NO se confirma nada)

    SELECT @@TRANCOUNT AS nivel;      -- 1
COMMIT TRANSACTION;                   -- baja a nivel 0: aquí sí se confirma todo

SELECT @@TRANCOUNT AS nivel;          -- 0
```

### Reglas importantes

| Regla | Explicación |
|---|---|
| Cada `COMMIT` resta 1 al contador | Los cambios solo se confirman cuando el contador llega a **0**. |
| Un `ROLLBACK` sin nombre **deshace todo** y deja el contador en 0 | No importa cuántos niveles haya. |
| Los `COMMIT` internos **no** confirman nada por sí solos | Solo el más externo es el definitivo. |

### 7.1 ¿Por qué importa en procedimientos?

Un procedimiento con transacción puede ser llamado desde otro que **ya abrió** una transacción. Si el procedimiento interno hace `ROLLBACK`, deshará **todo**, incluyendo el trabajo del procedimiento externo. Por eso, en aplicaciones reales se acostumbra definir quién es "dueño" de la transacción. En este curso la regla será:

> **Los procedimientos "de operación completa" (como registrar una venta) abren la transacción. Los procedimientos "pequeños" (como insertar un detalle) no la abren.**

---

## 8. Puntos de guardado (`SAVE TRANSACTION`)

Permiten deshacer **solo una parte** de la transacción.

```sql
BEGIN TRANSACTION;

    INSERT INTO dbo.cliente (id_cliente, nombre) VALUES (70, 'Cliente A');

    SAVE TRANSACTION punto_a;

    INSERT INTO dbo.cliente (id_cliente, nombre) VALUES (71, 'Cliente B');

    ROLLBACK TRANSACTION punto_a;     -- deshace solo "Cliente B"

COMMIT TRANSACTION;                    -- confirma "Cliente A"

SELECT * FROM dbo.cliente WHERE id_cliente IN (70, 71);   -- solo existe el 70

-- Limpieza
DELETE FROM dbo.cliente WHERE id_cliente = 70;
```

---

## 9. Transacciones dentro de procedimientos almacenados

### 9.1 Registrar una venta completa (solución al problema del punto 2)

Este procedimiento recibe el cliente y **dos productos** y registra la venta y sus líneas como una sola unidad.

```sql
CREATE OR ALTER PROCEDURE dbo.usp_venta_registrar_completa
    @id_cliente   INT,
    @id_producto1 INT,
    @cantidad1    INT,
    @sub_total1   DECIMAL(10,2),
    @id_producto2 INT,
    @cantidad2    INT,
    @sub_total2   DECIMAL(10,2),
    @id_venta     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            EXEC dbo.usp_venta_insertar
                 @id_cliente = @id_cliente,
                 @id_venta   = @id_venta OUTPUT;

            EXEC dbo.usp_detalle_venta_insertar
                 @id_venta = @id_venta, @id_producto = @id_producto1,
                 @cantidad = @cantidad1, @sub_total  = @sub_total1;

            EXEC dbo.usp_detalle_venta_insertar
                 @id_venta = @id_venta, @id_producto = @id_producto2,
                 @cantidad = @cantidad2, @sub_total  = @sub_total2;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @id_venta = NULL;   -- la venta no existe: no devolver un ID engañoso
        THROW;
    END CATCH;
END;
GO
```

**Prueba con datos válidos:**

```sql
DECLARE @id INT;

EXEC dbo.usp_venta_registrar_completa
     @id_cliente = 1,
     @id_producto1 = 1, @cantidad1 = 1, @sub_total1 = 150,
     @id_producto2 = 2, @cantidad2 = 2, @sub_total2 = 160,
     @id_venta = @id OUTPUT;

SELECT @id AS id_venta_generada;
SELECT * FROM dbo.detalle_venta WHERE id_venta = @id;   -- 2 líneas
```

**Prueba con un producto inexistente (debe fallar sin dejar rastro):**

```sql
DECLARE @id INT;

SELECT COUNT(*) AS ventas_antes   FROM dbo.venta;
SELECT COUNT(*) AS detalles_antes FROM dbo.detalle_venta;

EXEC dbo.usp_venta_registrar_completa
     @id_cliente = 1,
     @id_producto1 = 1,  @cantidad1 = 1, @sub_total1 = 150,
     @id_producto2 = 99, @cantidad2 = 1, @sub_total2 = 500,   -- no existe
     @id_venta = @id OUTPUT;
-- Error 50002: El producto indicado no existe.

SELECT COUNT(*) AS ventas_despues   FROM dbo.venta;           -- igual que antes
SELECT COUNT(*) AS detalles_despues FROM dbo.detalle_venta;   -- igual que antes
```

> **Comparar con el punto 2:** ahora el fallo del segundo producto deshace la venta y la primera línea. Los conteos no cambian.

### 9.2 Observación: el `IDENTITY` no se revierte

Después de la prueba fallida, registre una venta correcta y observe su `id_venta`: habrá un **salto** en la numeración.

```sql
SELECT id_venta FROM dbo.venta ORDER BY id_venta;
```

Los valores `IDENTITY` ya consumidos **no se devuelven** con `ROLLBACK`. Es normal y esperado: no use `IDENTITY` para garantizar números consecutivos sin huecos (por ejemplo, números de factura).

### 9.3 Anular una venta (eliminar detalle y encabezado)

Hay que borrar primero las tablas hijas y luego la madre. Si se borrara solo una, la base quedaría inconsistente.

```sql
CREATE OR ALTER PROCEDURE dbo.usp_venta_anular
    @id_venta INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.venta WHERE id_venta = @id_venta)
        BEGIN
            THROW 50002, 'La venta indicada no existe.', 1;
        END;

        BEGIN TRANSACTION;

            DELETE FROM dbo.detalle_venta WHERE id_venta = @id_venta;
            DELETE FROM dbo.venta         WHERE id_venta = @id_venta;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
```

```sql
EXEC dbo.usp_venta_anular @id_venta = 3;
```

---

## 10. Caso práctico: venta con control de inventario

Para ver el valor real de las transacciones, agregamos existencias a los productos.

### 10.1 Modificar el modelo

```sql
ALTER TABLE dbo.productos
ADD stock INT NOT NULL CONSTRAINT df_productos_stock DEFAULT 100;
GO

ALTER TABLE dbo.productos
ADD CONSTRAINT ck_productos_stock CHECK (stock >= 0);
GO

SELECT * FROM dbo.productos;
```

La restricción `CHECK` impide que el inventario sea negativo.

### 10.2 Procedimiento de venta de un producto con descuento de inventario

```sql
CREATE OR ALTER PROCEDURE dbo.usp_vender_producto
    @id_cliente  INT,
    @id_producto INT,
    @cantidad    INT,
    @sub_total   DECIMAL(10,2),
    @id_venta    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @cantidad <= 0
        BEGIN
            THROW 50003, 'La cantidad debe ser mayor que 0.', 1;
        END;

        BEGIN TRANSACTION;

            -- 1) Descontar inventario solo si alcanza (la condición va en el WHERE)
            UPDATE dbo.productos
            SET stock = stock - @cantidad
            WHERE id_producto = @id_producto
              AND stock >= @cantidad;

            IF @@ROWCOUNT = 0
            BEGIN
                THROW 50003, 'Producto inexistente o stock insuficiente.', 1;
            END;

            -- 2) Registrar encabezado y detalle
            EXEC dbo.usp_venta_insertar
                 @id_cliente = @id_cliente,
                 @id_venta   = @id_venta OUTPUT;

            EXEC dbo.usp_detalle_venta_insertar
                 @id_venta    = @id_venta,
                 @id_producto = @id_producto,
                 @cantidad    = @cantidad,
                 @sub_total   = @sub_total;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @id_venta = NULL;
        THROW;
    END CATCH;
END;
GO
```

### 10.3 Pruebas

```sql
DECLARE @id INT;

-- Venta válida: baja el stock del producto 1 en 5 unidades
EXEC dbo.usp_vender_producto
     @id_cliente = 1, @id_producto = 1, @cantidad = 5, @sub_total = 750,
     @id_venta = @id OUTPUT;

SELECT id_producto, nombre, stock FROM dbo.productos WHERE id_producto = 1;   -- 95

-- Venta imposible: pide más de lo que hay
EXEC dbo.usp_vender_producto
     @id_cliente = 1, @id_producto = 1, @cantidad = 500, @sub_total = 75000,
     @id_venta = @id OUTPUT;                                                  -- error 50003

SELECT id_producto, nombre, stock FROM dbo.productos WHERE id_producto = 1;   -- sigue en 95
```

> **Nota del tutor:** el `UPDATE ... WHERE stock >= @cantidad` hace la verificación y el descuento en **una sola sentencia atómica**. Es preferible a leer el stock con un `SELECT`, compararlo, y luego hacer el `UPDATE`, porque entre el `SELECT` y el `UPDATE` otro usuario podría haber vendido el mismo producto (ver sección 11).

---

## 11. Concurrencia: cuando varios usuarios trabajan a la vez

### 11.1 Problemas de concurrencia

| Problema | Descripción | Ejemplo |
|---|---|---|
| **Lectura sucia** (*dirty read*) | Se lee un dato **no confirmado** de otra transacción | A cambia el stock a 50 sin confirmar, B lee 50, A hace `ROLLBACK`: B usó un dato que nunca existió. |
| **Lectura no repetible** (*non-repeatable read*) | Dos lecturas de la misma fila en una transacción dan valores distintos | B lee el stock (100), A lo modifica y confirma, B lo vuelve a leer (95). |
| **Lectura fantasma** (*phantom read*) | Dos consultas con el mismo filtro devuelven distinta cantidad de filas | B cuenta las ventas del día (3), A inserta otra y confirma, B cuenta de nuevo (4). |
| **Actualización perdida** (*lost update*) | Dos transacciones leen el mismo valor y ambas lo sobrescriben | A y B leen stock = 100; A guarda 95; B guarda 90. Se perdió la venta de A. |

### 11.2 Niveles de aislamiento

Se configuran por sesión con `SET TRANSACTION ISOLATION LEVEL`.

| Nivel | Lectura sucia | No repetible | Fantasma | Comentario |
|---|:---:|:---:|:---:|---|
| `READ UNCOMMITTED` | Sí | Sí | Sí | Máxima velocidad, mínima seguridad. Equivale a `WITH (NOLOCK)`. |
| `READ COMMITTED` (**por defecto**) | No | Sí | Sí | Solo lee datos confirmados. |
| `REPEATABLE READ` | No | No | Sí | Bloquea las filas leídas hasta terminar. |
| `SERIALIZABLE` | No | No | No | El más estricto; bloquea rangos. Menor concurrencia. |
| `SNAPSHOT` | No | No | No | Usa versiones de filas en lugar de bloqueos. Requiere habilitarse en la base de datos. |

```sql
-- Consultar el nivel actual de la sesión
DBCC USEROPTIONS;

-- Cambiarlo
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

### 11.3 Bloqueos (*locks*)

Para aislar las transacciones, SQL Server coloca **bloqueos** sobre los datos:

| Tipo | Se usa en… | Compatibilidad |
|---|---|---|
| **Compartido (S)** | Lecturas | Varios lectores a la vez |
| **Exclusivo (X)** | `INSERT`, `UPDATE`, `DELETE` | Nadie más puede leer (en `READ COMMITTED`) ni modificar ese dato |

Si una transacción necesita un dato bloqueado por otra, **espera** (esto se llama *bloqueo* o *blocking*) hasta que la otra termine.

---

## 12. Práctica con dos sesiones

Estas prácticas requieren abrir **dos ventanas de consulta** en SSMS conectadas a la misma base (se les llamará **Sesión A** y **Sesión B**).

### 12.1 Práctica 1: bloqueo y espera (*blocking*)

**Sesión A:**

```sql
USE BD2S22026;
BEGIN TRANSACTION;
    UPDATE dbo.productos SET stock = stock - 1 WHERE id_producto = 2;
-- NO ejecutar COMMIT todavía
```

**Sesión B:**

```sql
USE BD2S22026;
SELECT * FROM dbo.productos WHERE id_producto = 2;
-- La consulta queda esperando (la fila tiene bloqueo exclusivo de A)
```

**Sesión A:**

```sql
COMMIT TRANSACTION;
-- En la Sesión B, la consulta termina inmediatamente
```

**Preguntas:** ¿por qué B esperó? ¿Qué habría pasado si A hacía `ROLLBACK`? ¿Qué valor de stock vio B?

### 12.2 Práctica 2: lectura sucia

**Sesión A:**

```sql
BEGIN TRANSACTION;
    UPDATE dbo.productos SET stock = 5 WHERE id_producto = 2;
```

**Sesión B:**

```sql
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT id_producto, stock FROM dbo.productos WHERE id_producto = 2;   -- ve 5 (dato sin confirmar)
```

**Sesión A:**

```sql
ROLLBACK TRANSACTION;
```

**Sesión B:**

```sql
SELECT id_producto, stock FROM dbo.productos WHERE id_producto = 2;   -- vuelve al valor real
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;                        -- restaurar
```

**Conclusión:** la Sesión B tomó una decisión con un dato que **nunca existió**.

### 12.3 Práctica 3: lectura no repetible vs. `REPEATABLE READ`

**Sesión B:**

```sql
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
    SELECT stock FROM dbo.productos WHERE id_producto = 2;   -- primera lectura
```

**Sesión A:**

```sql
UPDATE dbo.productos SET stock = stock - 10 WHERE id_producto = 2;   -- se ejecuta sin esperar
```

**Sesión B:**

```sql
    SELECT stock FROM dbo.productos WHERE id_producto = 2;   -- valor distinto: lectura no repetible
COMMIT TRANSACTION;
```

Repita la práctica cambiando la Sesión B a `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;` y observe que ahora el `UPDATE` de la Sesión A **queda esperando** hasta que B termine.

### 12.4 Práctica 4: *deadlock* (interbloqueo)

Un *deadlock* ocurre cuando dos transacciones se bloquean mutuamente, cada una esperando un recurso que tiene la otra. SQL Server detecta la situación y **cancela a una de ellas** (la "víctima") con el **error 1205**.

**Sesión A:**

```sql
BEGIN TRANSACTION;
    UPDATE dbo.cliente SET nombre = nombre WHERE id_cliente = 1;   -- bloquea cliente
    WAITFOR DELAY '00:00:10';                                       -- espera 10 s
    UPDATE dbo.productos SET stock = stock WHERE id_producto = 1;  -- quiere productos
COMMIT TRANSACTION;
```

**Sesión B** (ejecutar de inmediato, dentro de los 10 segundos):

```sql
BEGIN TRANSACTION;
    UPDATE dbo.productos SET stock = stock WHERE id_producto = 1;  -- bloquea productos
    WAITFOR DELAY '00:00:10';
    UPDATE dbo.cliente SET nombre = nombre WHERE id_cliente = 1;   -- quiere cliente
COMMIT TRANSACTION;
```

**Resultado:** una de las sesiones recibe el mensaje *"Transaction was deadlocked on lock resources with another process and has been chosen as the deadlock victim"* (error 1205) y su transacción se deshace.

> Si una sesión queda con la transacción abierta, ejecute `ROLLBACK;` en ella antes de continuar.

**¿Cómo se previenen?**

1. Acceder a las tablas **siempre en el mismo orden** en todos los procedimientos.
2. Mantener las transacciones **lo más cortas posible**.
3. No dejar interacción con el usuario dentro de una transacción.
4. Usar el nivel de aislamiento más bajo que sea seguro para la operación.
5. Controlar el error 1205 en la aplicación y **reintentar** la operación.

### 12.5 (Opcional) Práctica 5: `SNAPSHOT`

```sql
ALTER DATABASE BD2S22026 SET ALLOW_SNAPSHOT_ISOLATION ON;
```

Repita la práctica 1 con la Sesión B usando `SET TRANSACTION ISOLATION LEVEL SNAPSHOT;` y observe que **ya no espera**: lee la versión anterior (confirmada) de la fila. Es útil para reportes que no deben bloquear a quienes venden.

---

## 13. Buenas prácticas

1. **Mantenga las transacciones cortas:** abra la transacción lo más tarde posible y ciérrela lo más pronto posible.
2. **Valide antes de abrir la transacción** (por ejemplo, parámetros inválidos), para no bloquear recursos innecesariamente.
3. Use siempre el patrón: `SET XACT_ABORT ON` + `TRY...CATCH` + `IF @@TRANCOUNT > 0 ROLLBACK` + `THROW;`.
4. Agrupe en una transacción **solo** las operaciones que deben ser atómicas.
5. Defina quién es el "dueño" de la transacción cuando hay procedimientos que se llaman entre sí.
6. Acceda a las tablas **en el mismo orden** para reducir *deadlocks*.
7. Nunca deje una transacción abierta al terminar un script.
8. No use `READ UNCOMMITTED` / `NOLOCK` para operaciones que dependan de la exactitud de los datos.
9. Pruebe siempre el **camino de error**, no solo el camino feliz.

---

## 14. Errores comunes de los estudiantes

| Error | Causa | Solución |
|---|---|---|
| Consultas que "se quedan pegadas" | Transacción abierta en otra ventana | `SELECT @@TRANCOUNT;` y luego `COMMIT` o `ROLLBACK` |
| `Transaction count after EXECUTE indicates a mismatching number of BEGIN and COMMIT statements` | Un procedimiento abre y no cierra, o hace `ROLLBACK` dentro de otro con transacción | Revisar que cada `BEGIN TRAN` tenga su cierre y definir quién abre la transacción |
| `Cannot roll back... No transaction or savepoint of that name was found` | Se hace `ROLLBACK` sin transacción activa | Preguntar `IF @@TRANCOUNT > 0` antes |
| `The current transaction cannot be committed...` | Transacción condenada (`XACT_STATE() = -1`) | Solo hacer `ROLLBACK` |
| `THROW` sin parámetros fuera de `CATCH` | Solo se permite dentro de `CATCH` | Usar `THROW número, 'mensaje', estado;` |
| El `IDENTITY` tiene saltos | El valor se consumió antes del `ROLLBACK` | Es normal; no depender de números consecutivos |
| Transacción demasiado grande | Se incluyó lógica que no requiere atomicidad | Acortar la transacción |

---

## 15. Ejercicios propuestos

**Nivel básico**

1. Escriba un script con `BEGIN TRANSACTION` que inserte dos clientes, muestre `@@TRANCOUNT` y termine con `ROLLBACK`. Compruebe que no quedaron registrados.
2. Repita el ejercicio 1 con `COMMIT` y luego elimine los registros de prueba.
3. Modifique el ejemplo 3 (sección 5.4) para que, en el `CATCH`, imprima el número, el mensaje y la línea del error.

**Nivel intermedio**

4. Cree `usp_cliente_insertar_dos` que reciba los datos de dos clientes y los inserte en una transacción. Pruebe con nombres repetidos.
5. Cree `usp_venta_anular_con_stock` que, al anular una venta, **devuelva las cantidades al stock** de cada producto antes de borrar el detalle y el encabezado, todo en una transacción. *(Pista: `UPDATE productos SET stock = stock + d.cantidad FROM productos p JOIN detalle_venta d ON ...`.)*
6. Modifique `usp_venta_registrar_completa` para que **también descuente el stock** de ambos productos. Pruebe un caso donde el segundo producto no tenga stock suficiente y verifique que el stock del primero **no cambió**.

**Nivel avanzado**

7. Cree `usp_producto_trasladar_stock` que reciba dos productos y una cantidad y traslade existencias del primero al segundo (como si fueran presentaciones intercambiables). Debe fallar sin cambios si el origen no tiene suficiente.
8. Diseñe y ejecute un escenario de *deadlock* distinto al de la práctica 4, usando `venta` y `detalle_venta`. Explique el orden de bloqueos y proponga cómo evitarlo.
9. Con dos sesiones, demuestre una **actualización perdida** (leer el stock con `SELECT`, esperar con `WAITFOR DELAY` y luego escribir un valor calculado). Luego corríjala con el `UPDATE ... SET stock = stock - @cantidad WHERE stock >= @cantidad` de la sección 10.
10. Cree un procedimiento que reintente hasta 3 veces una operación si ocurre el error 1205. *(Pista: `CATCH` con `ERROR_NUMBER() = 1205`, un `WHILE` y `WAITFOR DELAY`.)*

---

## 16. Resumen

| Concepto | Sintaxis / idea clave |
|---|---|
| Iniciar | `BEGIN TRANSACTION` |
| Confirmar | `COMMIT TRANSACTION` |
| Deshacer | `ROLLBACK TRANSACTION` |
| Punto de guardado | `SAVE TRANSACTION nombre` / `ROLLBACK TRANSACTION nombre` |
| Contador de transacciones | `@@TRANCOUNT` |
| Estado de la transacción | `XACT_STATE()` (1, 0, -1) |
| Cancelar todo ante un error | `SET XACT_ABORT ON` |
| Manejo de errores | `BEGIN TRY ... END TRY BEGIN CATCH ... END CATCH` |
| Relanzar el error | `THROW;` (solo en `CATCH`) |
| Nivel de aislamiento | `SET TRANSACTION ISOLATION LEVEL ...` |
| Deadlock | Error 1205; se previene con orden consistente y transacciones cortas |

### Patrón de oro

```sql
CREATE OR ALTER PROCEDURE dbo.usp_nombre
    -- parámetros
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- 1) validaciones previas (fuera de la transacción)

        BEGIN TRANSACTION;

            -- 2) operaciones que deben ser atómicas

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
```

### Cierre de la secuencia de laboratorios

| Sesión | Tema | Qué se logró |
|---|---|---|
| 1 | Normalización y creación de la BD | Modelo en 3FN con integridad referencial |
| 2 | Procedimientos almacenados | Lógica reutilizable y validada en el servidor |
| 3 | Transacciones | Operaciones atómicas, seguras y concurrentes |