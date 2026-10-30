# Neo4j - Ejemplos  Avanzados

## 1. Consultas Avanzadas con Cypher

### 1.1 Consultas con Múltiples MATCH y Patrones Opcionales

Para ejemplos más realistas, vamos a crear un modelo de red social con usuarios, publicaciones (posts) y comentarios. Este escenario nos permitirá practicar consultas complejas.

```cypher
// CREATE: Crear tres usuarios con diferentes propiedades
// Nota: date() permite almacenar fechas, datetime() incluye hora
CREATE (maria:Usuario {nombre: "Maria", edad: 28, email: "maria@email.com"})
CREATE (pedro:Usuario {nombre: "Pedro", edad: 32, email: "pedro@email.com"})
CREATE (lucia:Usuario {nombre: "Lucia", edad: 25, email: "lucia@email.com"})

// Crear dos posts (publicaciones) con fecha
// Usamos la función date() para crear una fecha en formato ISO
CREATE (post1:Post {titulo: "Mi viaje a Tokyo", contenido: "Increíble experiencia...", fecha: date('2024-01-15')})
CREATE (post2:Post {titulo: "Receta de paella", contenido: "Los mejores ingredientes...", fecha: date('2024-02-20')})

// Crear comentarios con timestamp completo (fecha y hora)
// datetime() almacena tanto fecha como hora precisa
CREATE (comentario1:Comentario {texto: "Qué bonito!", fecha: datetime('2024-01-16T10:30:00')})
CREATE (comentario2:Comentario {texto: "Quiero ir también", fecha: datetime('2024-01-16T14:20:00')})
CREATE (comentario3:Comentario {texto: "Me encanta!", fecha: datetime('2024-02-21T09:15:00')})

// Conectar usuarios con sus publicaciones
// Maria publicó el post sobre Tokyo
CREATE (maria)-[:PUBLICO]->(post1)
// Pedro publicó el post sobre paella
CREATE (pedro)-[:PUBLICO]->(post2)

// Conectar usuarios con sus comentarios y los comentarios con los posts
// Lucia comentó en el post de Maria sobre Tokyo
CREATE (lucia)-[:COMENTO]->(comentario1)-[:EN_POST]->(post1)
// Pedro también comentó en el post de Maria
CREATE (pedro)-[:COMENTO]->(comentario2)-[:EN_POST]->(post1)
// Maria comentó en el post de Pedro sobre paella
CREATE (maria)-[:COMENTO]->(comentario3)-[:EN_POST]->(post2)

// Crear relaciones de seguimiento entre usuarios
// Maria sigue a Pedro
CREATE (maria)-[:SIGUE]->(pedro)
// Lucia sigue a Maria
CREATE (lucia)-[:SIGUE]->(maria)
// Pedro sigue a Lucia
CREATE (pedro)-[:SIGUE]->(lucia)
```

**OPTIONAL MATCH:** A diferencia de `MATCH` normal, `OPTIONAL MATCH` devuelve resultados incluso cuando el patrón NO existe. Si no encuentra el patrón, devuelve `NULL` en lugar de omitir la fila completa. Es similar a un `LEFT JOIN` en SQL.

```cypher
// Obtener TODOS los usuarios y sus posts
// MATCH: Busca todos los usuarios (esto siempre trae resultados)
// OPTIONAL MATCH: Busca los posts de cada usuario (puede ser NULL)
MATCH (u:Usuario)
OPTIONAL MATCH (u)-[:PUBLICO]->(p:Post)
// RETURN: Devuelve el nombre de cada usuario
// CASE WHEN: Si el post es NULL, significa que el usuario no ha publicado nada
RETURN u.nombre, 
       CASE WHEN p IS NULL THEN 0 ELSE 1 END AS tiene_posts,
       p.titulo AS titulo_post
// Resultado: Mostrará a Lucia con tiene_posts = 0 y titulo_post = NULL
// porque Lucia no ha publicado ningún post
```

### 1.2 Subconsultas con EXISTS y Expresiones de Patrón

**EXISTS:** Verifica si un patrón existe sin necesidad de devolverlo. Es más eficiente que contar elementos cuando solo necesitas saber si algo existe o no.

```cypher
// Encontrar usuarios que cumplen DOS condiciones:
// 1. Han publicado al menos un post
// 2. Han comentado en posts de OTRAS personas (no propios)

// MATCH: Busca todos los usuarios
MATCH (u:Usuario)
// WHERE: Filtra usuarios que cumplan ambas condiciones
// EXISTS: Verifica que el usuario haya publicado al menos un post
WHERE EXISTS { (u)-[:PUBLICO]->(:Post) }
  // AND: Además debe cumplir la segunda condición
  // EXISTS: Verifica que haya comentado en un post de otra persona
  // El patrón completo: usuario -> comentó -> comentario -> en post <- publicado por otro usuario
  AND EXISTS { (u)-[:COMENTO]->(:Comentario)-[:EN_POST]->(:Post)<-[:PUBLICO]-(:Usuario) }
// RETURN: Devuelve los nombres de usuarios que cumplen ambas condiciones
RETURN u.nombre

// Alternativa con expresiones de patrón (Neo4j 5+)
// Esta sintaxis más corta hace lo mismo que EXISTS
// MATCH: Busca todos los usuarios
MATCH (u:Usuario)
// WHERE: Usar el patrón directamente como condición booleana
// Si el patrón existe, la condición es verdadera
WHERE (u)-[:PUBLICO]->(:Post)
  AND (u)-[:COMENTO]->(:Comentario)-[:EN_POST]->(:Post)<-[:PUBLICO]-(:Usuario)
RETURN u.nombre
```

### 1.3 WITH y Pipeline de Consultas

**WITH:** Es como crear una "subconsulta" o "paso intermedio". Te permite transformar y filtrar datos antes de continuar con la siguiente parte de la consulta. Piénsalo como un "checkpoint" donde puedes reorganizar tus datos.

```cypher
// Pipeline en 4 etapas para calcular usuarios más activos
// Etapa 1: Buscar usuarios y sus publicaciones
MATCH (u:Usuario)
OPTIONAL MATCH (u)-[:PUBLICO]->(p:Post)
// OPTIONAL MATCH: También buscar comentarios (puede ser NULL si no tiene)
OPTIONAL MATCH (u)-[:COMENTO]->(c:Comentario)

// Etapa 2: WITH - Crear variables intermedias
// count(DISTINCT p): Cuenta cuántos posts únicos tiene el usuario
// count(DISTINCT c): Cuenta cuántos comentarios únicos ha hecho
WITH u, count(DISTINCT p) AS num_posts, count(DISTINCT c) AS num_comentarios

// Etapa 3: WITH - Calcular puntuación de actividad
// Los posts valen 3 puntos, los comentarios valen 1 punto
WITH u, num_posts, num_comentarios, (num_posts * 3 + num_comentarios) AS puntuacion_actividad
// WHERE: Filtrar solo usuarios con alguna actividad
WHERE puntuacion_actividad > 0

// Etapa 4: RETURN - Devolver resultados ordenados
// ORDER BY: Ordenar de mayor a menor puntuación
// LIMIT: Mostrar solo los 3 usuarios más activos
RETURN u.nombre, num_posts, num_comentarios, puntuacion_actividad
ORDER BY puntuacion_actividad DESC
LIMIT 3
```

