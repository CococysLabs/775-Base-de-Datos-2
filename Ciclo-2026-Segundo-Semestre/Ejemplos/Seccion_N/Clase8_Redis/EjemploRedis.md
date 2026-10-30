
## 1. Iniciar Redis con Docker

abre una terminal en el directorio del proyecto y ejecuta:

```bash
docker-compose up -d
```

Para conectarte a la instancia de Redis a través de la línea de comandos, ejecuta:

```bash
docker exec -it redis_ejemplos redis-cli
```
Una vez dentro, puedes usar el comando `PING` para verificar la conexión. Debería responder con `PONG`.

```redis
PING
```

## 2. Claves (Keys)

Las claves son el identificador único para cada dato en Redis. Una buena nomenclatura es crucial.

**Buena práctica:** Usar dos puntos para crear espacios de nombres (`objeto:id:campo`).

```redis
# SET: Asigna un valor a una clave. Si la clave ya existe, sobrescribe el valor.
SET producto:1001:color "Azul"

# GET: Obtiene el valor de una clave.
GET producto:1001:color
```

**Mala práctica:** Nombres largos, poco claros o sin estructura.

```redis
# Evitar esto
SET ElColorDelProductoConElId1001 "Azul"
```

**Comandos de gestión de claves :**

```redis
# Establecemos varias claves para los ejemplos
SET usuario:1:nombre "Juan"
SET usuario:1:email "juan@example.com"
SET producto:1001:stock 50

# EXISTS: Comprueba si una clave existe. Devuelve 1 (true) o 0 (false).
EXISTS producto:1001:stock  # Devuelve 1 (true)

# KEYS: Busca claves que coincidan con un patrón. El asterisco (*) es un comodín.
KEYS producto:*  # Devuelve "producto:1001:color", "producto:1001:stock"
KEYS usuario:1:* # Devuelve "usuario:1:nombre", "usuario:1:email"
KEYS *:email    # Devuelve "usuario:1:email"

# RENAME: Cambia el nombre de una clave.
RENAME usuario:1:nombre usuario:1:nombre_completo
EXISTS usuario:1:nombre # Devuelve 0 (false)
EXISTS usuario:1:nombre_completo # Devuelve 1 (true)

# TYPE: Devuelve el tipo de dato almacenado en una clave (string, list, hash, etc.).
TYPE producto:1001:color # Devuelve "string"

# DEL: Elimina una o más claves.
DEL usuario:1:nombre_completo producto:1001:color
```

## 3. Cadenas de Texto (Strings)

El tipo de dato más simple. Ideal para contadores, cachés de fragmentos de HTML, o valores simples.

```redis
# Guardar el estado de un servicio
SET servicio:notificaciones:estado "activo"
GET servicio:notificaciones:estado

# INCR: Incrementa en 1 el valor de una clave (que debe ser un número).
SET pagina:inicio:visitas 0
INCR pagina:inicio:visitas
INCR pagina:inicio:visitas
GET pagina:inicio:visitas # Devuelve "2"

# INCRBY: Incrementa el valor de una clave en una cantidad específica.
INCRBY pagina:inicio:visitas 10 # Devuelve "12"

# DECR: Decrementa en 1 el valor de una clave.
DECR producto:1001:stock # Devuelve 49
# DECRBY: Decrementa el valor de una clave en una cantidad específica.
DECRBY producto:1001:stock 5 # Devuelve 44
```

**Ejemplos avanzados con Strings:**

```redis
# SETEX: Asigna un valor a una clave con un tiempo de expiración en segundos.
# Guarda el fragmento de HTML de la página de inicio por 1 hora (3600s)
SETEX cache:html:inicio 3600 "<html>...</html>"
# TTL: Muestra el tiempo de vida restante de una clave.
TTL cache:html:inicio # Muestra el tiempo restante

# MSET: Asigna múltiples claves y valores en una sola operación.
MSET config:sitio:titulo "Mi Web" config:sitio:tema "oscuro"
# MGET: Obtiene los valores de múltiples claves en una sola operación.
MGET config:sitio:titulo config:sitio:tema # Devuelve "Mi Web" y "oscuro"
```

Joshua Vasquez - 202102407
Bases de datos 2 Seccion N
## 4. Diccionarios (Hashes)

Para almacenar objetos con múltiples campos. Mucho más eficiente en memoria que usar strings para cada campo de un objeto.

```redis
# HSET: Asigna un valor a un campo dentro de un hash.
HSET usuario:501 nombre "Ana" email "ana@correo.com" pais "Mexico"

# HGETALL: Obtiene todos los campos y valores de un hash.
HGETALL usuario:501

# HGET: Obtiene el valor de un campo específico de un hash.
HGET usuario:501 email
# HMGET: Obtiene los valores de múltiples campos de un hash.
HMGET usuario:501 nombre pais

# Actualizar la edad del usuario
HSET usuario:501 edad "30"

# HINCRBY: Incrementa el valor numérico de un campo en un hash.
HINCRBY usuario:501 posts 1
HINCRBY usuario:501 posts 5 # Devuelve 6
```

