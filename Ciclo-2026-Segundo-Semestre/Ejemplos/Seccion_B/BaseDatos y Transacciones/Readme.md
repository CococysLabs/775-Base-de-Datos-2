
# Bases de datos 2 
## Ejemplo de transacciones 

1. Crear tablas 

```cmd 
tablas.sql
```
2. Crear procedimientos almacenados
```cmd 
sp_crea_detalle_venta.sql
sp_crea_venta.sql
```
3. Crear Procedimiento con manejo de transacciones 
```cmd 
venta_con_manejo_errores.sql
```


# Explicaciòn

Se puede iniciar creando las tablas sin identity y colocando delays en los sp para ejemplificar conflictos de lecturas.

Luego puedes agregar transacciones

Por ultimo se puede completar agregando identity a las tablas.