### 1.4 Uso de UNION para Combinar Resultados

**UNION:** Combina los resultados de dos o más consultas en una sola tabla. Todas las consultas deben devolver el mismo número de columnas con los mismos nombres. Similar a UNION en SQL.

```cypher
// Obtener una lista unificada de todo el contenido generado por usuarios
// Primera consulta: Posts publicados
// MATCH: Busca usuarios que han publicado posts
MATCH (u:Usuario)-[:PUBLICO]->(p:Post)
// RETURN: Devuelve datos del post con columnas normalizadas
RETURN u.nombre AS creador, "Post" AS tipo, p.titulo AS contenido

// UNION: Combina los resultados de arriba con los de abajo
UNION

// Segunda consulta: Comentarios realizados
// MATCH: Busca usuarios que han hecho comentarios
MATCH (u:Usuario)-[:COMENTO]->(c:Comentario)
// RETURN: Devuelve datos del comentario con las MISMAS columnas
// Nota: Las columnas deben tener los mismos nombres (creador, tipo, contenido)
RETURN u.nombre AS creador, "Comentario" AS tipo, c.texto AS contenido

// Resultado: Una tabla con todos los posts y comentarios mezclados
// Cada fila indica quién lo creó, qué tipo es y el contenido
```

### 1.5 Expresiones CASE Avanzadas y Coalesce

**CASE:** Permite crear lógica condicional (if/else) dentro de una consulta para clasificar o transformar datos dinámicamente.

**COALESCE:** Devuelve el primer valor no nulo de una lista. Útil para valores predeterminados.

```cypher
// Clasificar a cada usuario según su nivel de participación en la red social

// MATCH: Buscar todos los usuarios
MATCH (u:Usuario)
// OPTIONAL MATCH: Buscar sus posts (puede ser NULL)
OPTIONAL MATCH (u)-[:PUBLICO]->(p:Post)
// OPTIONAL MATCH: Buscar sus comentarios (puede ser NULL)
OPTIONAL MATCH (u)-[:COMENTO]->(c:Comentario)

// WITH: Contar actividades
// count(p): Número de posts (0 si no tiene)
// count(c): Número de comentarios (0 si no tiene)
WITH u, count(p) AS posts, count(c) AS comentarios

// RETURN: Devolver clasificación de cada usuario
RETURN u.nombre,
  posts,
  comentarios,
  // CASE: Evalúa condiciones en orden y devuelve la primera que coincida
  CASE
    WHEN posts >= 2 THEN "Creador Activo"         // Usuario con 2+ posts
    WHEN posts = 1 THEN "Creador Ocasional"       // Usuario con 1 post
    WHEN comentarios > 2 THEN "Comentarista Activo"  // Sin posts pero muchos comentarios
    WHEN comentarios > 0 THEN "Participante"      // Al menos un comentario
    ELSE "Observador"                             // Ninguna actividad
  END AS perfil,
  // coalesce: Si posts + comentarios es NULL, devuelve 0
  // Útil para manejar casos donde el usuario no tenga ninguna actividad
  coalesce(posts + comentarios, 0) AS actividad_total
```

---

## 2. Análisis de Redes y Rutas Más Cortas

Los grafos son perfectos para analizar redes de transporte, redes sociales, o cualquier sistema donde las conexiones y rutas sean importantes. Neo4j tiene algoritmos especializados para encontrar caminos óptimos.

### 2.1 Preparar Datos para Análisis de Redes

Vamos a crear un grafo que represente ciudades españolas conectadas por carreteras. Este ejemplo nos permitirá practicar algoritmos de rutas.

```cypher
// CREATE: Crear nodos de ciudades con propiedades
// Cada ciudad tiene un nombre y su población
CREATE (madrid:Ciudad {nombre: "Madrid", poblacion: 3200000})
CREATE (barcelona:Ciudad {nombre: "Barcelona", poblacion: 1600000})
CREATE (valencia:Ciudad {nombre: "Valencia", poblacion: 800000})
CREATE (sevilla:Ciudad {nombre: "Sevilla", poblacion: 700000})
CREATE (bilbao:Ciudad {nombre: "Bilbao", poblacion: 350000})
CREATE (zaragoza:Ciudad {nombre: "Zaragoza", poblacion: 670000})

// Crear carreteras bidireccionales con propiedades de peso
// IMPORTANTE: En grafos no dirigidos, necesitas crear relaciones en AMBAS direcciones
// distancia_km: Peso para calcular la ruta más corta por distancia
// tiempo_horas: Peso alternativo para calcular la ruta más rápida

// Carretera Madrid <-> Barcelona (621 km, 6.5 horas)
CREATE (madrid)-[:CARRETERA {distancia_km: 621, tiempo_horas: 6.5}]->(barcelona)
CREATE (barcelona)-[:CARRETERA {distancia_km: 621, tiempo_horas: 6.5}]->(madrid)

// Carretera Madrid <-> Valencia (355 km, 3.5 horas)
CREATE (madrid)-[:CARRETERA {distancia_km: 355, tiempo_horas: 3.5}]->(valencia)
CREATE (valencia)-[:CARRETERA {distancia_km: 355, tiempo_horas: 3.5}]->(madrid)

// Carretera Madrid <-> Sevilla (531 km, 5.2 horas)
CREATE (madrid)-[:CARRETERA {distancia_km: 531, tiempo_horas: 5.2}]->(sevilla)
CREATE (sevilla)-[:CARRETERA {distancia_km: 531, tiempo_horas: 5.2}]->(madrid)

// Carretera Madrid <-> Bilbao (395 km, 4.0 horas)
CREATE (madrid)-[:CARRETERA {distancia_km: 395, tiempo_horas: 4.0}]->(bilbao)
CREATE (bilbao)-[:CARRETERA {distancia_km: 395, tiempo_horas: 4.0}]->(madrid)

// Carretera Madrid <-> Zaragoza (325 km, 3.2 horas)
CREATE (madrid)-[:CARRETERA {distancia_km: 325, tiempo_horas: 3.2}]->(zaragoza)
CREATE (zaragoza)-[:CARRETERA {distancia_km: 325, tiempo_horas: 3.2}]->(madrid)

// Carretera Barcelona <-> Valencia (348 km, 3.8 horas)
CREATE (barcelona)-[:CARRETERA {distancia_km: 348, tiempo_horas: 3.8}]->(valencia)
CREATE (valencia)-[:CARRETERA {distancia_km: 348, tiempo_horas: 3.8}]->(barcelona)

// Carretera Zaragoza <-> Barcelona (296 km, 3.0 horas)
CREATE (zaragoza)-[:CARRETERA {distancia_km: 296, tiempo_horas: 3.0}]->(barcelona)
CREATE (barcelona)-[:CARRETERA {distancia_km: 296, tiempo_horas: 3.0}]->(zaragoza)

// Carretera Bilbao <-> Zaragoza (305 km, 3.3 horas)
CREATE (bilbao)-[:CARRETERA {distancia_km: 305, tiempo_horas: 3.3}]->(zaragoza)
CREATE (zaragoza)-[:CARRETERA {distancia_km: 305, tiempo_horas: 3.3}]->(bilbao)
```

