# Implementación de un cubo en SQL Server Analysis Services (SSAS) – Edición Developer

**Fuente de datos:** `AdventureWorksDW` (Data Warehouse)
**Modo de SSAS:** Multidimensional
**Herramientas:** SQL Server Developer, SSMS, Visual Studio con SSDT (Analysis Services Projects)

---

## 1. Requisitos previos

| Componente | Detalle |
|---|---|
| SQL Server Developer Edition | Motor de base de datos (Database Engine) instalado |
| SQL Server Analysis Services | Instalado en modo **Multidimensional and Data Mining** |
| SQL Server Management Studio (SSMS) | Para restaurar la BD, consultar y administrar SSAS |
| Visual Studio 2019/2022 | Con la extensión **Microsoft Analysis Services Projects** |
| Base de datos `AdventureWorksDW` | Archivo `.bak` (por ejemplo `AdventureWorksDW2019.bak` o `AdventureWorksDW2022.bak`) |

> **Nota:** El modo del servidor SSAS (Multidimensional o Tabular) se define durante la instalación y no se puede cambiar después. Para este tutorial se necesita **Multidimensional**.

---

## 2. Instalar SSAS en modo Multidimensional (si aún no está instalado)

1. Ejecutar el instalador de SQL Server → **Installation** → **New SQL Server stand-alone installation or add features to an existing installation**.
2. Seleccionar la instancia existente y marcar **Analysis Services** en *Feature Selection*.
3. En *Analysis Services Configuration*:
   - **Server Mode:** `Multidimensional and Data Mining Mode`.
   - **Specify which users have administrative permissions:** agregar el usuario actual (*Add Current User*).
4. Finalizar la instalación.
5. Verificar en **Servicios de Windows** que el servicio `SQL Server Analysis Services (MSSQLSERVER)` esté en ejecución.

---

## 3. Restaurar la base de datos AdventureWorksDW

1. Copiar el archivo `.bak` a una ruta accesible, por ejemplo `C:\Backups\`.
2. Abrir **SSMS** y conectarse al **Database Engine**.
3. Clic derecho en **Databases** → **Restore Database...** → **Device** → seleccionar el `.bak`.
4. Verificar el nombre de destino (`AdventureWorksDW2019`, etc.) y presionar **OK**.

O mediante T-SQL:

```sql
RESTORE DATABASE AdventureWorksDW2019
FROM DISK = N'C:\Backups\AdventureWorksDW2019.bak'
WITH MOVE 'AdventureWorksDW2017' TO N'C:\Data\AdventureWorksDW2019.mdf',
     MOVE 'AdventureWorksDW2017_log' TO N'C:\Data\AdventureWorksDW2019_log.ldf',
     REPLACE, STATS = 10;
