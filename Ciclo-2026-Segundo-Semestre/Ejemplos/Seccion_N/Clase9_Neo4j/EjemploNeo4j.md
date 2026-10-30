## 1. Iniciar Neo4j con Neo4j Desktop

Neo4j Desktop es la forma más sencilla de empezar.

1.  **Crea un Proyecto:** Abre Neo4j Desktop y crea un nuevo proyecto.
2.  **Crea una Base de Datos:** Dentro del proyecto, haz clic en "Add" -> "Local DBMS". Dale un nombre (ej: "mi-proyecto") y una contraseña segura. O crea una base de datos nueva
3.  **Inicia y Conéctate:** Haz clic en el botón "Start" junto a tu nueva base de datos. Una vez que esté activa, haz clic en "Open" para lanzar Neo4j Browser, la interfaz de línea de comandos.

Para verificar que todo funciona, puedes ejecutar una consulta simple en el Browser:

```cypher
:sysinfo
```

Esto te mostrará información sobre la base de datos, confirmando que está activa.

## 2. Nodos y Propiedades (Creación de Datos)

Los **Nodos** son las entidades principales en un grafo (ej: usuarios, productos, posts). Las **Propiedades** son pares clave-valor que describen a esos nodos.

**Buena práctica:** Usar etiquetas en `MayusculaCamelCase` para categorizar nodos (ej: `Usuario`, `Ciudad`).

```cypher
// CREATE: Crea un nodo.
// Usamos la etiqueta :Usuario para categorizarlo.
// Las propiedades van entre llaves {}.
CREATE (u:Usuario {nombre: "Ana", edad: 30, ciudad: "Madrid"})

// Para ver el nodo que acabamos de crear:
// MATCH: Busca un patrón en el grafo.
// RETURN: Devuelve los resultados.
MATCH (u:Usuario {nombre: "Ana"})
RETURN u
```

**Crear múltiples nodos:**

```cypher
// Crear más usuarios para nuestra red social
CREATE (juan:Usuario {nombre: "Juan", edad: 25, ciudad: "Barcelona"})
CREATE (luis:Usuario {nombre: "Luis", edad: 35, ciudad: "Madrid"})
CREATE (sara:Usuario {nombre: "Sara", edad: 28, ciudad: "Sevilla"})
```

## 3. Relaciones (Conexión de Datos)

Las **Relaciones** (o aristas) son las conexiones con significado entre los nodos. Tienen un tipo (verbo en `MAYUSCULAS_CON_GUION_BAJO`) y una dirección.

```cypher
// Primero, buscamos los nodos que queremos conectar
MATCH (ana:Usuario {nombre: "Ana"})
MATCH (juan:Usuario {nombre: "Juan"})

// CREATE: Crea una relación entre los nodos encontrados.
// La relación :ES_AMIGO_DE va desde un Usuario hacia otro.
CREATE (ana)-[:ES_AMIGO_DE]->(juan)
```

**Crear múltiples relaciones y añadir propiedades a la relación:**

```cypher
// Conectamos a los demás usuarios
MATCH (ana:Usuario {nombre: "Ana"})
MATCH (luis:Usuario {nombre: "Luis"})
MATCH (juan:Usuario {nombre: "Juan"})
MATCH (sara:Usuario {nombre: "Sara"})

// La relación :ES_AMIGO_DE puede tener propiedades, como desde cuándo son amigos.
CREATE (ana)-[:ES_AMIGO_DE {desde: 2021}]->(luis)
CREATE (juan)-[:ES_AMIGO_DE {desde: 2020}]->(luis)
CREATE (sara)-[:ES_AMIGO_DE {desde: 2022}]->(ana)
```

## 4. Búsqueda de Patrones (MATCH)

`MATCH` es el comando más importante para leer datos. Permite describir patrones de nodos y relaciones.

```cypher
// ¿Quiénes son los amigos de Ana?
// Describe el patrón: un Usuario (ana) que ES_AMIGO_DE otro Usuario (amigo).
MATCH (ana:Usuario {nombre: "Ana"})-[:ES_AMIGO_DE]->(amigo:Usuario)
RETURN amigo.nombre

// ¿Quiénes son los amigos de los amigos de Ana? (Recomendaciones)
// El `-[*2]-` significa una ruta de 2 relaciones de longitud.
MATCH (ana:Usuario {nombre: "Ana"})-[:ES_AMIGO_DE*2]->(amigoDeAmigo:Usuario)
RETURN amigoDeAmigo.nombre

// Encontrar a todos los que viven en Madrid
MATCH (u:Usuario {ciudad: "Madrid"})
RETURN u.nombre

// Ver el grafo completo de amistades
MATCH (u1:Usuario)-[r:ES_AMIGO_DE]->(u2:Usuario)
RETURN u1, r, u2
```

