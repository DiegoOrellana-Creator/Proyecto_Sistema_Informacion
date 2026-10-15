-- ============================================================
-- TRIGGERS - ELECTRÓNICA CENTRAL AZ (ESQUEMA: electronica_az)
-- ============================================================

SET search_path = electronica_az, public;

-- ============================================================
-- 1. VALIDAR CATEGORÍA PADRE Y EVITAR CICLOS
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_validar_categoria_padre()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_ciclo boolean;
BEGIN
    IF NEW.id_categoria_padre IS NULL THEN
        RETURN NEW;
    END IF;

    -- Validar auto-referencia
    IF NEW.id_categoria IS NOT NULL AND NEW.id_categoria_padre = NEW.id_categoria THEN
        RAISE EXCEPTION 'Una categoría no puede ser su propia categoría padre';
    END IF;

    -- Detección de ciclos mediante CTE recursivo
    IF TG_OP = 'UPDATE' OR NEW.id_categoria IS NOT NULL THEN
        WITH RECURSIVE jerarquia AS (
            SELECT id_categoria, id_categoria_padre
            FROM electronica_az.categoria
            WHERE id_categoria = NEW.id_categoria_padre
            
            UNION ALL
            
            SELECT c.id_categoria, c.id_categoria_padre
            FROM electronica_az.categoria c
            INNER JOIN jerarquia j ON c.id_categoria = j.id_categoria_padre
        )
        SELECT EXISTS (
            SELECT 1 FROM jerarquia WHERE id_categoria = NEW.id_categoria
        ) INTO v_ciclo;

        IF v_ciclo THEN
            RAISE EXCEPTION 'La jerarquía de categorías genera un ciclo circular';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_categoria_padre ON electronica_az.categoria;
CREATE TRIGGER trg_validar_categoria_padre
BEFORE INSERT OR UPDATE OF id_categoria_padre
ON electronica_az.categoria
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_validar_categoria_padre();


-- ============================================================
-- 2. VALIDAR MARCA Y MODELO DEL PRODUCTO
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_validar_producto_marca_modelo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_marca_modelo uuid;
BEGIN
    IF NEW.id_modelo IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT id_marca
    INTO v_id_marca_modelo
    FROM electronica_az.modelo
    WHERE id_modelo = NEW.id_modelo;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El modelo indicado no existe';
    END IF;

    IF NEW.id_marca IS NOT NULL AND NEW.id_marca <> v_id_marca_modelo THEN
        RAISE EXCEPTION 'La marca del producto (%) no coincide con la marca del modelo (%)', NEW.id_marca, v_id_marca_modelo;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_producto_marca_modelo ON electronica_az.producto;
CREATE TRIGGER trg_validar_producto_marca_modelo
BEFORE INSERT OR UPDATE OF id_marca, id_modelo
ON electronica_az.producto
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_validar_producto_marca_modelo();


-- ============================================================
-- 3. IMPEDIR CAMBIAR LA MARCA DE UN MODELO EN USO
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_validar_cambio_marca_modelo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id_marca <> OLD.id_marca THEN
        IF EXISTS (
            SELECT 1
            FROM electronica_az.producto
            WHERE id_modelo = OLD.id_modelo
              AND id_marca IS NOT NULL
        ) THEN
            RAISE EXCEPTION 'No se puede cambiar la marca del modelo porque existen productos asociados a ella';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_cambio_marca_modelo ON electronica_az.modelo;
CREATE TRIGGER trg_validar_cambio_marca_modelo
BEFORE UPDATE OF id_marca
ON electronica_az.modelo
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_validar_cambio_marca_modelo();


-- ============================================================
-- 4. VALIDAR COMPATIBILIDAD
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_validar_compatibilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_modelo_producto uuid;
BEGIN
    SELECT id_modelo
    INTO v_id_modelo_producto
    FROM electronica_az.producto
    WHERE id_producto = NEW.id_producto;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto indicado no existe';
    END IF;

    IF v_id_modelo_producto IS NOT NULL AND v_id_modelo_producto = NEW.id_modelo THEN
        RAISE EXCEPTION 'El modelo ya corresponde al modelo principal asignado al producto';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_compatibilidad ON electronica_az.compatibilidad;
CREATE TRIGGER trg_validar_compatibilidad
BEFORE INSERT OR UPDATE
ON electronica_az.compatibilidad
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_validar_compatibilidad();