```

> Los nombres lógicos (`MOVE '...'`) pueden variar según la versión del backup. Consultarlos con `RESTORE FILELISTONLY FROM DISK = '...'`.

5. Validar los datos:

```sql
USE AdventureWorksDW2019;
SELECT COUNT(*) AS Filas FROM dbo.FactInternetSales;   -- ~60,398
SELECT COUNT(*) AS Filas FROM dbo.DimCustomer;         -- ~18,484
```

---

## 4. Dar permisos a la cuenta de servicio de SSAS

SSAS lee el DW usando (por defecto) la **cuenta de servicio** de Analysis Services. Esa cuenta necesita acceso de lectura.

1. En SSMS (Database Engine) → **Security** → **Logins** → buscar la cuenta `NT Service\MSSQLServerOLAPService`.
2. Si no existe, crearla: **New Login...** → Windows authentication → `NT Service\MSSQLServerOLAPService`.
3. En **User Mapping**, marcar `AdventureWorksDW2019` y asignar el rol `db_datareader`.

Equivalente en T-SQL:

```sql
USE master;
CREATE LOGIN [NT Service\MSSQLServerOLAPService] FROM WINDOWS;
GO
USE AdventureWorksDW2019;
CREATE USER [NT Service\MSSQLServerOLAPService] FOR LOGIN [NT Service\MSSQLServerOLAPService];
ALTER ROLE db_datareader ADD MEMBER [NT Service\MSSQLServerOLAPService];
```

> Si la instancia de SSAS es nombrada, la cuenta será `NT Service\MSOLAP$NOMBREINSTANCIA`.

---

## 5. Crear el proyecto de Analysis Services

1. Abrir **Visual Studio** → **Create a new project**.
2. Elegir la plantilla **Analysis Services Multidimensional Project** (en versiones antiguas: *Analysis Services Multidimensional and Data Mining Project*).
3. Nombre sugerido: `CuboAdventureWorks`. Crear el proyecto.
4. En el **Solution Explorer** se verán las carpetas: *Data Sources*, *Data Source Views*, *Cubes*, *Dimensions*, *Mining Structures*, *Roles*, *Assemblies*, *Miscellaneous*.

---

## 6. Crear el Data Source (origen de datos)

1. Clic derecho en **Data Sources** → **New Data Source...** → **Next**.
2. **New...** para crear la conexión:
   - **Provider:** `Microsoft OLE DB Driver for SQL Server` (o `SQL Server Native Client 11.0`).
   - **Server name:** `localhost` (o `.\NOMBREINSTANCIA`).
   - **Authentication:** Windows Authentication.
   - **Database:** `AdventureWorksDW2019`.
   - **Test Connection** → debe responder correctamente.
3. En **Impersonation Information** seleccionar **Use the service account**.
4. Nombre: `AdventureWorksDW` → **Finish**.

---

## 7. Crear el Data Source View (DSV)

1. Clic derecho en **Data Source Views** → **New Data Source View...**.
2. Seleccionar el Data Source `AdventureWorksDW`.
3. Seleccionar las tablas del modelo de **Ventas por Internet** (mover a *Included objects*):

| Tipo | Tablas |
|---|---|
| Hechos | `FactInternetSales` |
| Dimensión Fecha | `DimDate` |
| Dimensión Cliente | `DimCustomer`, `DimGeography` |
| Dimensión Producto | `DimProduct`, `DimProductSubcategory`, `DimProductCategory` |
| Dimensión Territorio | `DimSalesTerritory` |
| Dimensión Promoción | `DimPromotion` |
| Dimensión Moneda | `DimCurrency` |

4. Nombre: `AdventureWorksDW DSV` → **Finish**.
5. En el diagrama, **verificar las relaciones** (flechas) entre la tabla de hechos y las dimensiones:

| FactInternetSales | → | Dimensión |
|---|---|---|
| `ProductKey` | → | `DimProduct.ProductKey` |
| `OrderDateKey` | → | `DimDate.DateKey` |
| `DueDateKey` | → | `DimDate.DateKey` |
| `ShipDateKey` | → | `DimDate.DateKey` |
| `CustomerKey` | → | `DimCustomer.CustomerKey` |
| `PromotionKey` | → | `DimPromotion.PromotionKey` |
| `CurrencyKey` | → | `DimCurrency.CurrencyKey` |
| `SalesTerritoryKey` | → | `DimSalesTerritory.SalesTerritoryKey` |

Relaciones adicionales (esquema copo de nieve):
- `DimProduct.ProductSubcategoryKey` → `DimProductSubcategory.ProductSubcategoryKey`
- `DimProductSubcategory.ProductCategoryKey` → `DimProductCategory.ProductCategoryKey`
- `DimCustomer.GeographyKey` → `DimGeography.GeographyKey`

> Si alguna relación falta, arrastrar la columna origen sobre la columna destino para crearla.

6. *(Opcional)* Crear **Named Calculations** (clic derecho en la tabla → *New Named Calculation*), por ejemplo en `DimCustomer`:
   - Nombre: `NombreCompleto`
   - Expresión: `FirstName + ' ' + LastName`

---

## 8. Crear las dimensiones

Se recomienda crear primero las dimensiones con el asistente y luego el cubo.

1. Clic derecho en **Dimensions** → **New Dimension...** → *Use an existing table*.
2. Crear una por una:

| Dimensión | Tabla principal | Clave | Columna de nombre | Atributos sugeridos |
|---|---|---|---|---|
| `Dim Date` | `DimDate` | `DateKey` | `FullDateAlternateKey` | Calendar Year, Calendar Semester, Calendar Quarter, Month Name, Day |
| `Dim Customer` | `DimCustomer` | `CustomerKey` | `NombreCompleto` | Gender, Marital Status, Education, Occupation, Country, State, City |
| `Dim Product` | `DimProduct` | `ProductKey` | `EnglishProductName` | Color, Size, Class, Style, Subcategory, Category |
| `Dim Sales Territory` | `DimSalesTerritory` | `SalesTerritoryKey` | `SalesTerritoryRegion` | Country, Group |
| `Dim Promotion` | `DimPromotion` | `PromotionKey` | `EnglishPromotionName` | Type, Category |
| `Dim Currency` | `DimCurrency` | `CurrencyKey` | `CurrencyName` | – |

3. Para `Dim Customer` y `Dim Product`, en el asistente marcar las **tablas relacionadas** (`DimGeography`, `DimProductSubcategory`, `DimProductCategory`) para incluir sus atributos.

### 8.1 Configurar `Dim Date`

1. Abrir la dimensión y, en el panel **Attributes**, ajustar:

| Atributo | Propiedad | Valor |
|---|---|---|
| `Date Key` | `Type` | `Date` |
| `Calendar Year` | `Type` | `Years → Calendar` |
| `Calendar Semester` | `Type` | `Half Years → Calendar` |
| `Calendar Quarter` | `Type` | `Quarters → Calendar` |
| `Month Number Of Year` | `Type` | `Months → Calendar` |

2. Para mostrar nombres amigables (por ejemplo, el mes): en el atributo **Month**, propiedad `NameColumn` → `EnglishMonthName` (o `SpanishMonthName`) y `OrderBy` → `Key` para que se ordene cronológicamente.
3. Crear la **jerarquía** `Calendario`: arrastrar los atributos al panel **Hierarchies** en este orden:
   - `Calendar Year` → `Calendar Semester` → `Calendar Quarter` → `Month` → `Date`
4. En la pestaña **Attribute Relationships**, definir las relaciones en cascada (Date → Month → Quarter → Semester → Year) para mejorar el rendimiento y eliminar la advertencia de diseño.

### 8.2 Configurar `Dim Product`

1. Crear la jerarquía `Categoría de Producto`:
   - `Product Category` → `Product Subcategory` → `Product`
2. En **Attribute Relationships**: `Product → Subcategory → Category`.

### 8.3 Configurar `Dim Customer`

1. Crear la jerarquía `Geografía`:
   - `Country Region` → `State Province` → `City` → `Customer`
2. Definir las relaciones de atributos correspondientes.

> **Buenas prácticas:** definir siempre `Attribute Relationships` y poner `AttributeHierarchyVisible = False` en atributos que solo se usen dentro de jerarquías.

---

## 9. Crear el cubo

1. Clic derecho en **Cubes** → **New Cube...** → **Next**.
2. **Select Creation Method:** `Use existing tables`.
3. **Select Measure Group Tables:** marcar `FactInternetSales`.
4. **Select Measures:** dejar las siguientes (desmarcar las claves y campos sin valor analítico):

| Medida | Agregación |
|---|---|
| `Order Quantity` | Sum |
| `Unit Price` | Sum *(opcional; no suele ser aditiva)* |
| `Extended Amount` | Sum |
| `Discount Amount` | Sum |
| `Product Standard Cost` | Sum |
| `Total Product Cost` | Sum |
| `Sales Amount` | Sum |
| `Tax Amt` | Sum |
| `Freight` | Sum |
| `Fact Internet Sales Count` | Count (medida generada) |

5. **Select Existing Dimensions:** seleccionar todas las dimensiones creadas en el paso 8.
6. **Name:** `Adventure Works Internet Sales` → **Finish**.

---

## 10. Configurar el uso de dimensiones (Dimension Usage)

1. Abrir el cubo → pestaña **Dimension Usage**.
2. La dimensión de fecha aparecerá como **role-playing dimension** (múltiples relaciones a `FactInternetSales`). Renombrar cada una:
   - `Order Date` → `OrderDateKey`
   - `Due Date` → `DueDateKey`
   - `Ship Date` → `ShipDateKey`
3. Verificar que cada dimensión tenga la relación **Regular** con el grupo de medidas apuntando a la clave correcta.

---

## 11. Formato de medidas y cálculos (opcional)

### 11.1 Formato

En la pestaña **Cube Structure** → seleccionar cada medida y, en *Properties*, configurar `FormatString`:
- Importes (`Sales Amount`, `Total Product Cost`, etc.): `Currency`
- Cantidades: `#,#`

