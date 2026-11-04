# Introducción práctica a Redis

Este ejemplo te guía por los conceptos básicos de Redis usando `redis-cli`, y termina con un pequeño programa en Python. Se asume que Redis ya está instalado y en ejecución (consulta `redis-guia-instalacion.md`).

## 1. Conectarse

```bash
redis-cli
```

Prueba la conexión:

```
127.0.0.1:6379> PING
PONG
```

---

## 2. Strings (cadenas)

El tipo más básico: una clave con un valor.

```
SET nombre "Ana"
GET nombre
```

Resultado:

```
"Ana"
```

### Contadores

```
SET visitas 0
INCR visitas
INCR visitas
INCRBY visitas 10
GET visitas
```

Resultado final: `"12"`

### Expiración (TTL)

Ideal para cachés y sesiones.

```
SET sesion:abc123 "usuario_42" EX 60
TTL sesion:abc123
```

La clave se elimina automáticamente a los 60 segundos. `TTL` devuelve los segundos restantes (`-2` si la clave ya no existe).

---

## 3. Hashes (objetos)

Un hash agrupa varios campos bajo una sola clave, como un objeto.

```
HSET usuario:1 nombre "Carlos" edad 30 ciudad "Guatemala"
HGET usuario:1 nombre
HGETALL usuario:1
HINCRBY usuario:1 edad 1
```

---

## 4. Listas

Colecciones ordenadas por inserción, útiles como colas.

```
RPUSH tareas "enviar correo" "revisar informe" "llamar cliente"
LRANGE tareas 0 -1
LPOP tareas
LLEN tareas
```

- `RPUSH` agrega al final.
- `LPOP` extrae del inicio (comportamiento de cola FIFO).

---

## 5. Sets (conjuntos)

Colecciones sin orden y sin elementos repetidos.

```
SADD lenguajes "python" "java" "go" "python"
SMEMBERS lenguajes
SISMEMBER lenguajes "go"
SCARD lenguajes
```

`"python"` se agregó dos veces, pero solo aparece una.

---

## 6. Sorted Sets (rankings)

Cada elemento tiene una puntuación; Redis los mantiene ordenados.

```
ZADD ranking 150 "ana" 230 "luis" 180 "maria"
ZRANGE ranking 0 -1 WITHSCORES
ZREVRANGE ranking 0 2 WITHSCORES
ZINCRBY ranking 100 "ana"
```

`ZREVRANGE` devuelve de mayor a menor puntuación (un top 3, por ejemplo).

---

## 7. Gestión de claves

```
KEYS usuario:*        # Busca claves por patrón (evitar en producción)
SCAN 0 MATCH usuario:* COUNT 100   # Alternativa segura
EXISTS nombre
TYPE usuario:1
DEL nombre
FLUSHDB               # Borra TODAS las claves de la base actual
```

> **Precaución:** `FLUSHDB` y `KEYS` no deben usarse a la ligera en producción.

---

## 8. Ejemplo con Python: caché de consultas

### Instalación del cliente

```bash
pip install redis
```

### Código (`ejemplo_redis.py`)

```python
import time
import redis

# Conexión (decode_responses devuelve str en lugar de bytes)
r = redis.Redis(host="localhost", port=6379, db=0, decode_responses=True)

# Verificar conexión
print("Conexión:", r.ping())


def consulta_lenta(id_usuario):
    """Simula una consulta costosa a una base de datos."""
    time.sleep(2)
    return f"Datos del usuario {id_usuario}"


def obtener_usuario(id_usuario):
    clave = f"cache:usuario:{id_usuario}"

    # 1. Buscar en caché
    valor = r.get(clave)
    if valor is not None:
        print("-> Resultado desde Redis (caché)")
        return valor

    # 2. Si no existe, consultar y guardar 30 segundos
    print("-> Consultando base de datos...")
    valor = consulta_lenta(id_usuario)
    r.set(clave, valor, ex=30)
    return valor


# Primera llamada: lenta
inicio = time.time()
print(obtener_usuario(7))
print(f"Tiempo: {time.time() - inicio:.2f} s\n")

# Segunda llamada: instantánea
inicio = time.time()
print(obtener_usuario(7))
print(f"Tiempo: {time.time() - inicio:.4f} s")
```

### Ejecución

```bash
python ejemplo_redis.py
```

### Salida esperada

```
Conexión: True
-> Consultando base de datos...
Datos del usuario 7
Tiempo: 2.00 s

-> Resultado desde Redis (caché)
Datos del usuario 7
Tiempo: 0.0005 s
```

La segunda llamada es mucho más rápida porque el resultado ya está en memoria.

---

## 9. Resumen de estructuras de datos

| Estructura | Comandos clave | Caso de uso típico |
|---|---|---|
| String | `SET`, `GET`, `INCR` | Caché, contadores, sesiones |
| Hash | `HSET`, `HGETALL` | Objetos (perfiles de usuario) |
| List | `RPUSH`, `LPOP` | Colas de tareas |
| Set | `SADD`, `SMEMBERS` | Etiquetas, valores únicos |
| Sorted Set | `ZADD`, `ZRANGE` | Rankings, leaderboards |

## Próximos pasos

- Explora **Pub/Sub** para mensajería en tiempo real.
- Aprende sobre **Streams** para procesamiento de eventos.
- Revisa las opciones de **persistencia** (RDB y AOF).
- Documentación oficial: <https://redis.io/docs/>
