# Introducción práctica a MongoDB

Este ejemplo te guía por los conceptos básicos de MongoDB usando `mongosh`, y termina con un pequeño programa en Python. Se asume que MongoDB ya está instalado y en ejecución (consulta `mongodb-guia-instalacion.md`).

## Conceptos clave

| Concepto SQL | Concepto MongoDB |
|---|---|
| Base de datos | Base de datos (`database`) |
| Tabla | Colección (`collection`) |
| Fila | Documento (`document`) |
| Columna | Campo (`field`) |

Un documento es un objeto JSON, y los documentos de una misma colección **no necesitan tener la misma estructura**.

---

## 1. Conectarse

```bash
mongosh
```

Si tienes autenticación activada:

```bash
mongosh -u admin --authenticationDatabase admin
```

---

## 2. Bases de datos y colecciones

```javascript
// Ver bases de datos existentes
show dbs

// Seleccionar (o crear al insertar datos) una base de datos
use tienda

// Ver la base de datos actual
db

// Ver colecciones
show collections
```

> MongoDB crea la base de datos y la colección automáticamente al insertar el primer documento.

---

## 3. Insertar documentos (Create)

### Un documento

```javascript
db.productos.insertOne({
  nombre: "Laptop",
  precio: 850,
  categoria: "tecnologia",
  stock: 15,
  etiquetas: ["computadora", "portatil"]
})
```

### Varios documentos

```javascript
db.productos.insertMany([
  { nombre: "Mouse",    precio: 20,  categoria: "tecnologia", stock: 100 },
  { nombre: "Teclado",  precio: 45,  categoria: "tecnologia", stock: 60 },
  { nombre: "Silla",    precio: 150, categoria: "oficina",    stock: 25 },
  { nombre: "Escritorio", precio: 300, categoria: "oficina",  stock: 10 }
])
```

Cada documento recibe automáticamente un campo `_id` único (tipo `ObjectId`).

---

## 4. Consultar documentos (Read)

```javascript
// Todos los documentos
db.productos.find()

// Con formato legible
db.productos.find().pretty()

// Filtrar por igualdad
db.productos.find({ categoria: "oficina" })

// Un solo documento
db.productos.findOne({ nombre: "Laptop" })
```

### Operadores de comparación

```javascript
// Precio mayor que 100
db.productos.find({ precio: { $gt: 100 } })

// Precio entre 20 y 150
db.productos.find({ precio: { $gte: 20, $lte: 150 } })

// Categoría dentro de una lista
db.productos.find({ categoria: { $in: ["tecnologia", "oficina"] } })
```

### Operadores lógicos

```javascript
// Tecnología Y precio menor a 50
db.productos.find({ categoria: "tecnologia", precio: { $lt: 50 } })

// Precio menor a 30 O stock menor a 15
db.productos.find({ $or: [{ precio: { $lt: 30 } }, { stock: { $lt: 15 } }] })
```

### Proyección, orden y límite

```javascript
// Solo nombre y precio (sin _id), ordenado por precio descendente, máximo 3
db.productos
  .find({}, { nombre: 1, precio: 1, _id: 0 })
  .sort({ precio: -1 })
  .limit(3)
```

---

## 5. Actualizar documentos (Update)

```javascript
// Cambiar el precio de un producto
db.productos.updateOne(
  { nombre: "Mouse" },
  { $set: { precio: 25 } }
)

// Restar 1 al stock (incremento negativo)
db.productos.updateOne(
  { nombre: "Laptop" },
  { $inc: { stock: -1 } }
)

// Aplicar un descuento a toda una categoría
db.productos.updateMany(
  { categoria: "oficina" },
  { $mul: { precio: 0.9 } }
)

// Agregar un elemento a un arreglo
db.productos.updateOne(
  { nombre: "Laptop" },
  { $push: { etiquetas: "oferta" } }
)
```

---

## 6. Eliminar documentos (Delete)

```javascript
// Eliminar uno
db.productos.deleteOne({ nombre: "Silla" })

// Eliminar varios
db.productos.deleteMany({ stock: { $lt: 5 } })
```

> **Precaución:** `deleteMany({})` elimina **todos** los documentos de la colección.

---

## 7. Agregaciones

El *pipeline* de agregación procesa los documentos en etapas.