### 2.2 Algoritmo: Camino Más Corto (shortestPath)

**shortestPath:** Encuentra la ruta con menos "saltos" (relaciones) entre dos nodos. No considera el peso de las relaciones, solo cuenta cuántas conexiones hay.

```cypher
// Encontrar el camino más corto entre Bilbao y Sevilla
// Solo cuenta el número de carreteras (saltos), no la distancia

// MATCH: Buscar la ciudad de origen
MATCH (origen:Ciudad {nombre: "Bilbao"})
// MATCH: Buscar la ciudad de destino
MATCH (destino:Ciudad {nombre: "Sevilla"})
// MATCH con shortestPath: Encuentra el camino con menos relaciones
// [:CARRETERA*]: El asterisco indica "una o más relaciones CARRETERA"
// El guion sin flecha indica que la dirección no importa (bidireccional)
MATCH ruta = shortestPath((origen)-[:CARRETERA*]-(destino))

// RETURN: Devolver la ruta completa y estadísticas
RETURN ruta,
       // length(ruta): Número de relaciones en la ruta (saltos)
       length(ruta) AS numero_de_saltos,
       // nodes(ruta): Extrae todos los nodos de la ruta
       // [ciudad IN nodes(ruta) | ciudad.nombre]: Crea una lista con los nombres
       [ciudad IN nodes(ruta) | ciudad.nombre] AS ciudades_en_ruta
```

### 2.3 Algoritmo: Todos los Caminos Más Cortos (allShortestPaths)

**allShortestPaths:** Similar a `shortestPath`, pero devuelve TODAS las rutas que tengan la misma longitud mínima. Útil cuando hay múltiples caminos igualmente cortos.

```cypher
// Encontrar TODOS los caminos más cortos entre Madrid y Barcelona
// Puede haber múltiples rutas con el mismo número de saltos

// MATCH: Buscar ciudad de origen
MATCH (origen:Ciudad {nombre: "Madrid"})
// MATCH: Buscar ciudad de destino
MATCH (destino:Ciudad {nombre: "Barcelona"})
// MATCH con allShortestPaths: Encuentra TODAS las rutas con longitud mínima
// Si hay 2 rutas con 1 salto y 1 ruta con 2 saltos, solo devuelve las de 1 salto
MATCH rutas = allShortestPaths((origen)-[:CARRETERA*]-(destino))

// RETURN: Devolver cada ruta encontrada
// Nota: Devolverá una fila por cada ruta diferente
RETURN rutas,
       [ciudad IN nodes(rutas) | ciudad.nombre] AS ciudades_en_ruta
```

### 2.4 Algoritmo: Camino Más Corto Ponderado (Dijkstra Manual)

**Dijkstra:** A diferencia de `shortestPath` que solo cuenta saltos, el algoritmo de Dijkstra encuentra la ruta con el menor peso total (distancia, tiempo, costo, etc.). Aquí lo hacemos manualmente; Neo4j GDS ofrece implementaciones optimizadas.

```cypher
// Encontrar la ruta con MENOR DISTANCIA TOTAL entre Bilbao y Valencia
// No necesariamente la ruta con menos saltos

// MATCH: Buscar ciudad de origen
MATCH (origen:Ciudad {nombre: "Bilbao"})
// MATCH: Buscar ciudad de destino
MATCH (destino:Ciudad {nombre: "Valencia"})
// MATCH: Encontrar el camino más corto por número de saltos
// Nota: Este es un enfoque simplificado; para Dijkstra real usa Neo4j GDS
MATCH ruta = shortestPath((origen)-[:CARRETERA*]-(destino))

// WITH: Extraer información de la ruta
// relationships(ruta): Obtiene todas las relaciones de la ruta
// [rel IN relationships(ruta) | rel.distancia_km]: Crea una lista con las distancias
WITH ruta,
     [rel IN relationships(ruta) | rel.distancia_km] AS distancias,
     [ciudad IN nodes(ruta) | ciudad.nombre] AS ciudades

// RETURN: Calcular la distancia total
RETURN ciudades,
       // reduce: Función de agregación que suma todos los elementos de una lista
       // reduce(total = 0, d IN distancias | total + d): Suma todas las distancias
       reduce(total = 0, d IN distancias | total + d) AS distancia_total_km,
       length(ruta) AS numero_de_saltos
// ORDER BY: Ordenar por distancia total (de menor a mayor)
ORDER BY distancia_total_km ASC
// LIMIT: Mostrar solo la ruta más corta
LIMIT 1
```

**Nota:** Para algoritmos avanzados de grafos (Dijkstra, PageRank, Community Detection), es recomendable usar la **Graph Data Science (GDS) Library** de Neo4j, que ofrece implementaciones optimizadas.

### 2.5 Análisis: Grado de Conectividad (Degree)

**Degree (Grado):** El grado de un nodo es el número de relaciones que tiene. En grafos dirigidos, distinguimos entre "grado de salida" (relaciones salientes) y "grado de entrada" (relaciones entrantes).

```cypher
// ¿Cuáles son las ciudades mejor conectadas? (más carreteras directas)

// MATCH: Buscar todas las ciudades y sus carreteras salientes
// (c:Ciudad)-[r:CARRETERA]->(): Patrón que captura solo relaciones de salida
MATCH (c:Ciudad)-[r:CARRETERA]->()
// WITH: Contar cuántas carreteras tiene cada ciudad
// count(r): Cuenta el número de relaciones CARRETERA que salen de c
WITH c, count(r) AS num_conexiones
// RETURN: Devolver ciudades ordenadas por conectividad
RETURN c.nombre, num_conexiones
// ORDER BY: Mostrar primero las ciudades con más conexiones
ORDER BY num_conexiones DESC

// Alternativa: Encontrar ciudades "hub" (centros de conexión)
// Un hub es una ciudad con más de 3 conexiones directas

// MATCH: Buscar todas las ciudades
MATCH (c:Ciudad)
// WHERE: Filtrar solo ciudades con más de 3 conexiones
// size((c)-[:CARRETERA]->()): Cuenta cuántas relaciones CARRETERA salen de c
WHERE size((c)-[:CARRETERA]->()) > 3
// RETURN: Mostrar solo los hubs
RETURN c.nombre AS hub, 
       size((c)-[:CARRETERA]->()) AS conexiones
```