## 5. Modificación y Eliminación de Datos

Podemos actualizar propiedades o eliminar elementos del grafo.

```cypher
// SET: Actualiza o añade propiedades.
MATCH (u:Usuario {nombre: "Juan"})
SET u.estado = "Activo"
RETURN u

// REMOVE: Elimina una propiedad de un nodo.
MATCH (u:Usuario {nombre: "Juan"})
REMOVE u.estado
RETURN u

// DELETE: Elimina una relación.
MATCH (ana:Usuario {nombre: "Ana"})-[r:ES_AMIGO_DE]->(juan:Usuario {nombre: "Juan"})
DELETE r

// Para eliminar un nodo, primero debes eliminar todas sus relaciones.
// DELETE juan // Esto daría un error porque Juan todavía es amigo de Luis.
```

**`DETACH DELETE`:** Elimina un nodo y todas sus relaciones de una sola vez. ¡Usar con cuidado!

```cypher
// Crear un usuario temporal para borrarlo
CREATE (temp:Usuario {nombre: "Usuario Temporal"})

// Eliminar el nodo y cualquier relación que pudiera tener
MATCH (temp:Usuario {nombre: "Usuario Temporal"})
DETACH DELETE temp
```

## 6. Creación Condicional (MERGE)

`MERGE` es una combinación de `MATCH` y `CREATE`. Busca un patrón; si existe, no hace nada. Si no existe, lo crea. Es ideal para evitar duplicados.

```cypher
// Intenta encontrar un usuario llamado "Pedro". Si no existe, lo crea.
MERGE (p:Usuario {nombre: "Pedro"})

// ON CREATE SET: Ejecuta una acción solo si el nodo fue creado por MERGE.
MERGE (u:Usuario {nombre: "Maria"})
ON CREATE SET u.ciudad = "Valencia", u.edad = 40

// Conectar a Maria con Pedro usando MERGE para la relación
MATCH (maria:Usuario {nombre: "Maria"})
MATCH (pedro:Usuario {nombre: "Pedro"})

// MERGE en una relación evita crear conexiones duplicadas
MERGE (maria)-[:ES_AMIGO_DE {desde: 2023}]->(pedro)
```

## 7. Funciones y Agregaciones

Cypher tiene funciones para contar, sumar, promediar y recolectar resultados.

```cypher
// COUNT: Contar el número de elementos.
// ¿Cuántos amigos tiene Luis?
MATCH (luis:Usuario {nombre: "Luis"})<-[:ES_AMIGO_DE]-(amigo:Usuario)
RETURN count(amigo)

// COLLECT: Agrupa valores en una lista.
// Devuelve el nombre de cada usuario y una lista de sus amigos.
MATCH (u:Usuario)-[:ES_AMIGO_DE]->(amigo:Usuario)
RETURN u.nombre, collect(amigo.nombre) AS amigos

// WITH: Permite encadenar consultas y filtrar resultados intermedios.
// Encontrar usuarios con más de 1 amigo.
MATCH (u:Usuario)-[:ES_AMIGO_DE]->(amigo:Usuario)
WITH u, count(amigo) AS numero_de_amigos
WHERE numero_de_amigos > 1
RETURN u.nombre, numero_de_amigos
```

## 8. Índices y Restricciones (Constraints)

Los índices aceleran las búsquedas de nodos por una propiedad específica. Las restricciones garantizan la unicidad de los datos.