**Ejemplos avanzados con Hashes:**

```redis
# HLEN: Devuelve el número de campos en un hash.
HLEN usuario:501 # Devuelve 4 (nombre, email, pais, edad, posts)

# HDEL: Elimina uno o más campos de un hash.
HDEL usuario:501 pais
HGETALL usuario:501 # "pais" ya no aparece

# HKEYS: Obtiene solo los nombres de los campos de un hash.
HKEYS usuario:501 # Devuelve "nombre", "email", "edad", "posts"
# HVALS: Obtiene solo los valores de los campos de un hash.
HVALS usuario:501 # Devuelve "Ana", "ana@correo.com", "30", "6"
```

## 5. Colecciones en Fila (Lists)

Una colección de strings ordenados por inserción. Ideal para colas, historiales o logs.

```redis
# LPUSH: Añade uno o más elementos al principio (izquierda) de una lista.
# Caso de uso: Log de eventos recientes
LPUSH log:eventos "Usuario X inició sesión"
LPUSH log:eventos "Error en el servicio de pagos"
LPUSH log:eventos "Usuario Y actualizó su perfil"

# LRANGE: Obtiene un rango de elementos de una lista.
# Ver los últimos 10 eventos
LRANGE log:eventos 0 9

# RPUSH: Añade uno o más elementos al final (derecha) de una lista.
# Caso de uso: Cola de tareas (FIFO - First-In, First-Out)
RPUSH cola:impresion "documento1.pdf"
RPUSH cola:impresion "documento2.docx"

# LPOP: Elimina y devuelve el primer elemento (de la izquierda) de una lista.
# Un "worker" procesa el documento más antiguo
LPOP cola:impresion # Devuelve "documento1.pdf"
LPOP cola:impresion # Devuelve "documento2.docx"
```

**Ejemplos avanzados con Lists:**

```redis
# LTRIM: Recorta una lista para que solo contenga el rango de elementos especificado.
# Mantener una lista con un tamaño fijo (ej: solo los últimos 5 eventos)
LPUSH log:eventos "Nuevo evento 1"
LPUSH log:eventos "Nuevo evento 2"
# ... se agregan muchos eventos ...
LTRIM log:eventos 0 4 # Mantiene solo los 5 elementos más recientes

# LREM: Elimina ocurrencias de un valor de una lista.
LPUSH historial:comandos "ls"
LPUSH historial:comandos "cd"
LPUSH historial:comandos "ls"
LREM historial:comandos 2 "ls" # Elimina las 2 ocurrencias de "ls"

# LINDEX: Obtiene un elemento de una lista por su índice.
LINDEX log:eventos 0 # Devuelve el elemento más reciente
```

## 6. Agrupaciones Únicas (Sets)

Colección de strings únicos sin orden específico. Ideal para tags, IDs únicos, etc.

```redis
# SADD: Añade uno o más miembros a un set. Los duplicados son ignorados.
# Registrar los tags de un artículo de blog (no permite duplicados)
SADD articulo:123:tags "tecnologia" "redis" "database"
SADD articulo:123:tags "redis"  # Este será ignorado

# SMEMBERS: Obtiene todos los miembros de un set.
SMEMBERS articulo:123:tags

# SISMEMBER: Comprueba si un miembro existe en un set.
SISMEMBER articulo:123:tags "tecnologia" # Devuelve 1

# SCARD: Devuelve el número de miembros en un set (su "cardinalidad").
SCARD articulo:123:tags # Devuelve 3
```

**Ejemplos avanzados con Sets (operaciones entre conjuntos):**

```redis
# Tags de otro artículo
SADD articulo:456:tags "tecnologia" "nodejs" "javascript"

# SINTER: Devuelve los miembros que son comunes a todos los sets dados (intersección).
SINTER articulo:123:tags articulo:456:tags # Devuelve "tecnologia"

# SUNION: Devuelve los miembros de la unión de todos los sets dados.
SUNION articulo:123:tags articulo:456:tags

# SDIFF: Devuelve la diferencia entre el primer set y los siguientes.
SDIFF articulo:123:tags articulo:456:tags # Devuelve "redis", "database"
```

## 7. Agrupaciones Ordenadas (Sorted Sets)

Similar a los Sets, pero cada miembro tiene un "score" (puntuación) que se usa para ordenarlos. Perfecto para rankings, tablas de posiciones o colas de prioridad.