### 2.6 Análisis: Encontrar Nodos sin Salida (Dead Ends)

En grafos dirigidos, un "dead end" es un nodo que no tiene relaciones salientes. Útil para detectar nodos terminales o inconsistencias en los datos.

```cypher
// Encontrar ciudades que no tienen carretera de salida
// Esto puede indicar un error en los datos o nodos aislados

// MATCH: Buscar todas las ciudades
MATCH (c:Ciudad)
// WHERE NOT: Filtrar ciudades que NO tienen ninguna relación saliente
// (c)-[:CARRETERA]->(): Patrón de relación saliente
// WHERE NOT significa "donde este patrón NO existe"
WHERE NOT (c)-[:CARRETERA]->()
// RETURN: Devolver ciudades sin salida
RETURN c.nombre

// Nota: En nuestro ejemplo todas las ciudades tienen carreteras bidireccionales,
// por lo que esta consulta no debería devolver resultados
```

### 2.7 Análisis: Distancia Variable (Amigos de Amigos)

Las rutas de longitud variable permiten explorar conexiones indirectas. Esto es muy útil para análisis de redes sociales, recomendaciones y detección de comunidades.

```cypher
// Volver al ejemplo de usuarios: ¿Quiénes están a 2 o 3 grados de separación de Maria?
// Grado 1 = amigos directos
// Grado 2 = amigos de amigos
// Grado 3 = amigos de amigos de amigos

// MATCH: Buscar a Maria
MATCH (maria:Usuario {nombre: "Maria"})
// MATCH: Buscar a todos los otros usuarios
MATCH (otros:Usuario)
// WHERE: Filtrar para no incluir a Maria misma
WHERE maria <> otros

// WITH: Calcular la ruta más corta entre Maria y cada otro usuario
// shortestPath: Encuentra la ruta con menos relaciones [:SIGUE]
// IMPORTANTE: Acotamos a 1..3 saltos para evitar el error 03N91
WITH maria, otros,
     shortestPath((maria)-[:SIGUE*1..3]-(otros)) AS camino
// WHERE: Filtrar solo usuarios a 2 o 3 saltos de distancia
// length(camino): Número de relaciones en el camino
// Grado 1 no nos interesa (amigos directos), buscamos conexiones indirectas
WHERE length(camino) >= 1 AND length(camino) <= 3

// RETURN: Mostrar usuarios y su grado de separación
RETURN otros.nombre, 
       length(camino) AS grado_de_separacion
// Resultado: Muestra qué usuarios están conectados indirectamente con Maria
```

---

## 3. Modelado de Relaciones Complejas en Grafos

El verdadero poder de Neo4j está en modelar relaciones complejas que serían difíciles o ineficientes en bases de datos relacionales. Aquí exploramos patrones avanzados de modelado.

### 3.1 Relaciones con Múltiples Etiquetas (Reificación)

**Problema:** Neo4j no soporta múltiples tipos de relación en una sola arista.  
**Solución:** Usar nodos intermedios para representar relaciones complejas. Esto se llama "reificación" o "cosificación" de relaciones.

```cypher
// Escenario: Un usuario puede interactuar con un post de varias formas
// (Me gusta, Compartir, Guardar). Necesitamos modelar cada tipo de interacción
// con sus propias propiedades (fecha, plataforma, etc.)

// CREATE: Crear usuarios y un post
CREATE (ana:Usuario {nombre: "Ana"})
CREATE (post:Post {titulo: "Introducción a Neo4j", fecha: date('2024-03-01')})

// Crear NODOS de interacción en lugar de relaciones directas
// Esto permite tener propiedades específicas para cada tipo de interacción
CREATE (megusta:MeGusta {fecha: datetime('2024-03-02T10:00:00')})
CREATE (compartir:Compartir {fecha: datetime('2024-03-02T11:30:00'), plataforma: "Twitter"})

// Conectar: Usuario -> Interacción -> Post
// Este patrón de dos relaciones permite consultas muy flexibles
CREATE (ana)-[:HIZO]->(megusta)-[:EN]->(post)
CREATE (ana)-[:HIZO]->(compartir)-[:EN]->(post)

// Ahora podemos consultar fácilmente cada tipo de interacción
// ¿Qué posts le han gustado a los usuarios?
MATCH (u:Usuario)-[:HIZO]->(i:MeGusta)-[:EN]->(p:Post)
RETURN u.nombre, p.titulo, i.fecha

// ¿Qué posts ha compartido Ana y en qué plataforma?
MATCH (ana:Usuario {nombre: "Ana"})-[:HIZO]->(c:Compartir)-[:EN]->(p:Post)
RETURN p.titulo, c.plataforma, c.fecha
```

### 3.2 Relaciones Reflexivas (Self-Loops)

**Relación Reflexiva:** Un nodo puede tener una relación consigo mismo. Útil para modelar dependencias circulares, recursión, o procesos iterativos.

```cypher
// Escenario: Una tarea que depende de sí misma (proceso iterativo o recursivo)
// Por ejemplo, "Mejorar Algoritmo" puede requerir múltiples iteraciones

// CREATE: Crear una tarea
CREATE (tarea:Tarea {nombre: "Mejorar Algoritmo"})
// CREATE: Crear una relación que apunta al mismo nodo
// Esta relación indica que la tarea se repite a sí misma
CREATE (tarea)-[:REQUIERE {tipo: "optimización iterativa"}]->(tarea)

// Consultar relaciones reflexivas
// MATCH: El patrón (t)-[r:REQUIERE]->(t) busca relaciones que empiezan y terminan en el mismo nodo
MATCH (t:Tarea)-[r:REQUIERE]->(t)
RETURN t.nombre, r.tipo

// Esto devolverá: "Mejorar Algoritmo", "optimización iterativa"
```

### 3.3 Hipergrafos Simulados (Relaciones N-arias)

**Problema:** A veces necesitas una relación que involucre a más de 2 entidades (ej: "Ana, Pedro y Luis asistieron a una reunión").  
**Solución:** Usar un nodo intermedio que representa el "evento" o "contexto" donde participan múltiples entidades.

