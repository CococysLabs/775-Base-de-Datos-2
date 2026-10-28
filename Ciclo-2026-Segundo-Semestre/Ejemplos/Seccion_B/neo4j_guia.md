# Guía de Neo4j: comandos básicos, base de datos de películas y consultas avanzadas

## Índice

1. [Conceptos básicos](#1-conceptos-básicos)
2. [Comandos básicos de Cypher](#2-comandos-básicos-de-cypher)
3. [Cargar la base de datos de ejemplo de películas](#3-cargar-la-base-de-datos-de-ejemplo-de-películas)
4. [Explorar el modelo de datos](#4-explorar-el-modelo-de-datos)
5. [Consultas avanzadas](#5-consultas-avanzadas)
6. [Índices, restricciones y rendimiento](#6-índices-restricciones-y-rendimiento)
7. [Referencias](#7-referencias)

---

## 1. Conceptos básicos

Neo4j es una base de datos orientada a grafos. Sus elementos principales son:

| Elemento | Descripción | Ejemplo |
|---|---|---|
| **Nodo** | Entidad del grafo | `(p:Person)` |
| **Etiqueta (label)** | Tipo o categoría del nodo | `:Person`, `:Movie` |
| **Relación** | Conexión dirigida entre dos nodos, siempre con un tipo | `-[:ACTED_IN]->` |
| **Propiedad** | Par clave-valor en nodos o relaciones | `{name: 'Tom Hanks'}` |

El lenguaje de consulta se llama **Cypher**. Sintaxis visual (ASCII art):

```cypher
(a:Persona)-[:CONOCE]->(b:Persona)
```

---

## 2. Comandos básicos de Cypher

### 2.1 Crear datos (`CREATE` / `MERGE`)

```cypher
// Crear un nodo
CREATE (p:Person {name: 'Ana', born: 1990})

// Crear dos nodos y una relación
CREATE (a:Person {name: 'Luis'})-[:FRIEND_OF {since: 2020}]->(b:Person {name: 'Marta'})

// MERGE: crea solo si no existe (evita duplicados)
MERGE (p:Person {name: 'Ana'})
ON CREATE SET p.created = datetime()
ON MATCH SET p.lastSeen = datetime()
```

### 2.2 Leer datos (`MATCH` / `RETURN`)

```cypher
// Todos los nodos (¡cuidado en bases grandes!)
MATCH (n) RETURN n LIMIT 25

// Nodos por etiqueta
MATCH (p:Person) RETURN p.name, p.born

// Filtrar con WHERE
MATCH (p:Person)
WHERE p.born >= 1960 AND p.born < 1970
RETURN p.name, p.born
ORDER BY p.born DESC
LIMIT 10

// Filtrar por propiedad directamente
MATCH (p:Person {name: 'Ana'}) RETURN p

// Recorrer relaciones
MATCH (a:Person)-[:FRIEND_OF]->(b:Person)
RETURN a.name, b.name

// Búsquedas de texto
MATCH (p:Person)
WHERE p.name STARTS WITH 'A' OR p.name CONTAINS 'ar' OR p.name =~ '(?i)^a.*'
RETURN p.name
```

### 2.3 Actualizar datos (`SET` / `REMOVE`)

```cypher
// Agregar o modificar propiedades
MATCH (p:Person {name: 'Ana'})
SET p.born = 1991, p.city = 'Guatemala'

// Reemplazar o añadir múltiples propiedades
MATCH (p:Person {name: 'Ana'})
SET p += {job: 'Ingeniera', active: true}

// Agregar una etiqueta
MATCH (p:Person {name: 'Ana'})
SET p:Employee

// Quitar propiedad o etiqueta
MATCH (p:Person {name: 'Ana'})
REMOVE p.city, p:Employee
```

### 2.4 Eliminar datos (`DELETE` / `DETACH DELETE`)

```cypher
// Eliminar una relación
MATCH (:Person {name:'Luis'})-[r:FRIEND_OF]->(:Person {name:'Marta'})
DELETE r

// Eliminar un nodo con todas sus relaciones
MATCH (p:Person {name: 'Ana'})
DETACH DELETE p

// Borrar TODA la base de datos (cuidado)
MATCH (n) DETACH DELETE n
```

### 2.5 Comandos de utilidad

```cypher
// Mostrar el esquema visual
CALL db.schema.visualization()

// Etiquetas, tipos de relación y propiedades existentes
CALL db.labels()
CALL db.relationshipTypes()
CALL db.propertyKeys()

// Contar nodos y relaciones
MATCH (n) RETURN count(n) AS totalNodos
MATCH ()-[r]->() RETURN count(r) AS totalRelaciones

// Información de la instancia
SHOW DATABASES
SHOW INDEXES
SHOW CONSTRAINTS
SHOW PROCEDURES
SHOW FUNCTIONS
```

### 2.6 Comandos de Neo4j Browser (empiezan con `:`)

| Comando | Función |
|---|---|
| `:help` | Muestra la ayuda |
| `:clear` | Limpia el panel de resultados |
| `:play <guía>` | Abre una guía interactiva |
| `:server status` | Estado de la conexión |
| `:server disconnect` | Cierra la sesión |
| `:use <base>` | Cambia de base de datos |

---

## 3. Cargar la base de datos de ejemplo de películas

El dataset clásico **Movie Graph** contiene películas, actores, directores, productores y reseñas. Hay varias formas de cargarlo. Elige la que se ajuste a tu instalación.

### Opción A: Desde Neo4j Browser (la más sencilla)

1. Abre Neo4j Browser (por defecto `http://localhost:7474`).
2. Inicia sesión (usuario por defecto: `neo4j`; la contraseña es la que definiste al instalar).
3. Ejecuta en la barra de comandos:

   ```
   :play movies
   ```

   > Si no aparece, prueba con `:play movie-graph` o busca "Movie Graph" en el panel lateral, en la sección de guías (*Favorites* / *Guides*).

4. En la guía interactiva, avanza hasta la diapositiva con el script de carga.
5. Haz clic en el bloque de código `CREATE ...` (se copia al editor) y presiona **Run** (▶ o `Ctrl + Enter`).
6. Verifica la carga:

   ```cypher
   MATCH (n) RETURN labels(n) AS etiqueta, count(*) AS total
   ```

   Deberías ver aproximadamente 38 películas y 130+ personas.

### Opción B: Con Docker y `cypher-shell` (script de GitHub)

1. Levanta Neo4j:

   ```bash
   docker run -d --name neo4j-movies \
     -p 7474:7474 -p 7687:7687 \
     -e NEO4J_AUTH=neo4j/password123 \
     neo4j:5
   ```

2. Descarga el script del repositorio oficial de ejemplos (`neo4j-graph-examples/movies`):

   ```bash
   curl -L -o movies.cypher \
     https://raw.githubusercontent.com/neo4j-graph-examples/movies/main/scripts/movies.cypher
   ```

   > Si la ruta cambió, entra al repositorio en GitHub y revisa la carpeta `scripts/` o `data/`.

3. Cárgalo con `cypher-shell`:

   ```bash
   cat movies.cypher | docker exec -i neo4j-movies \
     cypher-shell -u neo4j -p password123
   ```

4. Verifica:

   ```bash
   docker exec -it neo4j-movies cypher-shell -u neo4j -p password123 \
     "MATCH (n) RETURN labels(n), count(*)"
   ```

### Opción C: Desde Neo4j Desktop

1. Abre Neo4j Desktop y crea (o selecciona) un proyecto.
2. Haz clic en **Add** → **Local DBMS** (o **Graph examples**, según la versión) y busca el ejemplo **Movies**.
3. Inicia la instancia (**Start**) y abre **Neo4j Browser**.
4. Si el ejemplo viene como *dump*, se importa automáticamente al crear el DBMS desde el ejemplo.

### Opción D: Neo4j Aura (nube)

1. Crea una instancia en [console.neo4j.io](https://console.neo4j.io).
2. En el asistente de creación, selecciona un **dataset de ejemplo** si está disponible (por ejemplo, *Recommendations/Movies*).
3. Alternativamente, abre la herramienta **Query** y pega el contenido del script `movies.cypher`.

> **Nota:** el dataset *Recommendations* de Aura usa un modelo distinto (`User`, `Movie`, `Genre`, `RATED`). Las consultas de esta guía usan el modelo clásico **Movie Graph** (`Person`, `Movie`, `ACTED_IN`, etc.).

### Opción E: Desde un archivo *dump* (instalación local)

Si tienes un archivo `movies.dump`:

```bash
# Detén la base de datos antes de cargar
neo4j stop

# Neo4j 5.x
neo4j-admin database load movies --from-path=/ruta/al/directorio --overwrite-destination=true

# Reinicia y crea la base si es necesario
neo4j start
```

Luego, en Browser:

```cypher
CREATE DATABASE movies IF NOT EXISTS
:use movies
```

---

## 4. Explorar el modelo de datos

### Modelo del grafo

```
(:Person)-[:ACTED_IN {roles: [...]}]->(:Movie)
(:Person)-[:DIRECTED]->(:Movie)
(:Person)-[:PRODUCED]->(:Movie)
(:Person)-[:WROTE]->(:Movie)
(:Person)-[:REVIEWED {summary, rating}]->(:Movie)
(:Person)-[:FOLLOWS]->(:Person)
```

| Etiqueta | Propiedades |
|---|---|
| `Person` | `name`, `born` |
| `Movie` | `title`, `released`, `tagline` |

### Consultas de exploración

```cypher
// Ver el esquema
CALL db.schema.visualization()

// Conteo por etiqueta
MATCH (n) RETURN labels(n) AS etiqueta, count(*) AS total

// Conteo por tipo de relación
MATCH ()-[r]->() RETURN type(r) AS relacion, count(*) AS total ORDER BY total DESC

// Ver una película con todo su entorno
MATCH (m:Movie {title: 'The Matrix'})<-[r]-(p:Person)
RETURN m, r, p
```

---

## 5. Consultas avanzadas

### 5.1 Agregaciones y ordenamiento

```cypher
// Los 10 actores con más películas
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)
RETURN p.name AS actor, count(m) AS peliculas
ORDER BY peliculas DESC
LIMIT 10
```

```cypher
// Películas por década
MATCH (m:Movie)
RETURN (m.released / 10) * 10 AS decada, count(*) AS total
ORDER BY decada
```

```cypher
// Promedio de edad de los actores por película (con collect y lista)
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)
WHERE p.born IS NOT NULL
RETURN m.title AS pelicula,
       count(p) AS actores,
       round(avg(m.released - p.born), 1) AS edadPromedio,
       collect(p.name)[..3] AS primerosActores
ORDER BY actores DESC
LIMIT 10
```

### 5.2 `WITH`: encadenar y filtrar resultados intermedios

```cypher
// Directores que dirigieron 2 o más películas, con sus títulos
MATCH (d:Person)-[:DIRECTED]->(m:Movie)
WITH d, collect(m.title) AS titulos
WHERE size(titulos) >= 2
RETURN d.name AS director, titulos
ORDER BY size(titulos) DESC
```

### 5.3 Compañeros de reparto (coactores)

```cypher
// Con quién ha actuado Tom Hanks y en cuántas películas
MATCH (tom:Person {name: 'Tom Hanks'})-[:ACTED_IN]->(m:Movie)<-[:ACTED_IN]-(coActor:Person)
WHERE coActor <> tom
RETURN coActor.name AS coactor,
       count(m) AS peliculasEnComun,
       collect(m.title) AS titulos
ORDER BY peliculasEnComun DESC
```

### 5.4 Recomendaciones: "coactores de mis coactores"

Actores con los que Tom Hanks **no** ha trabajado, pero sí sus compañeros de reparto (candidatos a futuras colaboraciones):

```cypher
MATCH (tom:Person {name: 'Tom Hanks'})-[:ACTED_IN]->(:Movie)<-[:ACTED_IN]-(coActor:Person),
      (coActor)-[:ACTED_IN]->(:Movie)<-[:ACTED_IN]-(candidato:Person)
WHERE tom <> candidato
  AND NOT (tom)-[:ACTED_IN]->(:Movie)<-[:ACTED_IN]-(candidato)
RETURN candidato.name AS recomendado,
       count(DISTINCT coActor) AS contactosEnComun,
       collect(DISTINCT coActor.name)[..5] AS intermediarios
ORDER BY contactosEnComun DESC
LIMIT 10
```

### 5.5 Camino más corto (`shortestPath`) y "Seis grados de Kevin Bacon"

```cypher
// Camino más corto entre dos personas
MATCH path = shortestPath(
  (a:Person {name: 'Keanu Reeves'})-[*..15]-(b:Person {name: 'Tom Cruise'})
)
RETURN path, length(path) AS saltos
```

```cypher
// Todos los caminos más cortos (si hay empates)
MATCH path = allShortestPaths(
  (a:Person {name: 'Keanu Reeves'})-[:ACTED_IN*..10]-(b:Person {name: 'Kevin Bacon'})
)
RETURN [n IN nodes(path) | coalesce(n.name, n.title)] AS ruta
```

```cypher
// Número de Bacon: distancia de todos los actores a Kevin Bacon
MATCH path = shortestPath(
  (kb:Person {name: 'Kevin Bacon'})-[:ACTED_IN*]-(p:Person)
)
WHERE p <> kb
RETURN p.name AS actor, length(path) / 2 AS numeroDeBacon
ORDER BY numeroDeBacon, actor
```

### 5.6 Patrones de longitud variable

```cypher
// Personas a 1 a 3 "saltos de película" de Keanu Reeves
MATCH (k:Person {name: 'Keanu Reeves'})-[:ACTED_IN*2..6]-(otro:Person)
WHERE otro <> k
RETURN DISTINCT otro.name AS persona
LIMIT 25
```

### 5.7 `OPTIONAL MATCH`: incluir datos que pueden no existir

```cypher
// Todas las películas, con su director (si lo tiene) y la calificación promedio (si hay reseñas)
MATCH (m:Movie)
OPTIONAL MATCH (d:Person)-[:DIRECTED]->(m)
OPTIONAL MATCH (:Person)-[r:REVIEWED]->(m)
RETURN m.title AS pelicula,
       collect(DISTINCT d.name) AS directores,
       avg(r.rating) AS ratingPromedio,
       count(r) AS numResenas
ORDER BY ratingPromedio DESC
```

### 5.8 Personas con múltiples roles en una misma película

```cypher
// Quienes actuaron Y dirigieron la misma película
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)<-[:DIRECTED]-(p)
RETURN p.name AS persona, m.title AS pelicula

// Quienes dirigieron y produjeron
MATCH (p:Person)-[:DIRECTED]->(m:Movie)<-[:PRODUCED]-(p)
RETURN p.name, collect(m.title) AS peliculas
```

### 5.9 Expresiones `CASE`, listas y comprensión de listas

```cypher
// Clasificar películas por época
MATCH (m:Movie)
RETURN m.title,
       m.released,
       CASE
         WHEN m.released < 1990 THEN 'Clásica'
         WHEN m.released < 2000 THEN 'Años 90'
         WHEN m.released < 2010 THEN 'Años 2000'
         ELSE 'Reciente'
       END AS epoca
ORDER BY m.released
```

```cypher
// Comprensión de listas: roles que interpretó cada actor en una película
MATCH (p:Person)-[r:ACTED_IN]->(m:Movie {title: 'The Matrix'})
RETURN p.name AS actor,
       [rol IN r.roles | toUpper(rol)] AS roles
```

### 5.10 `UNWIND`: expandir listas en filas

```cypher
// Contar cuántos personajes distintos ha interpretado cada actor
MATCH (p:Person)-[r:ACTED_IN]->(:Movie)
UNWIND r.roles AS rol
RETURN p.name AS actor, count(DISTINCT rol) AS personajes
ORDER BY personajes DESC
LIMIT 10
```

```cypher
// Crear datos desde una lista
UNWIND [
  {name: 'Persona A', born: 1980},
  {name: 'Persona B', born: 1985}
] AS fila
MERGE (p:Person {name: fila.name})
SET p.born = fila.born
```

### 5.11 Subconsultas: `COUNT {}`, `EXISTS {}` y `CALL {}`

```cypher
// Películas con más de 5 actores (subconsulta COUNT, Neo4j 5.x)
MATCH (m:Movie)
WHERE COUNT { (m)<-[:ACTED_IN]-() } > 5
RETURN m.title, COUNT { (m)<-[:ACTED_IN]-() } AS actores
ORDER BY actores DESC
```

```cypher
// Películas que tienen al menos una reseña
MATCH (m:Movie)
WHERE EXISTS { (m)<-[:REVIEWED]-(:Person) }
RETURN m.title
```

```cypher
// CALL {}: para cada director, su película más reciente
MATCH (d:Person)-[:DIRECTED]->(:Movie)
WITH DISTINCT d
CALL {
  WITH d
  MATCH (d)-[:DIRECTED]->(m:Movie)
  RETURN m.title AS ultima, m.released AS anio
  ORDER BY m.released DESC
  LIMIT 1
}
RETURN d.name AS director, ultima, anio
ORDER BY anio DESC
```

### 5.12 `UNION`: combinar resultados

```cypher
MATCH (p:Person)-[:DIRECTED]->(m:Movie)
RETURN p.name AS persona, 'Director' AS rol, m.title AS pelicula
UNION
MATCH (p:Person)-[:PRODUCED]->(m:Movie)
RETURN p.name AS persona, 'Productor' AS rol, m.title AS pelicula
```

### 5.13 Fechas y funciones de agregación estadística

```cypher
MATCH (p:Person)-[:ACTED_IN]->(:Movie)
WHERE p.born IS NOT NULL
WITH DISTINCT p
RETURN min(p.born) AS masViejo,
       max(p.born) AS masJoven,
       avg(p.born) AS promedio,
       percentileCont(p.born, 0.5) AS mediana,
       stDev(p.born) AS desviacion
```

### 5.14 Modificar el grafo con consultas avanzadas

```cypher
// Crear una relación derivada: COACTOR_DE con el número de películas compartidas
MATCH (a:Person)-[:ACTED_IN]->(m:Movie)<-[:ACTED_IN]-(b:Person)
WHERE id(a) < id(b)
WITH a, b, count(m) AS compartidas
MERGE (a)-[c:COACTOR_DE]->(b)
SET c.peliculas = compartidas
```

```cypher
// Actualizar en lote
MATCH (m:Movie)
WHERE m.released < 1990
SET m.clasica = true
RETURN count(m) AS actualizadas
```

### 5.15 Procedimientos útiles con APOC (si está instalado)

```cypher
// Listar procedimientos APOC disponibles
SHOW PROCEDURES YIELD name WHERE name STARTS WITH 'apoc' RETURN name LIMIT 20

// Exportar a JSON
CALL apoc.export.json.all('peliculas.json', {})

// Cargar JSON/CSV desde una URL o archivo
CALL apoc.load.json('https://ejemplo.com/datos.json') YIELD value
RETURN value LIMIT 5
```

> APOC viene como plugin: en Docker se activa con `-e NEO4J_PLUGINS='["apoc"]'`.

### 5.16 Algoritmos de grafos (Graph Data Science, opcional)

Con el plugin **GDS** instalado puedes calcular, por ejemplo, centralidad y comunidades:

```cypher
// Proyectar el grafo de actores y películas
CALL gds.graph.project(
  'actoresGrafo',
  ['Person', 'Movie'],
  {ACTED_IN: {orientation: 'UNDIRECTED'}}
)

// PageRank: los nodos más influyentes
CALL gds.pageRank.stream('actoresGrafo')
YIELD nodeId, score
RETURN coalesce(gds.util.asNode(nodeId).name, gds.util.asNode(nodeId).title) AS nodo, score
ORDER BY score DESC
LIMIT 10

// Detección de comunidades (Louvain)
CALL gds.louvain.stream('actoresGrafo')
YIELD nodeId, communityId
RETURN communityId, count(*) AS tamano
ORDER BY tamano DESC
```

---

## 6. Índices, restricciones y rendimiento

### Restricciones (garantizan unicidad y crean un índice automáticamente)

```cypher
CREATE CONSTRAINT person_name_unique IF NOT EXISTS
FOR (p:Person) REQUIRE p.name IS UNIQUE

CREATE CONSTRAINT movie_title_unique IF NOT EXISTS
FOR (m:Movie) REQUIRE m.title IS UNIQUE
```

### Índices

```cypher
// Índice de propiedad simple
CREATE INDEX movie_released IF NOT EXISTS
FOR (m:Movie) ON (m.released)

// Índice de texto (para CONTAINS / ENDS WITH)
CREATE TEXT INDEX person_name_text IF NOT EXISTS
FOR (p:Person) ON (p.name)

// Índice de texto completo (full-text)
CREATE FULLTEXT INDEX movie_search IF NOT EXISTS
FOR (m:Movie) ON EACH [m.title, m.tagline]

// Usar el índice full-text
CALL db.index.fulltext.queryNodes('movie_search', 'matrix OR love')
YIELD node, score
RETURN node.title, score
```

### Eliminar índices y restricciones

```cypher
DROP INDEX movie_released IF EXISTS
DROP CONSTRAINT person_name_unique IF EXISTS
```

### Analizar el rendimiento de una consulta

```cypher
// EXPLAIN: muestra el plan SIN ejecutar la consulta
EXPLAIN
MATCH (p:Person {name: 'Tom Hanks'})-[:ACTED_IN]->(m:Movie)
RETURN m.title

// PROFILE: ejecuta la consulta y muestra db hits y filas reales
PROFILE
MATCH (p:Person {name: 'Tom Hanks'})-[:ACTED_IN]->(m:Movie)
RETURN m.title
```

**Buenas prácticas:**

- Usa `MERGE` y restricciones de unicidad para evitar duplicados.
- Filtra lo antes posible (`WHERE`, propiedades en el `MATCH`) y limita con `LIMIT`.
- Evita patrones de longitud variable sin límite superior (`[*]`) en grafos grandes.
- Usa parámetros (`$nombre`) en lugar de concatenar valores en el texto de la consulta.
- Revisa los planes con `PROFILE` y busca `NodeByLabelScan` o `AllNodesScan` donde esperarías un índice.

```cypher
// Ejemplo con parámetros (en Browser: :param titulo => 'The Matrix')
MATCH (m:Movie {title: $titulo})<-[:ACTED_IN]-(p:Person)
RETURN p.name
```

---

## 7. Referencias

- Manual de Cypher: <https://neo4j.com/docs/cypher-manual/current/>
- Guía de introducción: <https://neo4j.com/docs/getting-started/>
- Ejemplos de grafos (repositorio oficial): <https://github.com/neo4j-graph-examples>
- Neo4j Browser: <https://neo4j.com/docs/browser-manual/current/>
- APOC: <https://neo4j.com/docs/apoc/current/>
- Graph Data Science: <https://neo4j.com/docs/graph-data-science/current/>
- Neo4j GraphAcademy (cursos gratuitos): <https://graphacademy.neo4j.com/>
