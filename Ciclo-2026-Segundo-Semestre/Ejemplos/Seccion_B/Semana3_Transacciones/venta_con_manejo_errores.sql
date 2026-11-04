use BD2S22026


BEGIN TRANSACTION 

begin try 
    -- crear venta
    declare @venta int 
    exec BD2S22026.dbo.sp_crea_venta 1, @venta out

    -- crear detalle
    exec BD2S22026.dbo.sp_crea_detalle_venta @venta, 11, 3

    COMMIT TRANSACTION
end try
begin catch 

    print 'ocurrio un error al crear venta'
    ROLLBACK TRANSACTION

end catch 