```cypher
// Escenario: Modelar una reunión con múltiples participantes
// No podemos crear una relación directa entre 3 personas
// En su lugar, creamos un nodo :Reunion y conectamos a cada persona con él

// CREATE: Crear el nodo de la reunión
CREATE (reunion:Reunion {tema: "Planificación Q2", fecha: date('2024-04-10')})
// CREATE: Crear los participantes
CREATE (ana:Persona {nombre: "Ana"})
CREATE (pedro:Persona {nombre: "Pedro"})
CREATE (luis:Persona {nombre: "Luis"})

// Conectar cada persona con la reunión
// Cada relación puede tener propiedades únicas (ej: rol de cada persona)
CREATE (ana)-[:ASISTIO {rol: "Líder"}]->(reunion)
CREATE (pedro)-[:ASISTIO {rol: "Participante"}]->(reunion)
CREATE (luis)-[:ASISTIO {rol: "Observador"}]->(reunion)

// Consultar: ¿Quiénes asistieron a la reunión de Planificación Q2?
// MATCH: Buscar la reunión específica
MATCH (p:Persona)-[r:ASISTIO]->(reunion:Reunion {tema: "Planificación Q2"})
// RETURN: Devolver cada persona y su rol
RETURN p.nombre, r.rol
// Resultado: Ana (Líder), Pedro (Participante), Luis (Observador)

// Consultar: ¿A qué reuniones ha asistido Ana?
MATCH (ana:Persona {nombre: "Ana"})-[:ASISTIO]->(r:Reunion)
RETURN r.tema, r.fecha
```

### 3.4 Modelado de Jerarquías (Árboles y DAGs)

**Jerarquías:** Estructuras tipo árbol donde cada nodo puede tener un padre y múltiples hijos. Muy común para organigramas, categorías, sistemas de archivos, etc.

```cypher
// Escenario: Estructura organizacional de una empresa (árbol jerárquico)
// CEO -> CTO/CFO -> Empleados de nivel inferior

// CREATE: Crear nodos de empleados con su puesto
CREATE (ceo:Empleado {nombre: "Carlos", puesto: "CEO"})
CREATE (cto:Empleado {nombre: "Teresa", puesto: "CTO"})
CREATE (cfo:Empleado {nombre: "Fernando", puesto: "CFO"})
CREATE (dev1:Empleado {nombre: "Marta", puesto: "Desarrolladora Senior"})
CREATE (dev2:Empleado {nombre: "Jorge", puesto: "Desarrollador Junior"})
CREATE (contador:Empleado {nombre: "Sofia", puesto: "Contadora"})

// Crear relaciones de supervisión (de jefe a subordinado)
// El CEO supervisa a CTO y CFO
CREATE (ceo)-[:SUPERVISA]->(cto)
CREATE (ceo)-[:SUPERVISA]->(cfo)
// El CTO supervisa a los desarrolladores
CREATE (cto)-[:SUPERVISA]->(dev1)
CREATE (cto)-[:SUPERVISA]->(dev2)
// El CFO supervisa al área financiera
CREATE (cfo)-[:SUPERVISA]->(contador)

// Consulta 1: Encontrar toda la jerarquía bajo el CTO
// MATCH: Patrón con longitud variable [:SUPERVISA*]
// El asterisco indica "una o más relaciones SUPERVISA en secuencia"
MATCH (cto:Empleado {puesto: "CTO"})-[:SUPERVISA*]->(subordinado:Empleado)
RETURN subordinado.nombre, subordinado.puesto
// Resultado: Marta (Desarrolladora Senior), Jorge (Desarrollador Junior)

// Consulta 2: Encontrar el jefe DIRECTO de Jorge (solo 1 nivel arriba)
// MATCH: Sin asterisco = exactamente una relación
MATCH (jefe:Empleado)-[:SUPERVISA]->(jorge:Empleado {nombre: "Jorge"})
RETURN jefe.nombre, jefe.puesto
// Resultado: Teresa (CTO)

// Consulta 3: Encontrar TODA la cadena de mando hasta el CEO
// MATCH: shortestPath desde el CEO hasta Jorge
MATCH camino = (ceo:Empleado {puesto: "CEO"})-[:SUPERVISA*]->(jorge:Empleado {nombre: "Jorge"})
// nodes(camino): Extrae todos los nodos de la ruta
RETURN [empleado IN nodes(camino) | empleado.nombre] AS cadena_de_mando
// Resultado: ["Carlos", "Teresa", "Jorge"]
```

### 3.5 Relaciones Temporales (Bitemporal)

**Relaciones Temporales:** Modelar relaciones que cambian en el tiempo. Muy útil para historial laboral, cambios de estado, evolución de relaciones, etc.

```cypher
// Escenario: Un empleado puede cambiar de departamento a lo largo del tiempo
// Necesitamos mantener el historial completo de movimientos

// CREATE: Crear el empleado y los departamentos
CREATE (empleado:Empleado {nombre: "Laura"})
CREATE (ventasDepot:Departamento {nombre: "Ventas"})
CREATE (marketingDepot:Departamento {nombre: "Marketing"})

// Crear relaciones con propiedades temporales
// desde: Fecha de inicio en el departamento
// hasta: Fecha de salida (NULL si está actualmente en ese departamento)

// Laura trabajó en Ventas desde 2020 hasta finales de 2022
CREATE (empleado)-[:TRABAJO_EN {desde: date('2020-01-01'), hasta: date('2022-12-31')}]->(ventasDepot)

// Laura está en Marketing desde 2023 (hasta es NULL porque sigue ahí)
CREATE (empleado)-[:TRABAJO_EN {desde: date('2023-01-01'), hasta: null}]->(marketingDepot)

// Consulta 1: ¿En qué departamento está Laura ACTUALMENTE? (hasta es NULL)
// MATCH: Buscar a Laura y sus relaciones TRABAJO_EN
MATCH (laura:Empleado {nombre: "Laura"})-[rel:TRABAJO_EN]->(d:Departamento)
// WHERE: Filtrar solo la relación actual (hasta es NULL)
WHERE rel.hasta IS NULL
RETURN d.nombre
// Resultado: Marketing

// Consulta 2: Obtener el historial completo de Laura
// MATCH: Buscar todas las relaciones TRABAJO_EN (pasadas y presentes)
MATCH (laura:Empleado {nombre: "Laura"})-[rel:TRABAJO_EN]->(d:Departamento)
// RETURN: Devolver cada departamento con sus fechas
RETURN d.nombre, rel.desde, rel.hasta
// ORDER BY: Ordenar cronológicamente
ORDER BY rel.desde
// Resultado:
// Ventas, 2020-01-01, 2022-12-31
// Marketing, 2023-01-01, null
```

---

## 4. Índices y Constraints en Neo4j (Profundización)

