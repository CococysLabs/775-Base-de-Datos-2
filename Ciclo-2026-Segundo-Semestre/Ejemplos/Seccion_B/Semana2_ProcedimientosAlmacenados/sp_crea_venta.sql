use [BD2S22026]
go 
-- drop procedure sp_crea_venta 
CREATE PROCEDURE sp_crea_venta
    @in_id_cliente int,
    @out_id_venta int out
as 
BEGIN

    --obtener el siguiente id
    --select @out_id_venta = isnull(max(id_venta),1)+1 from venta 

    -- simular congestion de base de datos 
    --WAITFOR delay '00:00:5'

    --crear nueva venta
    insert into venta ( id_cliente, fecha) values (
        @in_id_cliente, getdate()
    )
    --WAITFOR delay '00:00:10'
    set @out_id_venta = SCOPE_IDENTITY()

END