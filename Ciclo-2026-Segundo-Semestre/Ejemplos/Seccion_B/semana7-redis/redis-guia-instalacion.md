# Guía de instalación de Redis

Redis es una base de datos en memoria de tipo clave-valor, usada como caché, broker de mensajes y almacén de datos de acceso rápido. Esta guía cubre la instalación en Linux, macOS, Windows y Docker.

## Requisitos previos

- Acceso a una terminal con permisos de administrador (`sudo`).
- Conexión a internet.
- Puerto `6379` disponible (puerto por defecto de Redis).

---

## 1. Linux

### Ubuntu / Debian (repositorio oficial de Redis, recomendado)

Este método instala una versión más reciente que la de los repositorios por defecto.

```bash
sudo apt-get install -y lsb-release curl gpg

curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

sudo apt-get update
sudo apt-get install -y redis
```

### Ubuntu / Debian (repositorio por defecto)

Más simple, pero la versión puede ser más antigua.

```bash
sudo apt update
sudo apt install -y redis-server
```

### RHEL / Fedora / Rocky / AlmaLinux

```bash
sudo dnf install -y redis
```

### Iniciar y habilitar el servicio

```bash
# Ubuntu/Debian (el servicio puede llamarse redis-server o redis)
sudo systemctl enable --now redis-server

# RHEL/Fedora
sudo systemctl enable --now redis
```

Comprobar el estado:

```bash
sudo systemctl status redis-server
```

---

## 2. macOS

Con [Homebrew](https://brew.sh):

```bash
brew install redis

# Iniciar como servicio en segundo plano
brew services start redis

# O iniciar manualmente en primer plano
redis-server
```

---

## 3. Windows

Redis no tiene soporte oficial nativo en Windows. Las opciones recomendadas son:

### Opción A: WSL2 (recomendado)

1. Abre PowerShell como administrador e instala WSL:

   ```powershell
   wsl --install
   ```

2. Reinicia el equipo y abre la distribución de Ubuntu instalada.
3. Sigue los pasos de la sección **Ubuntu / Debian** de esta guía.
4. Inicia Redis:

   ```bash
   sudo service redis-server start
   ```

### Opción B: Docker Desktop

Consulta la sección siguiente.

---

## 4. Docker (cualquier sistema operativo)

```bash
docker run -d \
  --name redis \
  -p 6379:6379 \
  -v redis-data:/data \
  redis:latest \
  redis-server --appendonly yes
```

| Opción | Descripción |
|---|---|
| `-d` | Ejecuta el contenedor en segundo plano |
| `--name redis` | Nombre del contenedor |
| `-p 6379:6379` | Expone el puerto de Redis |
| `-v redis-data:/data` | Volumen para persistir los datos |
| `--appendonly yes` | Activa la persistencia AOF |

Abrir el cliente dentro del contenedor:

```bash
docker exec -it redis redis-cli
```

---

## 5. Verificar la instalación

```bash
redis-server --version
redis-cli ping
```

La respuesta esperada del segundo comando es:

```
PONG
```

---

## 6. Configuración básica

El archivo de configuración suele estar en:

| Sistema | Ruta |
|---|---|
| Ubuntu / Debian | `/etc/redis/redis.conf` |
| RHEL / Fedora | `/etc/redis/redis.conf` |
| macOS (Homebrew, Apple Silicon) | `/opt/homebrew/etc/redis.conf` |
| macOS (Homebrew, Intel) | `/usr/local/etc/redis.conf` |

Parámetros importantes:

```conf
# Escuchar solo en localhost (más seguro)
bind 127.0.0.1 -::1

# Puerto
port 6379

# Contraseña de acceso
requirepass TuContraseñaSegura

# Límite de memoria y política de expulsión
maxmemory 256mb
maxmemory-policy allkeys-lru

# Persistencia
appendonly yes
```

Después de modificar la configuración, reinicia el servicio:

```bash
sudo systemctl restart redis-server
```

Si definiste contraseña, conéctate así:

```bash
redis-cli -a TuContraseñaSegura
```

---

## 7. Recomendaciones de seguridad

- **No expongas Redis directamente a internet.** Mantén `bind 127.0.0.1` o usa una red privada.
- Configura siempre `requirepass` o, mejor, usuarios con ACL.
- Restringe el puerto `6379` con un firewall.
- Mantén Redis actualizado.

---

## 8. Solución de problemas

| Problema | Solución |
|---|---|
| `Could not connect to Redis at 127.0.0.1:6379` | Verifica que el servicio esté activo: `sudo systemctl status redis-server` |
| Puerto 6379 ocupado | Revisa qué proceso lo usa: `sudo lsof -i :6379` o cambia `port` en la configuración |
| `NOAUTH Authentication required` | Conéctate con contraseña: `redis-cli -a <contraseña>` |
| El servicio no inicia | Consulta los logs: `sudo journalctl -u redis-server -n 50` |

---

## 9. Desinstalación

```bash
# Ubuntu / Debian
sudo apt-get remove --purge -y redis redis-server

# RHEL / Fedora
sudo dnf remove -y redis

# macOS
brew services stop redis && brew uninstall redis

# Docker
docker rm -f redis && docker volume rm redis-data
```

---

## Recursos

- Documentación oficial: <https://redis.io/docs/>
- Guía de instalación oficial: <https://redis.io/docs/latest/operate/oss_and_stack/install/install-stack/>