```javascript
// Precio promedio y total de productos por categoría
db.productos.aggregate([
  {
    $group: {
      _id: "$categoria",
      precioPromedio: { $avg: "$precio" },
      totalProductos: { $sum: 1 },
      stockTotal: { $sum: "$stock" }
    }
  },
  { $sort: { precioPromedio: -1 } }
])
```

Resultado de ejemplo:

```javascript
[
  { _id: 'oficina',    precioPromedio: 202.5, totalProductos: 2, stockTotal: 35 },
  { _id: 'tecnologia', precioPromedio: 230,   totalProductos: 3, stockTotal: 175 }
]
```

---

## 8. Índices

Los índices aceleran las consultas sobre campos que se filtran con frecuencia.

```javascript
// Crear un índice en el campo nombre
db.productos.createIndex({ nombre: 1 })

// Índice único
db.productos.createIndex({ codigo: 1 }, { unique: true })

// Ver índices
db.productos.getIndexes()

// Verificar que una consulta usa el índice
db.productos.find({ nombre: "Laptop" }).explain("executionStats")
```

---

## 9. Ejemplo con Python (PyMongo)

### Instalación del cliente

```bash
pip install pymongo
```

### Código (`ejemplo_mongo.py`)

```python
from pymongo import MongoClient

# Conexión
cliente = MongoClient("mongodb://localhost:27017/")
db = cliente["tienda"]
productos = db["productos"]

# Limpiar la colección para el ejemplo
productos.delete_many({})

# 1. Insertar
productos.insert_many([
    {"nombre": "Laptop",  "precio": 850, "categoria": "tecnologia", "stock": 15},
    {"nombre": "Mouse",   "precio": 20,  "categoria": "tecnologia", "stock": 100},
    {"nombre": "Silla",   "precio": 150, "categoria": "oficina",    "stock": 25},
])
print("Documentos insertados:", productos.count_documents({}))

# 2. Consultar
print("\nProductos de tecnología:")
for p in productos.find({"categoria": "tecnologia"}, {"_id": 0}):
    print(" ", p)

# 3. Actualizar
productos.update_one({"nombre": "Mouse"}, {"$set": {"precio": 25}})
print("\nNuevo precio del Mouse:", productos.find_one({"nombre": "Mouse"})["precio"])

# 4. Agregación
print("\nPromedio de precio por categoría:")
pipeline = [
    {"$group": {"_id": "$categoria", "promedio": {"$avg": "$precio"}}},
    {"$sort": {"promedio": -1}},
]
for fila in productos.aggregate(pipeline):
    print(f"  {fila['_id']}: {fila['promedio']:.2f}")

# 5. Eliminar
productos.delete_one({"nombre": "Silla"})
print("\nDocumentos restantes:", productos.count_documents({}))

cliente.close()
```

### Ejecución

```bash
python ejemplo_mongo.py
```

### Salida esperada

```
Documentos insertados: 3

Productos de tecnología:
  {'nombre': 'Laptop', 'precio': 850, 'categoria': 'tecnologia', 'stock': 15}
  {'nombre': 'Mouse', 'precio': 20, 'categoria': 'tecnologia', 'stock': 100}

Nuevo precio del Mouse: 25

Promedio de precio por categoría:
  tecnologia: 437.50
  oficina: 150.00

Documentos restantes: 2
```

---

## 10. Resumen de operaciones CRUD

| Operación | mongosh | PyMongo |
|---|---|---|
| Crear uno | `insertOne()` | `insert_one()` |
| Crear varios | `insertMany()` | `insert_many()` |
| Leer | `find()` / `findOne()` | `find()` / `find_one()` |
| Actualizar | `updateOne()` / `updateMany()` | `update_one()` / `update_many()` |
| Eliminar | `deleteOne()` / `deleteMany()` | `delete_one()` / `delete_many()` |
| Agregar | `aggregate()` | `aggregate()` |

## Próximos pasos

- Aprende sobre **modelado de datos**: documentos embebidos vs. referencias.
- Explora **MongoDB Compass**, la interfaz gráfica oficial.
- Revisa **transacciones** y **replica sets** para alta disponibilidad.
- Prueba **MongoDB Atlas**, el servicio en la nube con un plan gratuito.
- Documentación oficial: <https://www.mongodb.com/docs/manual/>