-- ============================================================
-- 5. CREAR EXISTENCIA AUTOMÁTICAMENTE AL CREAR PRODUCTO
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_crear_existencia_producto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO electronica_az.existencia (
        id_producto,
        stock_actual,
        stock_minimo,
        costo_promedio
    )
    VALUES (
        NEW.id_producto,
        0,
        0,
        0
    )
    ON CONFLICT (id_producto) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_crear_existencia_producto ON electronica_az.producto;
CREATE TRIGGER trg_crear_existencia_producto
AFTER INSERT
ON electronica_az.producto
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_crear_existencia_producto();


-- ============================================================
-- 6. VALIDAR CANTIDADES FRACCIONARIAS
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_validar_cantidad_unidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_permite_fraccion boolean;
BEGIN
    SELECT um.permite_fraccion
    INTO v_permite_fraccion
    FROM electronica_az.producto p
    INNER JOIN electronica_az.unidad_medida um
        ON um.id_unidad_medida = p.id_unidad_medida
    WHERE p.id_producto = NEW.id_producto;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto o su unidad de medida no existe';
    END IF;

    IF v_permite_fraccion = false AND NEW.cantidad <> trunc(NEW.cantidad) THEN
        RAISE EXCEPTION 'El producto no admite cantidades fraccionarias en esta unidad de medida';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_cantidad_detalle_compra ON electronica_az.detalle_compra;
CREATE TRIGGER trg_validar_cantidad_detalle_compra
BEFORE INSERT OR UPDATE OF id_producto, cantidad
ON electronica_az.detalle_compra
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_validar_cantidad_unidad();

DROP TRIGGER IF EXISTS trg_validar_cantidad_detalle_venta ON electronica_az.detalle_venta;
CREATE TRIGGER trg_validar_cantidad_detalle_venta
BEFORE INSERT OR UPDATE OF id_producto, cantidad
ON electronica_az.detalle_venta
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_validar_cantidad_unidad();

DROP TRIGGER IF EXISTS trg_validar_cantidad_solicitud ON electronica_az.solicitud_producto;
CREATE TRIGGER trg_validar_cantidad_solicitud
BEFORE INSERT OR UPDATE OF id_producto, cantidad
ON electronica_az.solicitud_producto
FOR EACH ROW
WHEN (NEW.id_producto IS NOT NULL)
EXECUTE FUNCTION electronica_az.fn_validar_cantidad_unidad();


-- ============================================================
-- 7. VALIDAR SOLICITUD DE PRODUCTO
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_validar_solicitud_producto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_activo boolean;
    v_modelo_producto uuid;
    v_compatibilidad boolean;
BEGIN
    IF NEW.id_producto IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT activo, id_modelo
    INTO v_activo, v_modelo_producto
    FROM electronica_az.producto
    WHERE id_producto = NEW.id_producto;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto indicado no existe';
    END IF;

    IF v_activo = false THEN
        RAISE EXCEPTION 'No se puede solicitar un producto inactivo';
    END IF;

    IF NEW.id_modelo IS NOT NULL THEN
        IF v_modelo_producto = NEW.id_modelo THEN
            RETURN NEW;
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM electronica_az.compatibilidad
            WHERE id_producto = NEW.id_producto
              AND id_modelo = NEW.id_modelo
        ) INTO v_compatibilidad;

        IF NOT v_compatibilidad THEN
            RAISE EXCEPTION 'El modelo indicado no corresponde al producto ni a una compatibilidad registrada';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_solicitud_producto ON electronica_az.solicitud_producto;
CREATE TRIGGER trg_validar_solicitud_producto
BEFORE INSERT OR UPDATE OF id_producto, id_modelo
ON electronica_az.solicitud_producto
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_validar_solicitud_producto();


-- ============================================================
-- 8. VALIDAR ESTADOS DE COMPRA
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_validar_estado_compra()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.estado = 'RECIBIDA' AND NEW.estado <> 'RECIBIDA' THEN
        RAISE EXCEPTION 'Una compra RECIBIDA no puede cambiar de estado';
    END IF;

    IF OLD.estado = 'CANCELADA' AND NEW.estado <> 'CANCELADA' THEN
        RAISE EXCEPTION 'Una compra CANCELADA no puede cambiar de estado';
    END IF;

    IF OLD.estado = 'PENDIENTE' AND NEW.estado NOT IN ('PENDIENTE', 'RECIBIDA', 'CANCELADA') THEN
        RAISE EXCEPTION 'Transición de estado de compra no permitida: % -> %', OLD.estado, NEW.estado;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_estado_compra ON electronica_az.compra;
CREATE TRIGGER trg_validar_estado_compra
BEFORE UPDATE OF estado
ON electronica_az.compra
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_validar_estado_compra();