### 11.2 Miembro calculado

Pestaña **Calculations** → **New Calculated Member**:

- **Name:** `[Margen]`
- **Expression:**

```mdx
[Measures].[Sales Amount] - [Measures].[Total Product Cost]
```

- **Format string:** `"Currency"`

Segundo ejemplo, `[Margen %]`:

```mdx
IIF([Measures].[Sales Amount] = 0, NULL,
    ([Measures].[Sales Amount] - [Measures].[Total Product Cost]) / [Measures].[Sales Amount])
```

Format string: `"Percent"`.

### 11.3 KPI (opcional)

Pestaña **KPIs** → *New KPI* con valor `[Measures].[Margen %]`, meta (por ejemplo `0.4`) e indicador gráfico.

---

## 12. Configurar la implementación (Deployment)

1. Clic derecho en el proyecto → **Properties** → **Deployment**.
2. Configurar:
   - **Server:** `localhost` (o `localhost\NOMBREINSTANCIA`).
   - **Database:** `AdventureWorksCubo`.
   - **Processing Option:** `Default`.
   - **Transactional Deployment:** `False`.
3. Aceptar.

---

## 13. Implementar y procesar el cubo

1. Clic derecho en el proyecto → **Deploy** (o `F5`).
2. Visual Studio construirá el proyecto y lo publicará en SSAS.
3. Si se pide el procesamiento, aceptar y en la ventana **Process Cube** presionar **Run**.
4. Debe aparecer el estado **Process Succeeded** en cada objeto (dimensiones, grupos de medida, particiones).
5. Cerrar la ventana de procesamiento.

