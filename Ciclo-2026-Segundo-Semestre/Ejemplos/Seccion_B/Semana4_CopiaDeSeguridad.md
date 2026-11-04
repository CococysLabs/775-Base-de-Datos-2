# Backups y Restauración en SQL Server – Base de datos `BD2S22026`

Guía práctica con un esquema sencillo de ventas: backup **completo**, **diferencial** (lo que comúnmente se llama "incremental" en SQL Server) y de **log de transacciones**. Al final se automatiza con **SQL Server Agent (Jobs)** y con el **Programador de tareas de Windows**.

> **Nota sobre "incremental":** SQL Server no tiene un backup incremental como tal. Lo más parecido es el backup **diferencial**, que guarda todos los cambios desde el *último backup completo*. Los backups de **log de transacciones** son los que guardan los cambios *incrementales* entre un punto y otro.

---

## Índice

1. [Esquema de ejemplo y datos de prueba](#1-esquema-de-ejemplo-y-datos-de-prueba)
2. [Preparación: modelo de recuperación y carpetas](#2-preparación-modelo-de-recuperación-y-carpetas)
3. [Comandos de backup](#3-comandos-de-backup)

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