```redis
# ZADD: Añade uno o más miembros con su puntuación a un sorted set.
# Crear un tablero de puntuaciones de un juego
ZADD ranking:juego 1500 "jugador1"
ZADD ranking:juego 2100 "jugador2"
ZADD ranking:juego 1800 "jugador3"

# Si un miembro ya existe, ZADD actualiza su puntuación.
ZADD ranking:juego 2200 "jugador1"

# ZREVRANGE: Obtiene un rango de miembros ordenados de mayor a menor puntuación.
# Obtener el top 3 de jugadores (de mayor a menor puntuación)
ZREVRANGE ranking:juego 0 2 WITHSCORES

# ZSCORE: Obtiene la puntuación de un miembro específico.
ZSCORE ranking:juego "jugador3" # Devuelve "1800"

# ZREVRANK: Devuelve la posición (rank) de un miembro, ordenado de mayor a menor.
ZREVRANK ranking:juego "jugador1" # Devuelve 0 (es el primero)
```

**Ejemplos avanzados con Sorted Sets:**

```redis
# ZRANGEBYSCORE: Obtiene miembros cuya puntuación está dentro de un rango.
# Jugadores con score entre 1000 y 1800
ZRANGEBYSCORE ranking:juego 1000 1800 WITHSCORES

# ZREM: Elimina uno o más miembros de un sorted set.
ZREM ranking:juego "jugador3"

# Caso de uso: Tareas con prioridad (el score es la prioridad, menor es más importante)
ZADD cola:prioridad 1 "Enviar emails de alta prioridad"
ZADD cola:prioridad 10 "Generar reporte semanal"
ZADD cola:prioridad 5 "Reindexar base de datos"

# ZRANGE: Obtiene un rango de miembros ordenados de menor a mayor puntuación.
# Un "worker" siempre tomará la tarea de menor score (mayor prioridad)
ZRANGE cola:prioridad 0 0 # Devuelve "Enviar emails de alta prioridad"
```

## 8. Emisión Pub/Sub (Publicar/Suscribir)

Sistema de mensajería en tiempo real. No almacena los mensajes.

docker exec -it redis_ejemplos redis-cli

**Terminal 1 (Suscriptor):**
```redis
# SUBSCRIBE: Se suscribe a uno o más canales para recibir mensajes.
SUBSCRIBE canal:notificaciones canal:chat:general
```

**Terminal 2 (Publicador):**
```redis
# PUBLISH: Envía un mensaje a un canal. Todos los suscriptores lo reciben.
# Publicar un mensaje en el canal de notificaciones
PUBLISH canal:notificaciones "Nuevo pedido #9876 recibido!"

# Publicar un mensaje en el chat general
PUBLISH canal:chat:general "Hola a todos!"
```
La Terminal 1 recibirá ambos mensajes instantáneamente, indicando de qué canal provienen.

## 9. Transacciones Protegidas

Ejecutar un grupo de comandos como una única operación atómica.

```redis
# Simular una transferencia de saldo entre dos cuentas
SET cuenta:A:saldo 500
SET cuenta:B:saldo 200

# MULTI: Inicia un bloque de transacción. Los comandos no se ejecutan de inmediato.
MULTI

# Los comandos se encolan. Responden con "QUEUED".
DECRBY cuenta:A:saldo 100
INCRBY cuenta:B:saldo 100

# EXEC: Ejecuta todos los comandos encolados desde MULTI de forma atómica.
EXEC
# GET cuenta:A:saldo -> 400
# GET cuenta:B:saldo -> 300
```

**Ejemplo avanzado con `WATCH` (Optimistic Locking):**
`WATCH` permite cancelar una transacción si una clave "vigilada" es modificada por otro cliente.

**Terminal 1:**
```redis
# WATCH: Vigila una o más claves para detectar modificaciones.
WATCH cuenta:A:saldo # Vigilar cambios en el saldo de A
MULTI
DECRBY cuenta:A:saldo 100
INCRBY cuenta:B:saldo 100
# Antes de ejecutar EXEC, vamos a la Terminal 2...
```

**Terminal 2:**
```redis
# Otro proceso (ej: un cargo inesperado) modifica la clave vigilada
INCRBY cuenta:A:saldo 50 # El saldo ahora es 550
```

**Volver a Terminal 1:**
```redis
# Si una clave vigilada cambió, EXEC falla y devuelve (nil).
EXEC # La transacción falla y devuelve (nil)
# porque la clave 'cuenta:A:saldo' fue modificada.
# El programador debe reintentar la operación.
```

## 10. Eliminación Programada (TTL - Time To Live)

Asignar un tiempo de vida a una clave.

```redis
# Crear una clave para un código de verificación de un solo uso
SET token:verificacion:abc "a1b2c3d4"

# EXPIRE: Establece un tiempo de vida (en segundos) para una clave.
EXPIRE token:verificacion:abc 300

# TTL: Consulta el tiempo de vida restante de una clave (en segundos).
TTL token:verificacion:abc

# PERSIST: Elimina el tiempo de expiración de una clave, haciéndola persistente.
PERSIST token:verificacion:abc
TTL token:verificacion:abc # Devuelve -1 (no expira)

# Después de 5 minutos (si no se usó PERSIST), la clave ya no existe
GET token:verificacion:abc # Devuelve (nil)
```