---

## 14. Explorar y validar el cubo

### 14.1 Desde Visual Studio

1. Abrir el cubo → pestaña **Browser**.
2. Arrastrar `Sales Amount` al área de datos.
3. Arrastrar la jerarquía `Calendario` (de *Order Date*) a las filas y `Product Category` a las columnas.
4. Comparar totales contra el DW para validar:

```sql
SELECT SUM(SalesAmount) AS TotalVentas FROM dbo.FactInternetSales;
```

### 14.2 Desde SSMS

1. En SSMS → **Connect** → **Analysis Services** → servidor `localhost`.
2. Expandir **Databases** → `AdventureWorksCubo` → **Cubes**.
3. Clic derecho en el cubo → **Browse** o **New Query → MDX**.

Consulta MDX de ejemplo:

```mdx
SELECT
    { [Measures].[Sales Amount], [Measures].[Order Quantity] } ON COLUMNS,
    NON EMPTY [Dim Product].[Product Category].[Product Category].MEMBERS ON ROWS
FROM [Adventure Works Internet Sales]
WHERE ( [Order Date].[Calendar Year].&[2013] );
```

### 14.3 Desde Excel (opcional)

1. **Datos** → **Obtener datos** → **De base de datos** → **De Analysis Services**.
2. Servidor: `localhost` → seleccionar `AdventureWorksCubo` → cubo.
3. Crear una **tabla dinámica** con las medidas y jerarquías.

---

## 15. Problemas frecuentes

| Error / Síntoma | Causa probable | Solución |
|---|---|---|
| `Login failed for user 'NT Service\MSSQLServerOLAPService'` al procesar | La cuenta de servicio de SSAS no tiene acceso al DW | Repetir el paso 4 (login + `db_datareader`) |
| `The project cannot be deployed... server not found` | Nombre de servidor incorrecto en *Deployment* | Revisar `Server` (usar `localhost\INSTANCIA` si es nombrada) |
| No aparece la plantilla *Analysis Services Multidimensional Project* | Falta la extensión SSDT para SSAS | Instalar *Microsoft Analysis Services Projects* desde el Marketplace de Visual Studio |
| `Attribute key cannot be found when processing` | Claves de hechos sin su correspondiente miembro en la dimensión | Verificar integridad referencial en el DW; en el proceso configurar *Key not found = Report and continue* (solo para pruebas) |
| `Duplicate attribute key has been found` | Un atributo tiene `KeyColumn` no único (por ejemplo, el nombre del mes sin el año) | Usar clave compuesta (Año + Mes) o la clave numérica como `KeyColumn` y el nombre como `NameColumn` |
| Se instaló SSAS en modo Tabular | El modo se elige durante la instalación | Instalar una nueva instancia de SSAS en modo Multidimensional |
| Advertencias azules en el diseño de dimensiones | Falta de *Attribute Relationships* | Definirlas en la pestaña correspondiente (paso 8) |

---

## 16. Resumen del flujo

```
Instalar SSAS (Multidimensional)
        ↓
Restaurar AdventureWorksDW
        ↓
Permisos para la cuenta de servicio de SSAS
        ↓
Proyecto SSAS en Visual Studio
        ↓
Data Source → Data Source View
        ↓
Dimensiones (jerarquías + relaciones de atributos)
        ↓
Cubo (medidas + Dimension Usage + cálculos)
        ↓
Deploy + Process
        ↓
Validar (Browser / MDX / Excel)
```
