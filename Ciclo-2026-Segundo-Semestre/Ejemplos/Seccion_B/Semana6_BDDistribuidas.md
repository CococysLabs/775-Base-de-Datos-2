# Laboratorio: Replicación de MySQL (Source → Replica) en Ubuntu Server

**Asignatura:** Bases de Datos 2
**Tema:** Replicación asíncrona basada en GTID con MySQL 8.0
**Entorno:** 2 máquinas virtuales con Ubuntu Server 22.04 / 24.04 LTS

---

## 1. Objetivos

- Instalar y configurar dos servidores MySQL en máquinas virtuales distintas.
- Configurar un servidor **Source** (antes llamado *master*) y un servidor **Replica** (antes *slave*).
- Verificar que los cambios realizados en el Source se replican automáticamente en la Replica.
- Diagnosticar y resolver errores comunes de replicación.

## 2. Conceptos previos

| Concepto | Descripción |
|---|---|
| **Source** | Servidor principal, recibe las escrituras y las registra en el *binary log*. |
| **Replica** | Servidor secundario, copia y aplica los eventos del Source. |
| **Binary log (binlog)** | Archivo donde el Source registra todos los cambios de datos. |
| **Relay log** | Copia local del binlog que guarda la Replica antes de aplicarlo. |
| **IO thread** | Hilo de la Replica que descarga el binlog del Source. |
| **SQL thread** | Hilo de la Replica que ejecuta los eventos del relay log. |
| **GTID** | Identificador global de transacción (`UUID:número`). Simplifica la replicación porque no hay que indicar archivo ni posición del binlog. |

Flujo de la replicación:

```
 Cliente ──► SOURCE (escribe + binlog) ──► IO thread ──► relay log ──► SQL thread ──► REPLICA
```

## 3. Topología del laboratorio

| Máquina | Rol | Hostname | IP de ejemplo | server-id |
|---|---|---|---|---|
| VM1 | Source | `mysql-source` | `192.168.56.10` | 1 |
| VM2 | Replica | `mysql-replica` | `192.168.56.11` | 2 |

> Ajuste las IP a su red. Las dos VMs deben poder comunicarse entre sí.
> En VirtualBox/VMware use **Red interna**, **Host-only** o **Adaptador puente** (no basta NAT simple sin reenvío de puertos).

---

## 4. Preparación de las máquinas virtuales

### 4.1 Asignar nombre de host (en cada VM)

```bash
# VM1
sudo hostnamectl set-hostname mysql-source
# VM2
sudo hostnamectl set-hostname mysql-replica
```

### 4.2 Verificar la IP y la conectividad

```bash
ip a
ping -c 3 192.168.56.11     # desde VM1
ping -c 3 192.168.56.10     # desde VM2
```

### 4.3 (Opcional) IP estática con Netplan

Edite `/etc/netplan/00-installer-config.yaml` (el nombre del archivo puede variar y `enp0s8` debe ser su interfaz):

```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      addresses: [192.168.56.10/24]   # 192.168.56.11/24 en la VM2
```

```bash
sudo netplan apply
```

### 4.4 Sincronizar hora y actualizar paquetes (en ambas)

```bash
sudo apt update && sudo apt upgrade -y
timedatectl status
```

> ⚠️ **Si la VM2 es un clon de la VM1**, MySQL tendría el mismo `server_uuid` en ambas y la replicación fallará. Ver la sección 12 (Troubleshooting) antes de continuar. Lo más seguro es instalar MySQL **después** de clonar.

---

## 5. Instalación de MySQL (en ambas VMs)

```bash
sudo apt install mysql-server -y
sudo systemctl enable --now mysql
sudo systemctl status mysql
mysql --version
```

Asegurar la instalación (opcional pero recomendado):

```bash
sudo mysql_secure_installation
```

Acceso inicial como administrador:

```bash
sudo mysql
```

> Defina una contraseña para `root` si lo desea:
> ```sql
> ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'Root_Lab2025!';
> ```

---

## 6. Configuración del SOURCE (VM1)

### 6.1 Editar el archivo de configuración

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Busque y modifique (o agregue) en la sección `[mysqld]`:

```ini
[mysqld]
# --- Red ---
bind-address            = 0.0.0.0        # o la IP 192.168.56.10
mysqlx-bind-address     = 127.0.0.1

# --- Replicación ---
server-id               = 1
log_bin                 = /var/log/mysql/mysql-bin.log
binlog_format           = ROW
binlog_expire_logs_seconds = 604800      # 7 días

# --- GTID ---
gtid_mode               = ON
enforce_gtid_consistency = ON

# --- (Opcional) replicar solo una base de datos ---
# binlog_do_db          = laboratorio
```

