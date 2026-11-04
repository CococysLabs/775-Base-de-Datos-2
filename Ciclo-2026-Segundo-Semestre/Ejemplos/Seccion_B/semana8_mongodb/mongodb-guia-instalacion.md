# Guía de instalación de MongoDB

MongoDB es una base de datos NoSQL orientada a documentos que almacena la información en formato BSON (similar a JSON). Esta guía cubre la instalación de **MongoDB Community Edition** en Linux, macOS, Windows y Docker.

> Los ejemplos usan la serie **8.0**. Si existe una versión más reciente, reemplaza `8.0` por la que corresponda.

## Requisitos previos

- Acceso a una terminal con permisos de administrador (`sudo`).
- Conexión a internet.
- Puerto `27017` disponible (puerto por defecto de MongoDB).
- Arquitectura de 64 bits (x86_64 o ARM64).

---

## 1. Linux

### Ubuntu 22.04 / 24.04 (repositorio oficial)

1. Instala las dependencias:

   ```bash
   sudo apt-get install -y gnupg curl
   ```

2. Importa la clave pública de MongoDB:

   ```bash
   curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
     sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
   ```

3. Agrega el repositorio (elige **una** según tu versión de Ubuntu):

   ```bash
   # Ubuntu 22.04 (jammy)
   echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" | \
     sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

   # Ubuntu 24.04 (noble)
   echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | \
     sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
   ```

4. Instala MongoDB:

   ```bash
   sudo apt-get update
   sudo apt-get install -y mongodb-org
   ```

   Este paquete incluye el servidor (`mongod`), la shell (`mongosh`) y herramientas como `mongodump` y `mongoimport`.

### RHEL / Rocky / AlmaLinux / Fedora

1. Crea el archivo `/etc/yum.repos.d/mongodb-org-8.0.repo`:

   ```ini
   [mongodb-org-8.0]
   name=MongoDB Repository
   baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/8.0/x86_64/
   gpgcheck=1
   enabled=1
   gpgkey=https://pgp.mongodb.com/server-8.0.asc
   ```

2. Instala:

   ```bash
   sudo dnf install -y mongodb-org
   ```

### Iniciar y habilitar el servicio

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mongod
sudo systemctl status mongod
```

---

## 2. macOS

Con [Homebrew](https://brew.sh):

```bash
brew tap mongodb/brew
brew update
brew install mongodb-community@8.0

# Iniciar como servicio en segundo plano
brew services start mongodb-community@8.0

# Detener el servicio
brew services stop mongodb-community@8.0
```

---

## 3. Windows

1. Descarga el instalador **MSI** desde: <https://www.mongodb.com/try/download/community>
2. Ejecuta el instalador y elige **Complete**.
3. Marca **Install MongoDB as a Service** para que se inicie automáticamente.
4. (Opcional) Marca **Install MongoDB Compass**, la interfaz gráfica oficial.
5. Si `mongosh` no se instaló, descárgalo desde: <https://www.mongodb.com/try/download/shell>

Verifica el servicio desde PowerShell:

```powershell
Get-Service MongoDB
```

---

## 4. Docker (cualquier sistema operativo)

```bash
docker run -d \
  --name mongodb \
  -p 27017:27017 \
  -v mongo-data:/data/db \
  mongo:latest
```

| Opción | Descripción |
|---|---|
| `-d` | Ejecuta el contenedor en segundo plano |
| `--name mongodb` | Nombre del contenedor |
| `-p 27017:27017` | Expone el puerto de MongoDB |
| `-v mongo-data:/data/db` | Volumen para persistir los datos |

Con usuario administrador inicial:

```bash
docker run -d \
  --name mongodb \
  -p 27017:27017 \
  -v mongo-data:/data/db \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=TuContraseñaSegura \
  mongo:latest
```

Abrir la shell dentro del contenedor:

```bash
docker exec -it mongodb mongosh
```

---

## 5. Verificar la instalación

```bash
mongod --version
mongosh
```

Dentro de `mongosh`:

```javascript
db.runCommand({ ping: 1 })
```

Respuesta esperada:

```javascript
{ ok: 1 }
```

---

## 6. Configuración básica

Archivo de configuración principal:

| Sistema | Ruta |
|---|---|
| Linux | `/etc/mongod.conf` |
| macOS (Homebrew, Apple Silicon) | `/opt/homebrew/etc/mongod.conf` |
| macOS (Homebrew, Intel) | `/usr/local/etc/mongod.conf` |
| Windows | `C:\Program Files\MongoDB\Server\8.0\bin\mongod.cfg` |

Ejemplo de configuración:

```yaml
storage:
  dbPath: /var/lib/mongodb

systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true

net:
  port: 27017
  bindIp: 127.0.0.1

security:
  authorization: enabled
```

Reinicia el servicio tras cambiar la configuración:

```bash
sudo systemctl restart mongod
```

---

## 7. Crear un usuario administrador

Antes de activar `authorization: enabled`, crea un usuario:

```javascript
// En mongosh
use admin

db.createUser({
  user: "admin",
  pwd: passwordPrompt(),   // solicita la contraseña de forma interactiva
  roles: [{ role: "root", db: "admin" }]
})
```

Luego activa la autenticación en `/etc/mongod.conf`, reinicia el servicio y conéctate así:

```bash
mongosh -u admin --authenticationDatabase admin
```

---

## 8. Recomendaciones de seguridad

- **No expongas MongoDB directamente a internet.** Mantén `bindIp: 127.0.0.1` o usa una red privada/VPN.
- Activa siempre la autenticación (`authorization: enabled`).
- Usa roles con el mínimo de privilegios necesarios.
- Restringe el puerto `27017` con un firewall.
- Mantén MongoDB actualizado y realiza copias de seguridad periódicas.

---

## 9. Solución de problemas

| Problema | Solución |
|---|---|
| `MongoNetworkError: connect ECONNREFUSED` | Verifica que el servicio esté activo: `sudo systemctl status mongod` |
| El servicio no inicia | Revisa los logs: `sudo tail -n 50 /var/log/mongodb/mongod.log` |
| Error de permisos en `/var/lib/mongodb` | `sudo chown -R mongodb:mongodb /var/lib/mongodb /var/log/mongodb` |
| Puerto 27017 ocupado | Revisa el proceso: `sudo lsof -i :27017` o cambia `net.port` |
| `Authentication failed` | Usa `--authenticationDatabase admin` al conectarte |

---

## 10. Desinstalación

```bash
# Ubuntu / Debian
sudo systemctl stop mongod
sudo apt-get purge -y "mongodb-org*"
sudo rm -r /var/log/mongodb /var/lib/mongodb

# RHEL / Fedora
sudo systemctl stop mongod
sudo dnf remove -y mongodb-org
sudo rm -r /var/log/mongodb /var/lib/mongo

# macOS
brew services stop mongodb-community@8.0
brew uninstall mongodb-community@8.0

# Docker
docker rm -f mongodb && docker volume rm mongo-data
```

---

## Recursos

- Documentación oficial: <https://www.mongodb.com/docs/manual/>
- Guías de instalación: <https://www.mongodb.com/docs/manual/installation/>
- Descargas: <https://www.mongodb.com/try/download/community>