Los índices mejoran el rendimiento de las búsquedas, y los constraints garantizan la integridad de los datos. Son fundamentales para bases de datos en producción.

### 4.1 Tipos de Índices

**Índice de Búsqueda de Texto (Fulltext Index):**  
Permite búsquedas de texto completo similares a un motor de búsqueda. Ideal para buscar palabras clave en títulos, descripciones, contenidos, etc.

```cypher
// Crear un índice de búsqueda de texto completo
// Permite buscar palabras clave en el título Y contenido de los posts
// FOR (p:Post): Aplica a nodos con etiqueta :Post
// ON EACH [p.titulo, p.contenido]: Indexa ambas propiedades
CREATE FULLTEXT INDEX busqueda_posts FOR (p:Post) ON EACH [p.titulo, p.contenido]

// Usar el índice para búsqueda de texto
// CALL: Invoca un procedimiento almacenado de Neo4j
// db.index.fulltext.queryNodes: Función para búsqueda fulltext
// 'busqueda_posts': Nombre del índice que creamos arriba
// 'viaje OR receta': Query de búsqueda (OR significa cualquiera de las dos palabras)
CALL db.index.fulltext.queryNodes('busqueda_posts', 'viaje OR receta')
// YIELD: Devuelve resultados del procedimiento
// node: El nodo encontrado
// score: Relevancia de la coincidencia (más alto = más relevante)
YIELD node, score
RETURN node.titulo, score
// ORDER BY: Mostrar primero los más relevantes
ORDER BY score DESC
```

**Índice de Rango (Range Index):**  
Optimiza búsquedas con comparadores (<, >, <=, >=, BETWEEN). Ideal para fechas, números, edades, precios, etc.

```cypher
// Crear un índice de rango en la propiedad edad
// Acelera búsquedas como "edad > 25", "edad BETWEEN 20 AND 30"
// FOR (u:Usuario): Aplica a nodos con etiqueta :Usuario
// ON (u.edad): Indexa la propiedad edad
CREATE INDEX usuario_edad_index FOR (u:Usuario) ON (u.edad)

// Las consultas con comparadores ahora serán más rápidas
// MATCH: Buscar usuarios
MATCH (u:Usuario)
// WHERE: Filtrar por rango de edad (usa el índice automáticamente)
WHERE u.edad > 25 AND u.edad < 35
RETURN u.nombre, u.edad
```

**Índice Compuesto (Composite Index):**  
Indexa múltiples propiedades juntas. Útil cuando frecuentemente filtras por varias propiedades a la vez.

```cypher
// Crear un índice compuesto para búsquedas por ciudad Y edad
// Acelera consultas que filtran por AMBAS propiedades simultáneamente
// FOR (u:Usuario): Aplica a nodos :Usuario
// ON (u.ciudad, u.edad): Indexa ambas propiedades en orden
CREATE INDEX usuario_ciudad_edad FOR (u:Usuario) ON (u.ciudad, u.edad)

// Esta consulta usará el índice compuesto
// Es más rápido que usar dos índices separados
MATCH (u:Usuario)
// WHERE: Filtrar por ciudad Y edad (el orden importa)
WHERE u.ciudad = "Madrid" AND u.edad > 30
RETURN u.nombre
```

### 4.2 Tipos de Constraints

**Constraint de Unicidad (Uniqueness Constraint):**  
Garantiza que no puede haber dos nodos con el mismo valor en una propiedad. Similar a PRIMARY KEY o UNIQUE en SQL.

```cypher
// Crear una constraint de unicidad en el email
// Garantiza que no puede haber dos usuarios con el mismo email
// FOR (u:Usuario): Aplica a nodos :Usuario
// REQUIRE u.email IS UNIQUE: La propiedad email debe ser única
CREATE CONSTRAINT email_unico FOR (u:Usuario) REQUIRE u.email IS UNIQUE

// Intentar crear un usuario con un email que ya existe devolverá un error
// CREATE (u:Usuario {email: "maria@email.com"}) // ERROR: Email ya existe

// Nota: Las constraints de unicidad también crean un índice automáticamente
// No necesitas crear un índice separado para la propiedad
```

**Constraint de Existencia (Existence Constraint) - Solo Neo4j Enterprise:**  
Garantiza que todos los nodos de un tipo DEBEN tener una propiedad específica (no puede ser NULL).

```cypher
// Garantiza que todos los nodos :Usuario DEBEN tener la propiedad email
// FOR (u:Usuario): Aplica a nodos :Usuario
// REQUIRE u.email IS NOT NULL: La propiedad email es obligatoria
CREATE CONSTRAINT email_requerido FOR (u:Usuario) REQUIRE u.email IS NOT NULL

// Ahora no podrás crear un usuario sin email
// CREATE (u:Usuario {nombre: "Pedro"}) // ERROR: email es obligatorio
```

**Constraint de Clave (Node Key Constraint) - Solo Neo4j Enterprise:**  
Combina unicidad Y existencia en múltiples propiedades. Similar a PRIMARY KEY compuesta en SQL.

```cypher
// Un :Empleado debe tener empresa e id_empleado únicos JUNTOS
// Y ambas propiedades deben existir (no NULL)
// FOR (e:Empleado): Aplica a nodos :Empleado
// REQUIRE (e.empresa, e.id_empleado) IS NODE KEY: Clave compuesta
CREATE CONSTRAINT empleado_key FOR (e:Empleado) REQUIRE (e.empresa, e.id_empleado) IS NODE KEY

// Ahora puedes tener:
// {empresa: "TechCorp", id_empleado: "001"} 
// {empresa: "StartupXYZ", id_empleado: "001"} (diferente empresa)
// Pero NO puedes tener dos empleados con la MISMA combinación
```

### 4.3 Gestión de Índices y Constraints

Es importante saber cómo ver y eliminar índices y constraints cuando sea necesario.

```cypher
// Listar todos los índices de la base de datos
// SHOW INDEXES: Muestra nombre, tipo, estado y propiedades indexadas
SHOW INDEXES

// Listar todas las constraints de la base de datos
// SHOW CONSTRAINTS: Muestra nombre, tipo y propiedades afectadas
SHOW CONSTRAINTS

// Eliminar un índice específico (usar el nombre que aparece en SHOW INDEXES)
// DROP INDEX: Remueve el índice, las búsquedas serán más lentas
DROP INDEX usuario_edad_index

// Eliminar una constraint específica (usar el nombre que aparece en SHOW CONSTRAINTS)
// DROP CONSTRAINT: Remueve la restricción, permitirá duplicados o valores NULL
DROP CONSTRAINT email_unico

//  IMPORTANTE: Al eliminar una constraint de unicidad, el índice asociado
// también se elimina automáticamente
```

