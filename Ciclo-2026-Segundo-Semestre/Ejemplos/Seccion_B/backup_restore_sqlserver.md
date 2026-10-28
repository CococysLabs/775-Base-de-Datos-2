# Backups y Restauración en SQL Server – Base de datos `BD2S22026`

Guía práctica con un esquema sencillo de ventas: backup **completo**, **diferencial** (lo que comúnmente se llama "incremental" en SQL Server) y de **log de transacciones**. Al final se automatiza con **SQL Server Agent (Jobs)** y con el **Programador de tareas de Windows**.

> **Nota sobre "incremental":** SQL Server no tiene un backup incremental como tal. Lo más parecido es el backup **diferencial**, que guarda todos los cambios desde el *último backup completo*. Los backups de **log de transacciones** son los que guardan los cambios *incrementales* entre un punto y otro.

---

## Índice

1. [Esquema de ejemplo y datos de prueba](#1-esquema-de-ejemplo-y-datos-de-prueba)
2. [Preparación: modelo de recuperación y carpetas](#2-preparación-modelo-de-recuperación-y-carpetas)
3. [Comandos de backup](#3-comandos-de-backup)
4. [Simulación de un desastre y restauración](#4-simulación-de-un-desastre-y-restauración)
5. [Automatizar con SQL Server Agent (Jobs)](#5-automatizar-con-sql-server-agent-jobs)
6. [Automatizar con el Programador de tareas de Windows](#6-automatizar-con-el-programador-de-tareas-de-windows)
7. [Buenas prácticas](#7-buenas-prácticas)

---

## 1. Esquema de ejemplo y datos de prueba

### 1.1 Crear la base de datos y las tablas

```sql
CREATE DATABASE [BD2S22026];
GO

USE [BD2S22026];
GO

-- Clientes
CREATE TABLE cliente (
    id_cliente INT PRIMARY KEY,
    nombre     VARCHAR(50) NOT NULL UNIQUE
);

-- Productos
CREATE TABLE productos (
    id_producto INT PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE
);

-- Venta
CREATE TABLE BD2S22026.dbo.venta (
    id_venta   INT PRIMARY KEY IDENTITY,
    id_cliente INT NOT NULL,
    fecha      DATETIME NOT NULL
);

-- Detalle de venta
CREATE TABLE BD2S22026.dbo.detalle_venta (
    id_detalle_venta INT PRIMARY KEY IDENTITY,
    id_venta         INT NOT NULL,
    id_producto      INT NOT NULL,
    cantidad         INT NOT NULL,
    sub_total        DECIMAL NOT NULL
);

ALTER TABLE BD2S22026.dbo.detalle_venta
ADD CONSTRAINT fk_venta_detalle_venta
    FOREIGN KEY (id_venta) REFERENCES venta(id_venta);

ALTER TABLE BD2S22026.dbo.detalle_venta
ADD CONSTRAINT fk_venta_detalle_producto
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto);
GO
```

> **Observación:** `DECIMAL` sin precisión equivale a `DECIMAL(18,0)`, es decir, **sin decimales**. Para montos reales conviene usar `DECIMAL(10,2)`.

### 1.2 Datos iniciales (antes del backup completo)

```sql
USE [BD2S22026];
GO

INSERT INTO cliente (id_cliente, nombre) VALUES
(1, 'Ana López'),
(2, 'Carlos Pérez');

INSERT INTO productos (id_producto, nombre) VALUES
(1, 'Teclado'),
(2, 'Mouse'),
(3, 'Monitor');

INSERT INTO venta (id_cliente, fecha) VALUES (1, GETDATE());
INSERT INTO detalle_venta (id_venta, id_producto, cantidad, sub_total) VALUES (1, 1, 2, 300);
GO
```

---

## 2. Preparación: modelo de recuperación y carpetas

### 2.1 Cambiar el modelo de recuperación a FULL

Para poder hacer backups de **log de transacciones** (y restaurar a un punto en el tiempo), la base debe estar en modelo `FULL`:

```sql
USE master;
GO

ALTER DATABASE [BD2S22026] SET RECOVERY FULL;
GO

-- Verificar
SELECT name, recovery_model_desc
FROM sys.databases
WHERE name = 'BD2S22026';
```

### 2.2 Crear las carpetas de respaldo

Desde el Símbolo del sistema (CMD) o PowerShell:

```bat
mkdir C:\Backups\BD2S22026\FULL
mkdir C:\Backups\BD2S22026\DIFF
mkdir C:\Backups\BD2S22026\LOG
```

> La cuenta de servicio de SQL Server (por ejemplo `NT Service\MSSQLSERVER`) debe tener permisos de **escritura** sobre `C:\Backups`.

---

## 3. Comandos de backup

### 3.1 Backup completo (FULL)

Es la base de toda la cadena de respaldos. Debe existir antes que cualquier diferencial o log.

```sql
BACKUP DATABASE [BD2S22026]
TO DISK = N'C:\Backups\BD2S22026\FULL\BD2S22026_FULL.bak'
WITH
    INIT,                -- sobrescribe el archivo si existe
    NAME = N'BD2S22026 - Backup completo',
    COMPRESSION,         -- (no disponible en Express)
    CHECKSUM,
    STATS = 10;
GO
```

### 3.2 Agregar más datos y hacer un backup diferencial

```sql
USE [BD2S22026];
GO

INSERT INTO venta (id_cliente, fecha) VALUES (2, GETDATE());
INSERT INTO detalle_venta (id_venta, id_producto, cantidad, sub_total) VALUES (2, 2, 1, 80);
GO
```

```sql
BACKUP DATABASE [BD2S22026]
TO DISK = N'C:\Backups\BD2S22026\DIFF\BD2S22026_DIFF.bak'
WITH
    DIFFERENTIAL,        -- cambios desde el último FULL
    INIT,
    NAME = N'BD2S22026 - Backup diferencial',
    COMPRESSION,
    CHECKSUM,
    STATS = 10;
GO
```

### 3.3 Más cambios y backup del log de transacciones

```sql
USE [BD2S22026];
GO

INSERT INTO venta (id_cliente, fecha) VALUES (1, GETDATE());
INSERT INTO detalle_venta (id_venta, id_producto, cantidad, sub_total) VALUES (3, 3, 1, 1500);
GO
```

```sql
BACKUP LOG [BD2S22026]
TO DISK = N'C:\Backups\BD2S22026\LOG\BD2S22026_LOG_1.trn'
WITH
    INIT,
    NAME = N'BD2S22026 - Backup de log 1',
    COMPRESSION,
    CHECKSUM,
    STATS = 10;
GO
```

### 3.4 Un cambio más y un segundo backup de log

Guardamos la hora, la usaremos luego para restaurar a un punto en el tiempo:

```sql
SELECT GETDATE() AS hora_antes_del_error;   -- anótala, ej: 2026-10-27 10:15:00
GO

-- Simulamos un error humano: se borran las ventas por accidente
DELETE FROM detalle_venta;
DELETE FROM venta;
GO

BACKUP LOG [BD2S22026]
TO DISK = N'C:\Backups\BD2S22026\LOG\BD2S22026_LOG_2.trn'
WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;
GO
```

### 3.5 Verificar los backups

```sql
-- Verifica que el archivo sea legible
RESTORE VERIFYONLY
FROM DISK = N'C:\Backups\BD2S22026\FULL\BD2S22026_FULL.bak'
WITH CHECKSUM;

-- Historial de backups realizados
SELECT
    database_name,
    CASE type WHEN 'D' THEN 'FULL'
              WHEN 'I' THEN 'DIFERENCIAL'
              WHEN 'L' THEN 'LOG' END AS tipo,
    backup_start_date,
    backup_finish_date,
    CAST(backup_size / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS size_mb
FROM msdb.dbo.backupset
WHERE database_name = 'BD2S22026'
ORDER BY backup_start_date DESC;
```

---

## 4. Simulación de un desastre y restauración

### 4.1 Orden de restauración

```
FULL  →  DIFERENCIAL (el último)  →  LOG 1  →  LOG 2 (hasta el punto deseado)
```

- Todos los pasos intermedios usan `WITH NORECOVERY` (la base queda "en restauración").
- El último paso usa `WITH RECOVERY` para dejarla en línea.

### 4.2 (Opcional) Backup de la cola del log

Si la base todavía está accesible, conviene respaldar lo último que no se haya respaldado:

```sql
USE master;
GO

BACKUP LOG [BD2S22026]
TO DISK = N'C:\Backups\BD2S22026\LOG\BD2S22026_LOG_TAIL.trn'
WITH NORECOVERY, INIT;   -- deja la base en estado "Restoring"
GO
```

> Si usas este paso, la base ya queda en `RESTORING` y puedes continuar con el `RESTORE` sin tener que desconectar usuarios.

### 4.3 Restauración **completa** (hasta el último log)

```sql
USE master;
GO

-- (Solo si no hiciste la cola del log) Desconectar usuarios
-- ALTER DATABASE [BD2S22026] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

-- 1) Backup completo
RESTORE DATABASE [BD2S22026]
FROM DISK = N'C:\Backups\BD2S22026\FULL\BD2S22026_FULL.bak'
WITH NORECOVERY, REPLACE, STATS = 10;

-- 2) Backup diferencial
RESTORE DATABASE [BD2S22026]
FROM DISK = N'C:\Backups\BD2S22026\DIFF\BD2S22026_DIFF.bak'
WITH NORECOVERY, STATS = 10;

-- 3) Log 1
RESTORE LOG [BD2S22026]
FROM DISK = N'C:\Backups\BD2S22026\LOG\BD2S22026_LOG_1.trn'
WITH NORECOVERY, STATS = 10;

-- 4) Log 2 y se deja la base en línea
RESTORE LOG [BD2S22026]
FROM DISK = N'C:\Backups\BD2S22026\LOG\BD2S22026_LOG_2.trn'
WITH RECOVERY, STATS = 10;
GO

-- ALTER DATABASE [BD2S22026] SET MULTI_USER;
```

> En este caso las ventas **quedarían borradas**, porque el `DELETE` está dentro del log 2. Para recuperarlas usamos la restauración a un punto en el tiempo.

### 4.4 Restauración a un **punto en el tiempo** (`STOPAT`)

Restauramos hasta justo antes del `DELETE` accidental:

```sql
USE master;
GO

RESTORE DATABASE [BD2S22026]
FROM DISK = N'C:\Backups\BD2S22026\FULL\BD2S22026_FULL.bak'
WITH NORECOVERY, REPLACE;

RESTORE DATABASE [BD2S22026]
FROM DISK = N'C:\Backups\BD2S22026\DIFF\BD2S22026_DIFF.bak'
WITH NORECOVERY;

RESTORE LOG [BD2S22026]
FROM DISK = N'C:\Backups\BD2S22026\LOG\BD2S22026_LOG_1.trn'
WITH NORECOVERY;

RESTORE LOG [BD2S22026]
FROM DISK = N'C:\Backups\BD2S22026\LOG\BD2S22026_LOG_2.trn'
WITH STOPAT = '2026-10-27 10:15:00',   -- hora anotada antes del error
     RECOVERY;
GO
```

### 4.5 Verificar los datos restaurados

```sql
USE [BD2S22026];
GO

SELECT * FROM cliente;
SELECT * FROM productos;
SELECT * FROM venta;
SELECT * FROM detalle_venta;
```

### 4.6 Restaurar con otro nombre (sin pisar la base original)

Útil para recuperar datos puntuales o hacer pruebas:

```sql
-- Ver los nombres lógicos de los archivos dentro del backup
RESTORE FILELISTONLY
FROM DISK = N'C:\Backups\BD2S22026\FULL\BD2S22026_FULL.bak';

-- Restaurar como BD2S22026_COPIA
RESTORE DATABASE [BD2S22026_COPIA]
FROM DISK = N'C:\Backups\BD2S22026\FULL\BD2S22026_FULL.bak'
WITH
    MOVE N'BD2S22026'     TO N'C:\Data\BD2S22026_COPIA.mdf',
    MOVE N'BD2S22026_log' TO N'C:\Data\BD2S22026_COPIA_log.ldf',
    RECOVERY, STATS = 10;
```

> Ajusta los nombres lógicos (`BD2S22026`, `BD2S22026_log`) a lo que devuelva `RESTORE FILELISTONLY`.

---

## 5. Automatizar con SQL Server Agent (Jobs)

> SQL Server Agent **no está disponible en la edición Express**. Si usas Express, ve a la [sección 6](#6-automatizar-con-el-programador-de-tareas-de-windows).

### 5.1 Plan de respaldo propuesto

| Tipo | Frecuencia | Horario | Retención sugerida |
|---|---|---|---|
| FULL | Semanal | Domingo 01:00 | 4 semanas |
| DIFERENCIAL | Diario (lunes a sábado) | 01:00 | 1–2 semanas |
| LOG | Cada 15 minutos | Todo el día | 3–7 días |

### 5.2 Verificar que el Agent esté corriendo

En SSMS, en el Explorador de objetos, **SQL Server Agent** debe aparecer sin la flecha roja. Si está detenido: clic derecho → **Start**.

### 5.3 Crear un Job desde la interfaz gráfica (SSMS)

1. Expande **SQL Server Agent** → clic derecho en **Jobs** → **New Job...**
2. Pestaña **General**: Nombre = `Backup_FULL_BD2S22026`.
3. Pestaña **Steps** → **New...**
   - Step name: `Backup completo`
   - Type: `Transact-SQL script (T-SQL)`
   - Database: `master`
   - Command: el script de la sección 5.4.
4. Pestaña **Schedules** → **New...**
   - Name: `Semanal domingo 01:00`
   - Schedule type: `Recurring`
   - Frequency: `Weekly`, marcar **Sunday**
   - Occurs once at: `01:00:00`
5. (Opcional) Pestaña **Notifications**: configurar correo si usas Database Mail.
6. **OK**. Probar con clic derecho sobre el job → **Start Job at Step...**
7. Revisar el resultado en **View History**.

### 5.4 Crear los Jobs con T-SQL

Los nombres de archivo incluyen fecha y hora para **no sobrescribir** los backups anteriores.

#### Job 1 – Backup FULL semanal

```sql
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name    = N'Backup_FULL_BD2S22026',
    @description = N'Backup completo semanal de BD2S22026',
    @enabled     = 1;

EXEC dbo.sp_add_jobstep
    @job_name      = N'Backup_FULL_BD2S22026',
    @step_name     = N'Backup completo',
    @subsystem     = N'TSQL',
    @database_name = N'master',
    @command       = N'
DECLARE @archivo NVARCHAR(300);
SET @archivo = N''C:\Backups\BD2S22026\FULL\BD2S22026_FULL_''
             + FORMAT(GETDATE(), ''yyyyMMdd_HHmmss'') + N''.bak'';

BACKUP DATABASE [BD2S22026]
TO DISK = @archivo
WITH COMPRESSION, CHECKSUM, STATS = 10;';

EXEC dbo.sp_add_schedule
    @schedule_name         = N'Semanal_Domingo_0100',
    @freq_type             = 8,          -- semanal
    @freq_interval         = 1,          -- 1 = domingo
    @freq_recurrence_factor = 1,         -- cada 1 semana
    @active_start_time     = 010000;     -- 01:00:00

EXEC dbo.sp_attach_schedule
    @job_name      = N'Backup_FULL_BD2S22026',
    @schedule_name = N'Semanal_Domingo_0100';

EXEC dbo.sp_add_jobserver
    @job_name = N'Backup_FULL_BD2S22026';
GO
```

#### Job 2 – Backup DIFERENCIAL diario

```sql
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name    = N'Backup_DIFF_BD2S22026',
    @description = N'Backup diferencial diario de BD2S22026',
    @enabled     = 1;

EXEC dbo.sp_add_jobstep
    @job_name      = N'Backup_DIFF_BD2S22026',
    @step_name     = N'Backup diferencial',
    @subsystem     = N'TSQL',
    @database_name = N'master',
    @command       = N'
DECLARE @archivo NVARCHAR(300);
SET @archivo = N''C:\Backups\BD2S22026\DIFF\BD2S22026_DIFF_''
             + FORMAT(GETDATE(), ''yyyyMMdd_HHmmss'') + N''.bak'';

BACKUP DATABASE [BD2S22026]
TO DISK = @archivo
WITH DIFFERENTIAL, COMPRESSION, CHECKSUM, STATS = 10;';

EXEC dbo.sp_add_schedule
    @schedule_name         = N'Diario_Lun_Sab_0100',
    @freq_type             = 8,          -- semanal
    @freq_interval         = 126,        -- lunes(2)+martes(4)+miérc(8)+jueves(16)+viernes(32)+sábado(64)
    @freq_recurrence_factor = 1,
    @active_start_time     = 010000;

EXEC dbo.sp_attach_schedule
    @job_name      = N'Backup_DIFF_BD2S22026',
    @schedule_name = N'Diario_Lun_Sab_0100';

EXEC dbo.sp_add_jobserver
    @job_name = N'Backup_DIFF_BD2S22026';
GO
```

#### Job 3 – Backup de LOG cada 15 minutos

```sql
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name    = N'Backup_LOG_BD2S22026',
    @description = N'Backup del log de transacciones cada 15 minutos',
    @enabled     = 1;

EXEC dbo.sp_add_jobstep
    @job_name      = N'Backup_LOG_BD2S22026',
    @step_name     = N'Backup de log',
    @subsystem     = N'TSQL',
    @database_name = N'master',
    @command       = N'
DECLARE @archivo NVARCHAR(300);
SET @archivo = N''C:\Backups\BD2S22026\LOG\BD2S22026_LOG_''
             + FORMAT(GETDATE(), ''yyyyMMdd_HHmmss'') + N''.trn'';

BACKUP LOG [BD2S22026]
TO DISK = @archivo
WITH COMPRESSION, CHECKSUM;';

EXEC dbo.sp_add_schedule
    @schedule_name         = N'Cada_15_min',
    @freq_type             = 4,          -- diario
    @freq_interval         = 1,          -- cada 1 día
    @freq_subday_type      = 4,          -- minutos
    @freq_subday_interval  = 15,         -- cada 15 minutos
    @active_start_time     = 000000;

EXEC dbo.sp_attach_schedule
    @job_name      = N'Backup_LOG_BD2S22026',
    @schedule_name = N'Cada_15_min';

EXEC dbo.sp_add_jobserver
    @job_name = N'Backup_LOG_BD2S22026';
GO
```

### 5.5 Probar y monitorear los Jobs

```sql
-- Ejecutar un job manualmente
EXEC msdb.dbo.sp_start_job @job_name = N'Backup_FULL_BD2S22026';

-- Ver el historial de ejecuciones
SELECT
    j.name AS job,
    h.run_date,
    h.run_time,
    CASE h.run_status WHEN 1 THEN 'Exitoso' WHEN 0 THEN 'Fallido' ELSE 'Otro' END AS estado,
    h.message
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
WHERE h.step_id = 0
ORDER BY h.run_date DESC, h.run_time DESC;
```

### 5.6 Limpieza de backups antiguos

Agrega un **segundo paso** al job FULL (tipo *Operating system (CmdExec)*) que borre archivos de más de 30 días:

```bat
forfiles /p "C:\Backups\BD2S22026" /s /m *.bak /d -30 /c "cmd /c del @path"
forfiles /p "C:\Backups\BD2S22026" /s /m *.trn /d -30 /c "cmd /c del @path"
```

---

## 6. Automatizar con el Programador de tareas de Windows

Ideal para **SQL Server Express** (sin Agent) o cuando prefieres no usar jobs. Se usa la herramienta `sqlcmd` para ejecutar scripts T-SQL.

### 6.1 Verificar que `sqlcmd` esté disponible

```bat
sqlcmd -?
```

Si no se reconoce el comando, instala las *Command Line Utilities for SQL Server* o usa la ruta completa, por ejemplo:
`"C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"`

### 6.2 Crear la carpeta de scripts

```bat
mkdir C:\Backups\Scripts
```

### 6.3 Scripts `.sql`

**`C:\Backups\Scripts\backup_full.sql`**

```sql
DECLARE @archivo NVARCHAR(300);
SET @archivo = N'C:\Backups\BD2S22026\FULL\BD2S22026_FULL_'
             + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + N'.bak';

BACKUP DATABASE [BD2S22026]
TO DISK = @archivo
WITH CHECKSUM, STATS = 10;   -- agrega COMPRESSION si tu edición lo soporta
```

**`C:\Backups\Scripts\backup_diff.sql`**

```sql
DECLARE @archivo NVARCHAR(300);
SET @archivo = N'C:\Backups\BD2S22026\DIFF\BD2S22026_DIFF_'
             + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + N'.bak';

BACKUP DATABASE [BD2S22026]
TO DISK = @archivo
WITH DIFFERENTIAL, CHECKSUM, STATS = 10;
```

**`C:\Backups\Scripts\backup_log.sql`**

```sql
DECLARE @archivo NVARCHAR(300);
SET @archivo = N'C:\Backups\BD2S22026\LOG\BD2S22026_LOG_'
             + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + N'.trn';

BACKUP LOG [BD2S22026]
TO DISK = @archivo
WITH CHECKSUM;
```

### 6.4 Scripts `.bat` que llaman a `sqlcmd`

**`C:\Backups\Scripts\backup_full.bat`**

```bat
@echo off
sqlcmd -S .\SQLEXPRESS -E -b -i "C:\Backups\Scripts\backup_full.sql" >> "C:\Backups\Scripts\backup_full.log" 2>&1
```

**`C:\Backups\Scripts\backup_diff.bat`**

```bat
@echo off
sqlcmd -S .\SQLEXPRESS -E -b -i "C:\Backups\Scripts\backup_diff.sql" >> "C:\Backups\Scripts\backup_diff.log" 2>&1
```

**`C:\Backups\Scripts\backup_log.bat`**

```bat
@echo off
sqlcmd -S .\SQLEXPRESS -E -b -i "C:\Backups\Scripts\backup_log.sql" >> "C:\Backups\Scripts\backup_log.log" 2>&1
```

Parámetros de `sqlcmd`:

| Parámetro | Significado |
|---|---|
| `-S` | Servidor/instancia (`.` o `.\SQLEXPRESS` o `NOMBRE-PC\INSTANCIA`) |
| `-E` | Autenticación de Windows |
| `-b` | Devuelve código de error si el script falla |
| `-i` | Archivo de entrada `.sql` |

> Si usas autenticación SQL en lugar de Windows: `-U usuario -P contraseña` (evita dejar contraseñas en texto plano cuando sea posible).

### 6.5 Crear las tareas desde la interfaz gráfica

1. Abre **Programador de tareas** (`taskschd.msc`).
2. Clic en **Crear tarea...** (no "tarea básica", para tener más opciones).
3. Pestaña **General**:
   - Nombre: `SQL_Backup_FULL_BD2S22026`
   - Marcar **Ejecutar tanto si el usuario inició sesión como si no**.
   - Marcar **Ejecutar con los privilegios más altos**.
   - Usar una cuenta con permisos para respaldar (por ejemplo `SYSTEM` o una cuenta de servicio con rol `db_backupoperator`).
4. Pestaña **Desencadenadores** → **Nuevo...**
   - Iniciar la tarea: `Según una programación`
   - Semanalmente, domingo, 01:00.
5. Pestaña **Acciones** → **Nuevo...**
   - Acción: `Iniciar un programa`
   - Programa o script: `C:\Backups\Scripts\backup_full.bat`
6. Pestaña **Configuración**:
   - Marcar **Permitir que la tarea se ejecute a petición**.
   - Marcar **Si la tarea no se ejecutó, iniciarla lo antes posible**.
7. **Aceptar**. Clic derecho sobre la tarea → **Ejecutar** para probarla.
8. Verificar que se creó el archivo `.bak` y revisar `backup_full.log`.

Repite el proceso para el diferencial (diario) y el log (ver 6.6).

### 6.6 Crear las tareas desde la línea de comandos (`schtasks`)

Ejecuta CMD **como administrador**:

```bat
:: FULL: domingos a la 01:00
schtasks /create /tn "SQL_Backup_FULL_BD2S22026" ^
  /tr "C:\Backups\Scripts\backup_full.bat" ^
  /sc weekly /d SUN /st 01:00 /ru SYSTEM /rl HIGHEST

:: DIFERENCIAL: lunes a sábado a la 01:00
schtasks /create /tn "SQL_Backup_DIFF_BD2S22026" ^
  /tr "C:\Backups\Scripts\backup_diff.bat" ^
  /sc weekly /d MON,TUE,WED,THU,FRI,SAT /st 01:00 /ru SYSTEM /rl HIGHEST

:: LOG: cada 15 minutos
schtasks /create /tn "SQL_Backup_LOG_BD2S22026" ^
  /tr "C:\Backups\Scripts\backup_log.bat" ^
  /sc minute /mo 15 /ru SYSTEM /rl HIGHEST
```

Comandos útiles:

```bat
:: Ejecutar una tarea manualmente
schtasks /run /tn "SQL_Backup_FULL_BD2S22026"

:: Ver el estado de las tareas
schtasks /query /tn "SQL_Backup_FULL_BD2S22026" /v /fo list

:: Eliminar una tarea
schtasks /delete /tn "SQL_Backup_FULL_BD2S22026" /f
```

> Si usas `SYSTEM`, asegúrate de que ese usuario tenga login en SQL Server (`NT AUTHORITY\SYSTEM`) con permiso de backup. Si no, usa una cuenta de dominio/local con ese permiso.

### 6.7 Limpieza automática de backups antiguos

**`C:\Backups\Scripts\limpiar_backups.bat`**

```bat
@echo off
:: Borra archivos .bak y .trn con más de 30 días
forfiles /p "C:\Backups\BD2S22026" /s /m *.bak /d -30 /c "cmd /c del @path"
forfiles /p "C:\Backups\BD2S22026" /s /m *.trn /d -30 /c "cmd /c del @path"
```

```bat
schtasks /create /tn "SQL_Limpieza_Backups" ^
  /tr "C:\Backups\Scripts\limpiar_backups.bat" ^
  /sc daily /st 03:00 /ru SYSTEM /rl HIGHEST
```

---

## 7. Buenas prácticas

- **Regla 3-2-1:** 3 copias de los datos, en 2 tipos de medios distintos, 1 copia fuera del servidor (nube, otra sede).
- **No guardes los backups en el mismo disco** que los archivos `.mdf`/`.ldf`.
- **Prueba las restauraciones periódicamente**: un backup que nunca se ha restaurado no es un backup confiable.
- Usa `CHECKSUM` y `RESTORE VERIFYONLY` para detectar corrupción.
- Si tu base está en modelo `FULL` y **no** haces backups de log, el archivo `.ldf` crecerá sin control.
- Mantén una **cadena de respaldos sin saltos**: no borres un FULL del cual dependan diferenciales o logs vigentes.
- Para bases en modelo `SIMPLE` solo funcionan FULL y DIFERENCIAL (no hay backup de log).
- Respalda también las bases del sistema `master` y `msdb` (donde viven logins y jobs).
- Monitorea los jobs/tareas y configura alertas por correo en caso de fallo.

---

### Resumen rápido de comandos

| Acción | Comando |
|---|---|
| Backup completo | `BACKUP DATABASE [BD] TO DISK = '...'` |
| Backup diferencial | `BACKUP DATABASE [BD] TO DISK = '...' WITH DIFFERENTIAL` |
| Backup de log | `BACKUP LOG [BD] TO DISK = '...'` |
| Restaurar FULL (esperando más) | `RESTORE DATABASE [BD] FROM DISK = '...' WITH NORECOVERY` |
| Restaurar DIFF (esperando más) | `RESTORE DATABASE [BD] FROM DISK = '...' WITH NORECOVERY` |
| Restaurar LOG (último) | `RESTORE LOG [BD] FROM DISK = '...' WITH RECOVERY` |
| Punto en el tiempo | `RESTORE LOG ... WITH STOPAT = 'AAAA-MM-DD hh:mm:ss', RECOVERY` |
| Verificar backup | `RESTORE VERIFYONLY FROM DISK = '...'` |