```cypher
// Crear un índice en la propiedad 'ciudad' de los nodos :Usuario.
// Las búsquedas como MATCH (u:Usuario {ciudad: "..."}) serán mucho más rápidas.
CREATE INDEX usuario_ciudad FOR (u:Usuario) ON (u.ciudad)

// Crear una restricción de unicidad.
// Garantiza que no puede haber dos usuarios con el mismo nombre.
// También crea un índice automáticamente.
CREATE CONSTRAINT usuario_nombre_unique FOR (u:Usuario) REQUIRE u.nombre IS UNIQUE

// Intentar crear un usuario con un nombre que ya existe fallará.
// CREATE (u:Usuario {nombre: "Ana"}) // Esto devolverá un error

// Para eliminar un índice o una restricción:
// DROP INDEX usuario_ciudad
// DROP CONSTRAINT usuario_nombre_unique
```
## 9. Filtrado Avanzado y Ordenación (WHERE, ORDER BY, LIMIT)

Para hacer consultas más precisas y mostrar los datos de forma ordenada en tus reportes.

```cypher
// WHERE: Filtrar resultados con condiciones específicas combinadas
MATCH (u:Usuario)
WHERE u.edad >= 30 AND u.ciudad = "Madrid"
RETURN u.nombre, u.edad

// Búsqueda de texto dinámica (STARTS WITH, ENDS WITH, CONTAINS)
MATCH (u:Usuario)
WHERE u.nombre STARTS WITH "A" OR u.nombre CONTAINS "ar"
RETURN u.nombre

// ORDER BY: Ordenar resultados (ASCendente o DESCendente)
// LIMIT: Mostrar solo un top específico (ej. los 3 mayores)
MATCH (u:Usuario)
WHERE u.edad IS NOT NULL
RETURN u.nombre, u.edad
ORDER BY u.edad DESC
LIMIT 3

// SKIP: Paginación (saltar los primeros 2 resultados)
MATCH (u:Usuario)
WHERE u.edad IS NOT NULL
RETURN u.nombre, u.edad
ORDER BY u.edad DESC
SKIP 2 LIMIT 2
```

## 10. Creación en Lote de Datos (UNWIND)

`UNWIND` transforma una lista de elementos en filas individuales. Es la forma más eficiente y recomendada de insertar muchos datos de golpe en lugar de escribir múltiples `CREATE`.

```cypher
// 1. Crear varios usuarios a partir de una lista simple de nombres
UNWIND ["Carlos", "Elena", "Fernando", "Gabriela"] AS nombre_nuevo
CREATE (u:Usuario {nombre: nombre_nuevo, ciudad: "Desconocida"})
RETURN u.nombre

// 2. UNWIND con una lista de diccionarios (simulando un JSON que llega de una API)
UNWIND [
  {nombre: "Hugo", edad: 22, ciudad: "Bilbao"},
  {nombre: "Irene", edad: 29, ciudad: "Zaragoza"}
] AS persona
CREATE (u:Usuario {nombre: persona.nombre, edad: persona.edad, ciudad: persona.ciudad})
RETURN u.nombre, u.ciudad
```

## 11. Búsqueda de Rutas (Shortest Path)

Aquí es donde Neo4j demuestra su verdadero poder frente a bases de datos relacionales: analizar cómo se conectan dos elementos lejanos.

```cypher
// Primero preparamos una conexión lejana para el ejemplo
MATCH (carlos:Usuario {nombre: "Carlos"}), (sara:Usuario {nombre: "Sara"})
MERGE (carlos)-[:ES_AMIGO_DE]->(sara)

// Encontrar el camino más corto entre dos usuarios 
// El `*..5` indica buscar en un máximo de 5 "saltos" de distancia
MATCH (inicio:Usuario {nombre: "Ana"})
MATCH (fin:Usuario {nombre: "Carlos"})
MATCH ruta = shortestPath((inicio)-[:ES_AMIGO_DE*..5]-(fin))
RETURN ruta
```

## 12. Lógica Condicional en Consultas (CASE)

A veces necesitas transformar los datos obtenidos sin modificar la base de datos, usando lógica de tipo if/else.

```cypher
// Clasificar usuarios en categorías dinámicas según sus propiedades
MATCH (u:Usuario)
WHERE u.edad IS NOT NULL
RETURN u.nombre, u.edad,
  CASE
    WHEN u.edad < 25 THEN "Joven"
    WHEN u.edad >= 25 AND u.edad <= 30 THEN "Joven-Adulto"
    ELSE "Adulto"
  END AS categoria_edad
```

## 13. Limpieza Total del Entorno

 Permite reiniciar el entorno de pruebas rápidamente.

```cypher
// Borrar TODOS los nodos y TODAS sus relaciones de la base de datos
MATCH (n)
DETACH DELETE n
```