-- ============================================================
-- 9. VALIDAR ESTADOS DE VENTA
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_validar_estado_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.estado = 'ANULADA' AND NEW.estado <> 'ANULADA' THEN
        RAISE EXCEPTION 'Una venta ANULADA no puede reactivarse ni cambiar de estado';
    END IF;

    IF OLD.estado = 'CONFIRMADA' AND NEW.estado NOT IN ('CONFIRMADA', 'ANULADA') THEN
        RAISE EXCEPTION 'Una venta CONFIRMADA solo puede pasar a ANULADA';
    END IF;

    IF OLD.estado = 'BORRADOR' AND NEW.estado NOT IN ('BORRADOR', 'CONFIRMADA', 'ANULADA') THEN
        RAISE EXCEPTION 'Transición de estado de venta no permitida: % -> %', OLD.estado, NEW.estado;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_estado_venta ON electronica_az.venta;
CREATE TRIGGER trg_validar_estado_venta
BEFORE UPDATE OF estado
ON electronica_az.venta
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_validar_estado_venta();


-- ============================================================
-- 10. IMPEDIR MODIFICAR DETALLES DE COMPRA RECIBIDA/CANCELADA
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_proteger_detalle_compra()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_compra uuid;
    v_estado varchar(120);
BEGIN
    v_id_compra := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_compra ELSE NEW.id_compra END;

    SELECT estado
    INTO v_estado
    FROM electronica_az.compra
    WHERE id_compra = v_id_compra;

    IF v_estado IN ('RECIBIDA', 'CANCELADA') THEN
        RAISE EXCEPTION 'No se pueden alterar detalles de una compra en estado %', v_estado;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_detalle_compra ON electronica_az.detalle_compra;
CREATE TRIGGER trg_proteger_detalle_compra
BEFORE INSERT OR UPDATE OR DELETE
ON electronica_az.detalle_compra
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_proteger_detalle_compra();


-- ============================================================
-- 11. IMPEDIR MODIFICAR DETALLES DE VENTA CONFIRMADA/ANULADA
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_proteger_detalle_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_venta uuid;
    v_estado varchar(120);
BEGIN
    v_id_venta := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_venta ELSE NEW.id_venta END;

    SELECT estado
    INTO v_estado
    FROM electronica_az.venta
    WHERE id_venta = v_id_venta;

    IF v_estado IN ('CONFIRMADA', 'ANULADA') THEN
        RAISE EXCEPTION 'No se pueden alterar detalles de una venta en estado %', v_estado;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_detalle_venta ON electronica_az.detalle_venta;
CREATE TRIGGER trg_proteger_detalle_venta
BEFORE INSERT OR UPDATE OR DELETE
ON electronica_az.detalle_venta
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_proteger_detalle_venta();


-- ============================================================
-- 12. VALIDAR PAGOS CONFIRMADOS CONTRA TOTAL DE VENTA
-- ============================================================
CREATE OR REPLACE FUNCTION electronica_az.fn_validar_pago_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_venta numeric(18,4);
    v_total_pagado numeric(18,4);
    v_estado_venta varchar(120);
BEGIN
    -- Bloqueo pesimista de la fila de venta para evitar race conditions
    SELECT estado
    INTO v_estado_venta
    FROM electronica_az.venta
    WHERE id_venta = NEW.id_venta
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La venta indicada no existe';
    END IF;

    IF v_estado_venta = 'ANULADA' THEN
        RAISE EXCEPTION 'No se puede registrar pagos para una venta anulada';
    END IF;

    IF NEW.estado = 'CONFIRMADO' THEN
        SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
        INTO v_total_venta
        FROM electronica_az.detalle_venta
        WHERE id_venta = NEW.id_venta;

        SELECT COALESCE(SUM(monto), 0)
        INTO v_total_pagado
        FROM electronica_az.pago
        WHERE id_venta = NEW.id_venta
          AND estado = 'CONFIRMADO'
          AND (TG_OP = 'INSERT' OR id_pago <> OLD.id_pago);

        IF (v_total_pagado + NEW.monto) > v_total_venta THEN
            RAISE EXCEPTION 'El total de pagos confirmados (BOB %) supera el total de la venta (BOB %)',
                (v_total_pagado + NEW.monto), v_total_venta;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_pago_venta ON electronica_az.pago;
CREATE TRIGGER trg_validar_pago_venta
BEFORE INSERT OR UPDATE OF monto, estado, id_venta
ON electronica_az.pago
FOR EACH ROW
EXECUTE FUNCTION electronica_az.fn_validar_pago_venta();
