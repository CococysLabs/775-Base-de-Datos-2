
-- nombre de variables 
use [BD2S22026]
go
-- clientes
create table cliente(
   id_cliente int primary key,
   nombre varchar(50) not null unique
)

-- productos
create table productos (
 id_producto int primary key,
 nombre varchar(100) not null unique  
)

-- venta
-- drop table BD2S22026.dbo.venta
create table BD2S22026.dbo.venta(
 id_venta int primary key IDENTITY,
 id_cliente int not null,
 fecha datetime not null
)

-- detalle venta
-- drop table BD2S22026.dbo.detalle_venta
create table BD2S22026.dbo.detalle_venta(
 id_detalle_venta int primary key IDENTITY,
 id_venta int not null,
 id_producto int not null,
 cantidad int not null, 
 sub_total decimal not null,
)

alter table BD2S22026.dbo.detalle_venta
add constraint fk_venta_detalle_venta FOREIGN KEY (id_venta) REFERENCES venta(id_venta)

alter table BD2S22026.dbo.detalle_venta
add constraint fk_venta_detalle_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