> En MySQL 8.0 el binlog ya viene activado por defecto; aun así es buena práctica declararlo de forma explícita.

### 6.2 Reiniciar y verificar

```bash
sudo systemctl restart mysql
sudo mysql -e "SHOW VARIABLES WHERE Variable_name IN ('server_id','log_bin','gtid_mode','binlog_format');"
```

Resultado esperado: `server_id = 1`, `log_bin = ON`, `gtid_mode = ON`, `binlog_format = ROW`.

### 6.3 Abrir el puerto 3306 solo para la Replica

```bash
sudo ufw allow from 192.168.56.11 to any port 3306 proto tcp
sudo ufw status
```

> Si `ufw` está inactivo, no es necesario; en un entorno real debería estar activo.

### 6.4 Crear el usuario de replicación

```bash
sudo mysql
```

```sql
CREATE USER 'repl'@'192.168.56.11' IDENTIFIED BY 'Repl_Lab2025!';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'192.168.56.11';
FLUSH PRIVILEGES;
```

### 6.5 Crear la base de datos de prueba

```sql
CREATE DATABASE laboratorio;
USE laboratorio;

CREATE TABLE estudiantes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    carrera VARCHAR(100),
    creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO estudiantes (nombre, carrera) VALUES
('Ana López', 'Ingeniería en Sistemas'),
('Carlos Pérez', 'Ingeniería en Sistemas');
```

### 6.6 Verificar el estado del Source

```sql
SHOW BINARY LOG STATUS;   -- MySQL 8.4+
-- En MySQL 8.0 use:
SHOW MASTER STATUS;
```

Debe mostrar el archivo de binlog actual y un valor en `Executed_Gtid_Set`.

---

## 7. Copia inicial de los datos (dump del Source)

Como el Source ya contiene datos, hay que copiarlos a la Replica **antes** de iniciar la replicación.

En la **VM1 (Source)**:

```bash
mysqldump -u root -p \
  --databases laboratorio \
  --single-transaction \
  --routines --triggers --events \
  --set-gtid-purged=ON \
  > /tmp/laboratorio.sql
```

Enviar el archivo a la VM2:

```bash
scp /tmp/laboratorio.sql usuario@192.168.56.11:/tmp/
```

> Reemplace `usuario` por un usuario válido de la VM2 (requiere `openssh-server`: `sudo apt install openssh-server -y`).

> **Nota:** si la base de datos está vacía o aún no existe, este paso puede omitirse; la Replica recibirá todo desde el inicio del binlog.

---

## 8. Configuración de la REPLICA (VM2)

### 8.1 Editar el archivo de configuración

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

```ini
[mysqld]
bind-address            = 0.0.0.0
mysqlx-bind-address     = 127.0.0.1

# --- Replicación ---
server-id               = 2
relay_log               = /var/log/mysql/mysql-relay-bin.log
log_bin                 = /var/log/mysql/mysql-bin.log
log_replica_updates     = ON

# --- GTID ---
gtid_mode               = ON
enforce_gtid_consistency = ON

# --- Protección: la Replica solo lee ---
read_only               = ON
super_read_only         = ON
```

> `log_bin` y `log_replica_updates` en la Replica son opcionales, pero permiten promoverla a Source o encadenar réplicas (ver ejercicios).

```bash
sudo systemctl restart mysql
sudo mysql -e "SHOW VARIABLES WHERE Variable_name IN ('server_id','gtid_mode','read_only','super_read_only');"
```

### 8.2 Probar la conexión hacia el Source

```bash
sudo apt install mysql-client -y     # si no está instalado
mysql -h 192.168.56.10 -u repl -p -e "SELECT 'Conexión OK' AS estado;"
```

Si falla, revise la sección 12.

### 8.3 Importar el dump

La Replica tiene `super_read_only` activo, así que se debe desactivar temporalmente (el usuario `root` local sí puede):

```bash
sudo mysql
```

```sql
SET GLOBAL super_read_only = OFF;
SET GLOBAL read_only = OFF;
RESET MASTER;          -- limpia GTIDs ejecutados (necesario antes de importar un dump con GTID_PURGED)
SOURCE /tmp/laboratorio.sql;
SET GLOBAL read_only = ON;
SET GLOBAL super_read_only = ON;
```

Verificar:

