"""
Script SIMPLE para cargar usuarios a Neo4j desde CSV
"""

from neo4j import GraphDatabase
import csv

#CONFIGURACIÓN 
URI = "neo4j://127.0.0.1:7687"
USUARIO = "neo4j"
CONTRASEÑA = "12344321" 

# Conectar a Neo4j
print("Conectando a Neo4j...")
driver = GraphDatabase.driver(URI, auth=(USUARIO, CONTRASEÑA))

try:
    # Verificar conexión
    driver.verify_connectivity()
    print(" Conexión exitosa\n")
    
    # Leer CSV
    print("Leyendo archivo usuarios.csv...")
    with open('usuarios.csv', 'r', encoding='utf-8') as archivo:
        lector = csv.DictReader(archivo)
        usuarios = list(lector)
    
    print(f" {len(usuarios)} usuarios encontrados en el CSV\n")
    
    # Cargar usuarios uno por uno
    print("Cargando usuarios a Neo4j...")
    with driver.session() as session:
        for i, usuario in enumerate(usuarios, 1):
            # Crear o actualizar usuario
            session.run("""
                MERGE (u:Usuario {email: $email})
                SET u.nombre = $nombre,
                    u.edad = $edad,
                    u.ciudad = $ciudad,
                    u.telefono = $telefono,
                    u.profesion = $profesion
            """, 
                email=usuario['email'],
                nombre=usuario['nombre'],
                edad=int(usuario['edad']),
                ciudad=usuario['ciudad'],
                telefono=usuario['telefono'],
                profesion=usuario['profesion']
            )
            print(f"  [{i}/{len(usuarios)}]  {usuario['nombre']}")
    
    print(f"\n {len(usuarios)} usuarios cargados exitosamente")
    
    # Mostrar resultados
    print("\nVerificando datos en Neo4j...")
    with driver.session() as session:
        result = session.run("MATCH (u:Usuario) RETURN count(u) as total")
        total = result.single()["total"]
        print(f" Total de usuarios en la base de datos: {total}")

except FileNotFoundError:
    print(" ERROR: No se encuentra el archivo 'usuarios.csv'")
    print("  Asegúrate de que el archivo esté en la misma carpeta que este script")

except Exception as e:
    print(f" ERROR: {e}")

finally:
    # Cerrar conexión
    driver.close()
    print("\n Conexión cerrada")