---

## 5. Optimización de Consultas de Grafos

La optimización es crucial para bases de datos grandes. Neo4j tiene herramientas para analizar y mejorar el rendimiento de tus consultas.

### 5.1 Uso de EXPLAIN y PROFILE

**EXPLAIN:** Muestra el plan de ejecución estimado SIN ejecutar la consulta. Útil para ver cómo Neo4j procesará tu consulta antes de ejecutarla.

```cypher
// EXPLAIN: Muestra qué pasos seguirá Neo4j, pero NO ejecuta la consulta
// Útil para consultas que pueden ser lentas y quieres optimizar antes de ejecutar
EXPLAIN
MATCH (u:Usuario)-[:PUBLICO]->(p:Post)
WHERE u.ciudad = "Madrid"
RETURN u.nombre, p.titulo

// El resultado mostrará el plan de ejecución con operaciones como:
// - NodeByLabelScan: Escanea todos los nodos con esa etiqueta
// - NodeIndexSeek: Usa un índice (mucho más rápido)
// - Filter: Aplica condiciones WHERE
// - Expand(All): Recorre relaciones desde un nodo
```

**PROFILE:** Ejecuta la consulta Y muestra estadísticas REALES de rendimiento. Muestra cuántas filas se procesaron y cuántas operaciones de base de datos se hicieron.

```cypher
// PROFILE: Ejecuta la consulta y muestra estadísticas detalladas
// Úsalo para identificar cuellos de botella en consultas lentas
PROFILE
MATCH (u:Usuario)-[:PUBLICO]->(p:Post)
WHERE u.ciudad = "Madrid"
RETURN u.nombre, p.titulo

// El resultado mostrará:
// - Rows: Número de filas procesadas en cada paso
// - DB hits: Accesos a la base de datos (MENOS es mejor)
// - Time: Tiempo que tomó cada operación (solo en Enterprise)
```

**¿Qué buscar en el plan de ejecución?**
- **NodeByLabelScan:** Escanea TODOS los nodos con esa etiqueta (lento sin filtros)
- **NodeIndexSeek:** Usa un índice (RÁPIDO - esto es lo que quieres ver)
- **Expand(All):** Recorre todas las relaciones desde un nodo
- **db hits:** Número de accesos a la base de datos (cuanto MENOR, mejor)

### 5.2 Optimización: Filtrar Temprano

**Regla de Oro:** Filtra los datos lo más pronto posible en la consulta. Reduce el número de nodos a procesar desde el inicio.

```cypher
// MAL: Filtrar DESPUÉS de expandir las relaciones
// Esto encuentra a todos los usuarios, expande todas sus relaciones,
// y LUEGO filtra por nombre (muy ineficiente)
MATCH (u:Usuario)-[:SIGUE]->(seguido:Usuario)
WHERE u.nombre = "Maria"
RETURN seguido.nombre

// BIEN: Filtrar PRIMERO, expandir después
// Primero encuentra solo a Maria (usando índice si existe),
// luego expande solo sus relaciones (mucho más rápido)
MATCH (u:Usuario {nombre: "Maria"})-[:SIGUE]->(seguido:Usuario)
RETURN seguido.nombre

// El filtro {nombre: "Maria"} en el patrón MATCH es más eficiente
// que usar WHERE después, porque permite a Neo4j usar índices desde el inicio
```

### 5.3 Optimización: Usar Etiquetas Específicas

**Regla:** SIEMPRE usa etiquetas en tus consultas. Sin etiquetas, Neo4j debe escanear TODOS los nodos de la base de datos.

```cypher
// MAL: Sin etiqueta, escanea TODOS los nodos de la base
// Si tienes 1 millón de nodos de diferentes tipos, escaneará todos
MATCH (n)
WHERE n.nombre = "Ana"
RETURN n

// BIEN: Con etiqueta, solo escanea nodos :Usuario
// Si tienes 10,000 usuarios y 990,000 otros nodos, esto es 100x más rápido
MATCH (u:Usuario)
WHERE u.nombre = "Ana"
RETURN u

// MEJOR: Usar el patrón inline cuando sea posible
// Permite a Neo4j optimizar aún más la consulta
MATCH (u:Usuario {nombre: "Ana"})
RETURN u

// Regla: Cuanto más específico seas con las etiquetas y propiedades,
// más rápido será tu consulta
```

### 5.4 Optimización: Limitar la Profundidad de Rutas Variables

**Peligro:** Las rutas sin límite pueden explorar millones de nodos en grafos grandes o causar bucles infinitos en grafos con ciclos.

```cypher
// PELIGROSO: Puede explorar infinitamente si hay ciclos
// En una red social grande, esto podría intentar encontrar TODOS los usuarios
// conectados indirectamente (puede ser millones de personas)
MATCH (u:Usuario {nombre: "Maria"})-[:SIGUE*]->(otros:Usuario)
RETURN otros.nombre

// BIEN: Limitar la profundidad de búsqueda
// [:SIGUE*1..3] significa "entre 1 y 3 relaciones de distancia"
// 1 = amigos directos
// 2 = amigos de amigos
// 3 = amigos de amigos de amigos
MATCH (u:Usuario {nombre: "Maria"})-[:SIGUE*1..3]->(otros:Usuario)
RETURN otros.nombre

// TAMBIÉN VÁLIDO: Solo una profundidad específica
// [:SIGUE*2] significa "exactamente 2 relaciones de distancia"
MATCH (u:Usuario {nombre: "Maria"})-[:SIGUE*2]->(otros:Usuario)
RETURN otros.nombre

// Regla: SIEMPRE especifica un límite razonable para rutas variables
// Típicamente 1..5 es suficiente para la mayoría de casos de uso
```

### 5.5 Optimización: Evitar Productos Cartesianos

**Producto Cartesiano:** Cuando combinas dos conjuntos sin relacionarlos, obtienes TODAS las combinaciones posibles (muy lento y generalmente incorrecto).

```cypher
// MAL: Esto crea un producto cartesiano
// Si tienes 100 usuarios y 200 posts, devolverá 20,000 filas (100 × 200)
// Porque está combinando CADA usuario con CADA post sin relación
MATCH (u:Usuario)
MATCH (p:Post)
RETURN u.nombre, p.titulo

// Neo4j mostrará un WARNING sobre producto cartesiano en el plan EXPLAIN

// BIEN: Relacionar explícitamente los nodos
// Ahora solo devuelve los posts que cada usuario realmente publicó
MATCH (u:Usuario)-[:PUBLICO]->(p:Post)
RETURN u.nombre, p.titulo

// Regla: Si ves un warning de "Cartesian Product" en EXPLAIN,
// probablemente tu consulta esté mal escrita. Busca cómo relacionar los nodos.
```