```sql
SELECT * FROM laboratorio.estudiantes;
```

> En MySQL 8.4 el comando `RESET MASTER` se llama `RESET BINARY LOGS AND GTIDS`.

### 8.4 Conectar la Replica con el Source

```sql
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = '192.168.56.10',
    SOURCE_PORT = 3306,
    SOURCE_USER = 'repl',
    SOURCE_PASSWORD = 'Repl_Lab2025!',
    SOURCE_AUTO_POSITION = 1,
    GET_SOURCE_PUBLIC_KEY = 1;

START REPLICA;
```

> - `SOURCE_AUTO_POSITION = 1` activa la replicación por GTID (no hace falta indicar archivo/posición).
> - `GET_SOURCE_PUBLIC_KEY = 1` es necesario porque `caching_sha2_password` requiere SSL o intercambio de clave pública. En producción se recomienda usar SSL (`SOURCE_SSL = 1`).
> - En versiones anteriores a 8.0.23 la sintaxis es `CHANGE MASTER TO ...`, `MASTER_HOST`, `START SLAVE`.

---

## 9. Verificación del estado

En la **Replica**:

```sql
SHOW REPLICA STATUS\G
```

Campos que deben revisarse:

| Campo | Valor esperado |
|---|---|
| `Replica_IO_Running` | `Yes` |
| `Replica_SQL_Running` | `Yes` |
| `Seconds_Behind_Source` | `0` (o un número pequeño) |
| `Last_IO_Error` | vacío |
| `Last_SQL_Error` | vacío |
| `Retrieved_Gtid_Set` / `Executed_Gtid_Set` | con valores y coincidiendo con el Source |

En versiones antiguas el comando es `SHOW SLAVE STATUS\G` y los campos son `Slave_IO_Running`, `Slave_SQL_Running`, `Seconds_Behind_Master`.

---

## 10. Pruebas de funcionamiento

### 10.1 Escribir en el Source

En la **VM1**:

```sql
USE laboratorio;
INSERT INTO estudiantes (nombre, carrera) VALUES ('María Gómez', 'Ingeniería Industrial');
UPDATE estudiantes SET carrera = 'Ingeniería en Ciencias y Sistemas' WHERE nombre = 'Ana López';
CREATE TABLE cursos (id INT PRIMARY KEY, nombre VARCHAR(80));
INSERT INTO cursos VALUES (1, 'Bases de Datos 2');
```

### 10.2 Leer en la Replica

En la **VM2**:

```sql
USE laboratorio;
SELECT * FROM estudiantes;
SELECT * FROM cursos;
```

Los datos deben aparecer sin intervención manual.

### 10.3 Comprobar que la Replica es de solo lectura

En la **VM2**:

```sql
INSERT INTO laboratorio.estudiantes (nombre, carrera) VALUES ('Prueba', 'X');
```

Debe devolver un error similar a:

```
ERROR 1290 (HY000): The MySQL server is running with the --super-read-only option...
```

### 10.4 Comparar GTIDs

```sql
-- En ambas VMs
SELECT @@GLOBAL.gtid_executed;
```

Deben coincidir (o la Replica ir apenas por detrás).

### 10.5 Probar tolerancia a fallos de la Replica

```bash
# VM2
sudo systemctl stop mysql
```

En la VM1 inserte más datos. Luego:

```bash
# VM2
sudo systemctl start mysql
```

```sql
SHOW REPLICA STATUS\G
```

La Replica debe ponerse al día sola gracias a los GTID.

---

## 11. Comandos útiles de administración

```sql
STOP REPLICA;                    -- detiene IO y SQL threads
START REPLICA;                   -- los inicia
STOP REPLICA IO_THREAD;          -- detiene solo uno
SHOW PROCESSLIST;                -- en el Source se ve el hilo "Binlog Dump GTID"
SHOW REPLICAS;                   -- en el Source, lista las réplicas conectadas (8.0.22+)
RESET REPLICA ALL;               -- elimina la configuración de replicación
SHOW BINARY LOGS;                -- lista los binlogs del Source
```

Revisar logs de MySQL:

```bash
sudo tail -n 50 /var/log/mysql/error.log
```

---

