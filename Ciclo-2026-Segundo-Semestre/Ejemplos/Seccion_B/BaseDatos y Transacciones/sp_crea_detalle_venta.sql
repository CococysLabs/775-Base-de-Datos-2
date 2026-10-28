use [BD2S22026]
go 
-- drop procedure sp_crea_detalle_venta 
CREATE PROCEDURE sp_crea_detalle_venta
    @in_id_venta int ,
    @in_id_producto int ,
    @in_cant_producto int
AS
BEGIN 
  -- creacion de detalle
   insert into detalle_venta(id_venta,id_producto,cantidad,sub_total)
   VALUES(
    @in_id_venta,@in_id_producto,@in_cant_producto,0
   )
END 