### 5.6 Optimización: Usar WITH para Reducir Datos Intermedios

**WITH:** Permite filtrar y reducir datos en etapas intermedias, antes de continuar con operaciones más costosas.

```cypher
// Ejemplo: Queremos encontrar usuarios activos y luego ver a quién siguen
// Filtrar usuarios con pocos posts ANTES de expandir la red social

// MATCH: Buscar usuarios y sus posts
MATCH (u:Usuario)-[:PUBLICO]->(p:Post)
// WITH: Contar posts y crear variable intermedia
WITH u, count(p) AS num_posts
// WHERE: Filtrar usuarios con pocos posts ANTES de la siguiente expansión
// Esto reduce drásticamente el número de nodos a procesar
WHERE num_posts > 2  // Solo usuarios con más de 2 posts
// MATCH: Ahora sí, expandir la red social solo de usuarios activos
MATCH (u)-[:SIGUE]->(otros:Usuario)
// RETURN: Devolver resultados finales
RETURN u.nombre, num_posts, collect(otros.nombre) AS sigue_a

// Ventaja: Si solo 10 de 100 usuarios tienen >2 posts,
// solo expandirás relaciones para 10 usuarios en lugar de 100
```

### 5.7 Optimización: Evitar OPTIONAL MATCH Innecesarios

**OPTIONAL MATCH:** Tiene un costo de rendimiento. Solo úsalo cuando realmente necesites incluir filas con valores NULL.

```cypher
// MENOS EFICIENTE: Si sabes que la relación DEBE existir
// OPTIONAL MATCH hace trabajo extra para manejar casos NULL
OPTIONAL MATCH (u:Usuario)-[:PUBLICO]->(p:Post)
RETURN u.nombre, p.titulo

// MÁS EFICIENTE: Si la relación es obligatoria, usa MATCH normal
// Esto permite a Neo4j optimizar mejor la consulta
MATCH (u:Usuario)-[:PUBLICO]->(p:Post)
RETURN u.nombre, p.titulo

// Regla: Usa OPTIONAL MATCH solo cuando:
// - Quieras incluir nodos aunque no tengan la relación (con valores NULL)
// - Ejemplo: Mostrar TODOS los usuarios, tengan o no posts
MATCH (u:Usuario)
OPTIONAL MATCH (u)-[:PUBLICO]->(p:Post)
RETURN u.nombre, count(p) AS num_posts  // Devolverá 0 para usuarios sin posts
```

### 5.8 Optimización: Reescribir con EXISTS para Filtros de Existencia

**EXISTS:** Es más eficiente que contar elementos cuando solo necesitas saber si algo existe o no.

```cypher
// MENOS EFICIENTE: Contar para verificar existencia
// size() cuenta TODOS los posts del usuario (trabajo innecesario)
MATCH (u:Usuario)
WHERE size((u)-[:PUBLICO]->(:Post)) > 0
RETURN u.nombre

// MÁS EFICIENTE: Usar EXISTS (para atrás)
// EXISTS se detiene en cuanto encuentra UNA coincidencia (no cuenta todas)
MATCH (u:Usuario)
WHERE EXISTS { (u)-[:PUBLICO]->(:Post) }
RETURN u.nombre

// TAMBIÉN VÁLIDO: Expresión de patrón (Neo4j 5+)
// Sintaxis más corta que hace lo mismo que EXISTS
MATCH (u:Usuario)
WHERE (u)-[:PUBLICO]->(:Post)
RETURN u.nombre

// Regla: Para preguntas de "¿existe al menos uno?", usa EXISTS o expresión de patrón
// Para "¿cuántos?", usa count() o size()
```

### 5.9 Monitoreo de Rendimiento

Neo4j ofrece herramientas para monitorear consultas en ejecución y detectar cuellos de botella.

```cypher
// Ver consultas que están corriendo actualmente (Neo4j Enterprise)
// CALL: Invoca un procedimiento del sistema
// dbms.listQueries(): Lista todas las consultas activas
CALL dbms.listQueries()
// YIELD: Extrae campos específicos del resultado
YIELD query, elapsedTimeMillis, status
// WHERE: Filtrar solo consultas lentas (más de 1 segundo)
WHERE elapsedTimeMillis > 1000
RETURN query, elapsedTimeMillis, status

// Resultado: Muestra las consultas lentas, cuánto tiempo llevan ejecutándose,
// y su estado (running, waiting, etc.)

// Terminar una consulta específica que está tardando mucho (por queryId)
// Útil si una consulta mal escrita está consumiendo recursos
// CALL dbms.killQuery('query-123')  // Reemplaza 'query-123' con el ID real
```

```


## 8. Limpieza y Reset del Entorno Avanzado

Herramientas para limpiar datos específicos o resetear completamente tu entorno de prueba.

```cypher
// 1. Eliminar solo nodos de un tipo específico (y sus relaciones)
// Útil cuando quieres limpiar una categoría sin afectar el resto

// MATCH: Buscar todos los nodos :Ciudad
MATCH (c:Ciudad)
// DETACH DELETE: Elimina el nodo Y todas sus relaciones automáticamente
// Sin DETACH daría error si el nodo tiene relaciones
DETACH DELETE c
// Resultado: Elimina todas las ciudades y carreteras, pero usuarios y posts quedan intactos

// 2. Eliminar relaciones de un tipo específico (mantener nodos)
// Útil cuando quieres "desconectar" nodos sin eliminarlos

// MATCH: Buscar todas las relaciones :CARRETERA (sin importar dirección)
MATCH ()-[r:CARRETERA]-()
// DELETE: Eliminar solo las relaciones (los nodos quedan)
DELETE r
// Resultado: Las ciudades siguen existiendo, pero ya no están conectadas

// 3. Reset completo (borrar TODO)
//  PELIGROSO: Elimina TODOS los nodos y TODAS las relaciones
// Solo usar en entornos de desarrollo/prueba, NUNCA en producción

// MATCH: Buscar absolutamente todos los nodos (sin filtro)
MATCH (n)
// DETACH DELETE: Eliminar cada nodo y todas sus relaciones
DETACH DELETE n
// Resultado: Base de datos completamente vacía (como recién creada)

// 4. Eliminar todos los índices y constraints
// Primero, ver qué hay para eliminar:
SHOW CONSTRAINTS
SHOW INDEXES

// Luego, eliminar uno por uno usando los nombres que aparecen arriba:
// DROP CONSTRAINT usuario_nombre_unique
// DROP CONSTRAINT email_unico
// DROP INDEX usuario_edad_index
// DROP INDEX busqueda_posts

// Nota: No hay un comando para eliminar TODOS los índices/constraints de golpe
// Debes eliminarlos individualmente basándote en sus nombres
```