## 12. Solución de problemas (Troubleshooting)

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Last_IO_Error: Fatal error: The slave I/O thread stops because master and slave have equal MySQL server UUIDs` | VM clonada, mismo `server_uuid` | En la Replica: `sudo systemctl stop mysql && sudo rm /var/lib/mysql/auto.cnf && sudo systemctl start mysql` (se genera un UUID nuevo). |
| `Last_IO_Error: error connecting to source ... (110)` | Firewall, red o `bind-address` | Verificar `ping`, `ufw`, `bind-address` y `ss -tlnp \| grep 3306` en el Source. |
| `Access denied for user 'repl'@...` | Usuario/clave/host incorrectos | Revisar `SELECT user, host FROM mysql.user;` en el Source y corregir `CHANGE REPLICATION SOURCE TO`. |
| `Authentication requires secure connection` / error de RSA | Falta `GET_SOURCE_PUBLIC_KEY` o SSL | Añadir `GET_SOURCE_PUBLIC_KEY = 1` y volver a ejecutar `CHANGE REPLICATION SOURCE TO`. |
| `Replica_SQL_Running: No` con error 1062 (duplicate key) o 1032 | Se escribió directamente en la Replica | Ver abajo "Saltar una transacción con GTID". |
| `Got fatal error 1236 ... purged binary logs` | El Source ya borró binlogs que la Replica necesita | Reconstruir la Replica con un nuevo dump (secciones 7 y 8). |
| `ERROR 3546: @@GLOBAL.GTID_PURGED cannot be changed` | La Replica ya tenía GTIDs | Ejecutar `RESET MASTER;` antes de importar el dump. |
| `Can't connect to MySQL server on '192.168.56.10'` | `bind-address = 127.0.0.1` | Cambiarlo, reiniciar MySQL. |

### Saltar una transacción con error (usando GTID)

Si en `SHOW REPLICA STATUS\G` aparece un error de SQL en una transacción concreta, identifique su GTID (campo `Last_SQL_Error`, p. ej. `uuid:15`) y ejecute en la Replica:

```sql
STOP REPLICA;
SET GTID_NEXT = 'uuid-del-source:15';
BEGIN; COMMIT;
SET GTID_NEXT = 'AUTOMATIC';
START REPLICA;
```

> Es una medida de emergencia: saltar transacciones deja las réplicas **inconsistentes**. Úsela solo con fines didácticos.

---

## 13. Ejercicios propuestos

1. Explique la diferencia entre replicación **asíncrona**, **semisíncrona** y **grupal** (Group Replication).
2. Configure la replicación para que solo se repliquen las tablas de la base `laboratorio` (`replicate-do-db` / `binlog_do_db`) y compruebe que otra base no se replica.
3. Cambie `binlog_format` a `STATEMENT` y `MIXED`, ejecute `INSERT ... VALUES (UUID())` y analice las diferencias con `SHOW BINLOG EVENTS`.
4. Provoque un error de replicación insertando un registro directamente en la Replica, y resuélvalo.
5. **Failover manual:** detenga el Source, promueva la Replica (`STOP REPLICA; RESET REPLICA ALL; SET GLOBAL read_only=OFF; SET GLOBAL super_read_only=OFF;`) y redirija las aplicaciones a ella.
6. Una vez promovida la VM2, reconfigure la VM1 como Replica de la VM2.
7. Agregue una **tercera VM** como segunda Replica del mismo Source.
8. Mida el retraso (`Seconds_Behind_Source`) ejecutando una carga grande (`INSERT` masivo) en el Source.
9. Active SSL en la replicación (`SOURCE_SSL = 1`) y verifique el cifrado.

---

## 14. Restablecer el laboratorio (limpieza)

En la **Replica**:

```sql
STOP REPLICA;
RESET REPLICA ALL;
DROP DATABASE laboratorio;
```

En el **Source**:

```sql
DROP DATABASE laboratorio;
DROP USER 'repl'@'192.168.56.11';
RESET MASTER;
```

---

## 15. Entregables sugeridos

- Capturas de pantalla de: `SHOW REPLICA STATUS\G` (con IO y SQL en `Yes`), los datos en la Source y en la Replica, y el error de escritura en la Replica de solo lectura.
- Archivos `mysqld.cnf` de ambas máquinas.
- Respuestas a los ejercicios propuestos.
- Breve informe con los problemas encontrados y cómo se resolvieron.

---

## 16. Referencias

- MySQL 8.0 Reference Manual — *Replication*: <https://dev.mysql.com/doc/refman/8.0/en/replication.html>
- MySQL 8.0 Reference Manual — *Replication with Global Transaction Identifiers*: <https://dev.mysql.com/doc/refman/8.0/en/replication-gtids.html>
- Ubuntu Server Documentation — *MySQL*: <https://documentation.ubuntu.com/server/how-to/databases/install-mysql/>
