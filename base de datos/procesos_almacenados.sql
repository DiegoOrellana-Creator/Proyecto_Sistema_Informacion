-- ============================================================
-- PROCEDIMIENTOS Y FUNCIONES - ELECTRÓNICA CENTRAL AZ
-- Esquema: electronica_az
-- ============================================================

SET search_path = electronica_az, public;

-- ============================================================
-- 1. REGISTRAR BITÁCORA
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_registrar_bitacora(
    p_accion varchar,
    p_objeto_afectado text,
    p_resultado text,
    p_id_usuario uuid,
    p_direccion_ip inet DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO electronica_az.registro_bitacora (
        accion,
        objeto_afectado,
        resultado,
        direccion_ip,
        id_usuario
    )
    VALUES (
        p_accion,
        p_objeto_afectado,
        p_resultado,
        p_direccion_ip,
        p_id_usuario
    );
END;
$$;


-- ============================================================
-- 2. RECIBIR COMPRA (Actualiza stock, costo promedio y kardex)
-- ============================================================
CREATE OR REPLACE PROCEDURE electronica_az.sp_recibir_compra(
    p_id_compra uuid,
    p_id_usuario uuid,
    p_direccion_ip inet DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado varchar(120);
    v_detalle RECORD;
    v_stock_anterior numeric(18,4);
    v_costo_anterior numeric(18,4);
    v_nuevo_stock numeric(18,4);
    v_nuevo_costo numeric(18,4);
BEGIN
    -- Bloquear compra
    SELECT estado
    INTO v_estado
    FROM electronica_az.compra
    WHERE id_compra = p_id_compra
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La compra % no existe', p_id_compra;
    END IF;

    IF v_estado <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Solo se pueden recibir compras en estado PENDIENTE. Estado actual: %', v_estado;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM electronica_az.detalle_compra
        WHERE id_compra = p_id_compra
    ) THEN
        RAISE EXCEPTION 'La compra no tiene detalles asociados';
    END IF;

    FOR v_detalle IN
        SELECT
            id_detalle_compra,
            id_producto,
            cantidad,
            costo_unitario
        FROM electronica_az.detalle_compra
        WHERE id_compra = p_id_compra
    LOOP
        -- Bloquear existencia
        SELECT
            stock_actual,
            costo_promedio
        INTO
            v_stock_anterior,
            v_costo_anterior
        FROM electronica_az.existencia
        WHERE id_producto = v_detalle.id_producto
        FOR UPDATE;

        IF NOT FOUND THEN
            INSERT INTO electronica_az.existencia (
                id_producto,
                stock_actual,
                stock_minimo,
                costo_promedio
            )
            VALUES (
                v_detalle.id_producto,
                0,
                0,
                0
            );

            v_stock_anterior := 0;
            v_costo_anterior := 0;
        END IF;

        v_nuevo_stock := v_stock_anterior + v_detalle.cantidad;

        -- Cálculo del Costo Promedio Ponderado
        IF v_nuevo_stock > 0 THEN
            v_nuevo_costo := (
                (v_stock_anterior * v_costo_anterior) + (v_detalle.cantidad * v_detalle.costo_unitario)
            ) / v_nuevo_stock;
        ELSE
            v_nuevo_costo := v_detalle.costo_unitario;
        END IF;

        UPDATE electronica_az.existencia
        SET
            stock_actual = v_nuevo_stock,
            costo_promedio = v_nuevo_costo
        WHERE id_producto = v_detalle.id_producto;

        INSERT INTO electronica_az.movimiento_inventario (
            tipo,
            cantidad,
            motivo,
            costo_unitario,
            id_producto,
            id_usuario,
            id_detalle_compra
        )
        VALUES (
            'ENTRADA',
            v_detalle.cantidad,
            'Recepción de compra',
            v_detalle.costo_unitario,
            v_detalle.id_producto,
            p_id_usuario,
            v_detalle.id_detalle_compra
        );
    END LOOP;

    UPDATE electronica_az.compra
    SET estado = 'RECIBIDA'
    WHERE id_compra = p_id_compra;

    PERFORM electronica_az.fn_registrar_bitacora(
        'RECIBIR_COMPRA',
        p_id_compra::text,
        'Compra recibida correctamente',
        p_id_usuario,
        p_direccion_ip
    );
END;
$$;


-- ============================================================
-- 3. CONFIRMAR VENTA (Descuenta stock y fija costo histórico)
-- ============================================================
CREATE OR REPLACE PROCEDURE electronica_az.sp_confirmar_venta(
    p_id_venta uuid,
    p_id_usuario uuid,
    p_direccion_ip inet DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado varchar(120);
    v_detalle RECORD;
    v_stock numeric(18,4);
    v_costo numeric(18,4);
BEGIN
    SELECT estado
    INTO v_estado
    FROM electronica_az.venta
    WHERE id_venta = p_id_venta
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La venta % no existe', p_id_venta;
    END IF;

    IF v_estado <> 'BORRADOR' THEN
        RAISE EXCEPTION 'Solo se pueden confirmar ventas en estado BORRADOR. Estado actual: %', v_estado;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM electronica_az.detalle_venta
        WHERE id_venta = p_id_venta
    ) THEN
        RAISE EXCEPTION 'La venta no tiene productos registrados en su detalle';
    END IF;

    FOR v_detalle IN
        SELECT
            id_detalle_venta,
            id_producto,
            cantidad
        FROM electronica_az.detalle_venta
        WHERE id_venta = p_id_venta
    LOOP
        SELECT
            e.stock_actual,
            e.costo_promedio
        INTO
            v_stock,
            v_costo
        FROM electronica_az.existencia e
        WHERE e.id_producto = v_detalle.id_producto
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El producto % no tiene existencia registrada', v_detalle.id_producto;
        END IF;

        IF v_stock < v_detalle.cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente para el producto %. Stock actual: %, Solicitado: %',
                v_detalle.id_producto, v_stock, v_detalle.cantidad;
        END IF;

        -- Fijar costo promedio al momento de la venta
        UPDATE electronica_az.detalle_venta
        SET costo_unitario_historico = v_costo
        WHERE id_detalle_venta = v_detalle.id_detalle_venta;

        UPDATE electronica_az.existencia
        SET stock_actual = stock_actual - v_detalle.cantidad
        WHERE id_producto = v_detalle.id_producto;

        INSERT INTO electronica_az.movimiento_inventario (
            tipo,
            cantidad,
            motivo,
            costo_unitario,
            id_producto,
            id_usuario,
            id_detalle_venta
        )
        VALUES (
            'SALIDA',
            v_detalle.cantidad,
            'Confirmación de venta',
            v_costo,
            v_detalle.id_producto,
            p_id_usuario,
            v_detalle.id_detalle_venta
        );
    END LOOP;

    UPDATE electronica_az.venta
    SET estado = 'CONFIRMADA'
    WHERE id_venta = p_id_venta;

    PERFORM electronica_az.fn_registrar_bitacora(
        'CONFIRMAR_VENTA',
        p_id_venta::text,
        'Venta confirmada correctamente',
        p_id_usuario,
        p_direccion_ip
    );
END;
$$;


-- ============================================================
-- 4. ANULAR VENTA (Devuelve inventario al kardex)
-- ============================================================
CREATE OR REPLACE PROCEDURE electronica_az.sp_anular_venta(
    p_id_venta uuid,
    p_id_usuario uuid,
    p_direccion_ip inet DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado varchar(120);
    v_detalle RECORD;
BEGIN
    SELECT estado
    INTO v_estado
    FROM electronica_az.venta
    WHERE id_venta = p_id_venta
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La venta % no existe', p_id_venta;
    END IF;

    IF v_estado = 'ANULADA' THEN
        RAISE EXCEPTION 'La venta ya se encuentra anulada';
    END IF;

    -- Validar que no se haya realizado entrega física
    IF EXISTS (
        SELECT 1 FROM electronica_az.entrega WHERE id_venta = p_id_venta
    ) THEN
        RAISE EXCEPTION 'No se puede anular una venta que ya cuenta con entrega física registrada';
    END IF;

    -- Si estaba confirmada, se revierte el stock con su costo histórico
    IF v_estado = 'CONFIRMADA' THEN
        FOR v_detalle IN
            SELECT
                id_detalle_venta,
                id_producto,
                cantidad,
                costo_unitario_historico
            FROM electronica_az.detalle_venta
            WHERE id_venta = p_id_venta
        LOOP
            UPDATE electronica_az.existencia
            SET stock_actual = stock_actual + v_detalle.cantidad
            WHERE id_producto = v_detalle.id_producto;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'No existe inventario para el producto %', v_detalle.id_producto;
            END IF;

            INSERT INTO electronica_az.movimiento_inventario (
                tipo,
                cantidad,
                motivo,
                costo_unitario,
                id_producto,
                id_usuario,
                id_detalle_venta
            )
            VALUES (
                'ENTRADA',
                v_detalle.cantidad,
                'Anulación de venta',
                v_detalle.costo_unitario_historico,
                v_detalle.id_producto,
                p_id_usuario,
                v_detalle.id_detalle_venta
            );
        END LOOP;
    END IF;

    UPDATE electronica_az.venta
    SET estado = 'ANULADA'
    WHERE id_venta = p_id_venta;

    PERFORM electronica_az.fn_registrar_bitacora(
        'ANULAR_VENTA',
        p_id_venta::text,
        'Venta anulada correctamente',
        p_id_usuario,
        p_direccion_ip
    );
END;
$$;


-- ============================================================
-- 5. REGISTRAR PAGO
-- ============================================================
CREATE OR REPLACE PROCEDURE electronica_az.sp_registrar_pago(
    p_id_venta uuid,
    p_monto numeric(18,2),
    p_metodo varchar(120),
    p_estado varchar(120),
    p_referencia_externa varchar(200),
    p_id_usuario uuid,
    p_direccion_ip inet DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_venta varchar(120);
BEGIN
    IF p_monto <= 0 THEN
        RAISE EXCEPTION 'El monto del pago debe ser mayor que cero';
    END IF;

    IF p_metodo NOT IN ('EFECTIVO', 'QR') THEN
        RAISE EXCEPTION 'Método de pago no válido: %', p_metodo;
    END IF;

    IF p_estado NOT IN ('PENDIENTE', 'CONFIRMADO', 'RECHAZADO') THEN
        RAISE EXCEPTION 'Estado de pago no válido: %', p_estado;
    END IF;

    SELECT estado
    INTO v_estado_venta
    FROM electronica_az.venta
    WHERE id_venta = p_id_venta
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La venta % no existe', p_id_venta;
    END IF;

    IF v_estado_venta = 'ANULADA' THEN
        RAISE EXCEPTION 'No se puede registrar un pago para una venta anulada';
    END IF;

    INSERT INTO electronica_az.pago (
        monto,
        metodo,
        estado,
        referencia_externa,
        id_venta,
        id_usuario
    )
    VALUES (
        p_monto,
        p_metodo,
        p_estado,
        p_referencia_externa,
        p_id_venta,
        p_id_usuario
    );

    PERFORM electronica_az.fn_registrar_bitacora(
        'REGISTRAR_PAGO',
        p_id_venta::text,
        'Pago de BOB ' || p_monto::text || ' registrado correctamente (' || p_estado || ')',
        p_id_usuario,
        p_direccion_ip
    );
END;
$$;


-- ============================================================
-- 6. GENERAR COMPROBANTE
-- ============================================================
CREATE OR REPLACE PROCEDURE electronica_az.sp_generar_comprobante(
    p_id_venta uuid,
    p_numero varchar(120),
    p_id_usuario uuid DEFAULT NULL,
    p_direccion_ip inet DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado varchar(120);
BEGIN
    IF btrim(p_numero) = '' THEN
        RAISE EXCEPTION 'El número de comprobante no puede estar vacío';
    END IF;

    SELECT estado
    INTO v_estado
    FROM electronica_az.venta
    WHERE id_venta = p_id_venta;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La venta % no existe', p_id_venta;
    END IF;

    IF v_estado <> 'CONFIRMADA' THEN
        RAISE EXCEPTION 'Solo se puede emitir comprobante para una venta CONFIRMADA. Estado actual: %', v_estado;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM electronica_az.comprobante
        WHERE id_venta = p_id_venta
    ) THEN
        RAISE EXCEPTION 'La venta ya cuenta con un comprobante asignado';
    END IF;

    INSERT INTO electronica_az.comprobante (
        id_venta,
        numero
    )
    VALUES (
        p_id_venta,
        p_numero
    );

    IF p_id_usuario IS NOT NULL THEN
        PERFORM electronica_az.fn_registrar_bitacora(
            'GENERAR_COMPROBANTE',
            p_id_venta::text,
            'Comprobante Nro. ' || p_numero || ' emitido correctamente',
            p_id_usuario,
            p_direccion_ip
        );
    END IF;
END;
$$;


-- ============================================================
-- 7. ATENDER SOLICITUD DE PRODUCTO
-- ============================================================
CREATE OR REPLACE PROCEDURE electronica_az.sp_atender_solicitud_producto(
    p_id_solicitud uuid,
    p_id_usuario uuid,
    p_id_producto uuid DEFAULT NULL,
    p_id_modelo uuid DEFAULT NULL,
    p_observaciones text DEFAULT NULL,
    p_direccion_ip inet DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado varchar(120);
BEGIN
    SELECT estado
    INTO v_estado
    FROM electronica_az.solicitud_producto
    WHERE id_solicitud = p_id_solicitud
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud % no existe', p_id_solicitud;
    END IF;

    IF v_estado <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Solo se pueden atender solicitudes en estado PENDIENTE. Estado actual: %', v_estado;
    END IF;

    UPDATE electronica_az.solicitud_producto
    SET
        estado = 'ATENDIDA',
        id_producto = COALESCE(p_id_producto, id_producto),
        id_modelo = COALESCE(p_id_modelo, id_modelo),
        observaciones = COALESCE(p_observaciones, observaciones),
        id_usuario = p_id_usuario
    WHERE id_solicitud = p_id_solicitud;

    PERFORM electronica_az.fn_registrar_bitacora(
        'ATENDER_SOLICITUD',
        p_id_solicitud::text,
        'Solicitud atendida correctamente',
        p_id_usuario,
        p_direccion_ip
    );
END;
$$;


-- ============================================================
-- 8. CANCELAR SOLICITUD DE PRODUCTO
-- ============================================================
CREATE OR REPLACE PROCEDURE electronica_az.sp_cancelar_solicitud_producto(
    p_id_solicitud uuid,
    p_id_usuario uuid,
    p_observaciones text DEFAULT NULL,
    p_direccion_ip inet DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado varchar(120);
BEGIN
    SELECT estado
    INTO v_estado
    FROM electronica_az.solicitud_producto
    WHERE id_solicitud = p_id_solicitud
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud % no existe', p_id_solicitud;
    END IF;

    IF v_estado <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Solo se pueden cancelar solicitudes en estado PENDIENTE. Estado actual: %', v_estado;
    END IF;

    UPDATE electronica_az.solicitud_producto
    SET
        estado = 'CANCELADA',
        observaciones = COALESCE(p_observaciones, observaciones),
        id_usuario = p_id_usuario
    WHERE id_solicitud = p_id_solicitud;

    PERFORM electronica_az.fn_registrar_bitacora(
        'CANCELAR_SOLICITUD',
        p_id_solicitud::text,
        'Solicitud cancelada correctamente',
        p_id_usuario,
        p_direccion_ip
    );
END;
$$;


-- ============================================================
-- 9. ASIGNAR ROL A USUARIO
-- ============================================================
CREATE OR REPLACE PROCEDURE electronica_az.sp_asignar_rol_usuario(
    p_id_usuario uuid,
    p_id_rol uuid,
    p_id_usuario_operador uuid,
    p_direccion_ip inet DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM electronica_az.usuario WHERE id_usuario = p_id_usuario
    ) THEN
        RAISE EXCEPTION 'El usuario % no existe', p_id_usuario;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM electronica_az.rol WHERE id_rol = p_id_rol
    ) THEN
        RAISE EXCEPTION 'El rol % no existe', p_id_rol;
    END IF;

    INSERT INTO electronica_az.usuario_rol (
        id_usuario,
        id_rol
    )
    VALUES (
        p_id_usuario,
        p_id_rol
    )
    ON CONFLICT (id_usuario, id_rol) DO NOTHING;

    PERFORM electronica_az.fn_registrar_bitacora(
        'ASIGNAR_ROL',
        p_id_usuario::text,
        'Rol ' || p_id_rol::text || ' asignado al usuario',
        p_id_usuario_operador,
        p_direccion_ip
    );
END;
$$;


-- ============================================================
-- 10. REVOCAR ROL A USUARIO
-- ============================================================
CREATE OR REPLACE PROCEDURE electronica_az.sp_revocar_rol_usuario(
    p_id_usuario uuid,
    p_id_rol uuid,
    p_id_usuario_operador uuid,
    p_direccion_ip inet DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM electronica_az.usuario_rol
    WHERE id_usuario = p_id_usuario
      AND id_rol = p_id_rol;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario % no tiene asignado el rol %', p_id_usuario, p_id_rol;
    END IF;

    PERFORM electronica_az.fn_registrar_bitacora(
        'REVOCAR_ROL',
        p_id_usuario::text,
        'Rol ' || p_id_rol::text || ' revocado al usuario',
        p_id_usuario_operador,
        p_direccion_ip
    );
END;
$$;
