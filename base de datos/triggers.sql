-- ============================================================
-- TRIGGERS - TIENDA DE COMPONENTES ELECTRÓNICOS
-- ============================================================


-- ============================================================
-- 1. VALIDAR CATEGORÍA PADRE Y EVITAR CICLOS
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_categoria_padre()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_padre uuid;
    v_visitada uuid[];
BEGIN

    -- Una categoría no puede ser su propio padre
    IF NEW.id_categoria_padre = NEW.id_categoria THEN
        RAISE EXCEPTION
            'Una categoría no puede ser su propia categoría padre';
    END IF;

    -- Si no tiene padre, no hay nada que recorrer
    IF NEW.id_categoria_padre IS NULL THEN
        RETURN NEW;
    END IF;

    v_padre := NEW.id_categoria_padre;
    v_visitada := ARRAY[NEW.id_categoria];

    WHILE v_padre IS NOT NULL LOOP

        -- Detectar ciclo
        IF v_padre = ANY(v_visitada) THEN
            RAISE EXCEPTION
                'La jerarquía de categorías genera un ciclo';
        END IF;

        v_visitada := array_append(v_visitada, v_padre);

        SELECT id_categoria_padre
        INTO v_padre
        FROM categoria
        WHERE id_categoria = v_padre;

        -- El FK se encargará de validar si el padre existe
        IF NOT FOUND THEN
            EXIT;
        END IF;

    END LOOP;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_categoria_padre
ON categoria;

CREATE TRIGGER trg_validar_categoria_padre
BEFORE INSERT OR UPDATE OF id_categoria_padre
ON categoria
FOR EACH ROW
EXECUTE FUNCTION fn_validar_categoria_padre();


-- ============================================================
-- 2. VALIDAR MARCA Y MODELO DEL PRODUCTO
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_producto_marca_modelo()
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
    FROM modelo
    WHERE id_modelo = NEW.id_modelo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El modelo indicado no existe';
    END IF;

    IF NEW.id_marca IS NOT NULL
       AND NEW.id_marca <> v_id_marca_modelo THEN

        RAISE EXCEPTION
            'La marca del producto no coincide con la marca del modelo';

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_producto_marca_modelo
ON producto;

CREATE TRIGGER trg_validar_producto_marca_modelo
BEFORE INSERT OR UPDATE OF id_marca, id_modelo
ON producto
FOR EACH ROW
EXECUTE FUNCTION fn_validar_producto_marca_modelo();


-- ============================================================
-- 3. IMPEDIR CAMBIAR LA MARCA DE UN MODELO EN USO
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_cambio_marca_modelo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF NEW.id_marca <> OLD.id_marca THEN

        IF EXISTS (
            SELECT 1
            FROM producto
            WHERE id_modelo = OLD.id_modelo
              AND id_marca IS NOT NULL
        ) THEN

            RAISE EXCEPTION
                'No se puede cambiar la marca del modelo porque existen productos asociados';

        END IF;

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_cambio_marca_modelo
ON modelo;

CREATE TRIGGER trg_validar_cambio_marca_modelo
BEFORE UPDATE OF id_marca
ON modelo
FOR EACH ROW
EXECUTE FUNCTION fn_validar_cambio_marca_modelo();


-- ============================================================
-- 4. VALIDAR COMPATIBILIDAD
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_compatibilidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_modelo_producto uuid;
BEGIN

    SELECT id_modelo
    INTO v_id_modelo_producto
    FROM producto
    WHERE id_producto = NEW.id_producto;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El producto indicado no existe';
    END IF;

    IF v_id_modelo_producto IS NOT NULL
       AND v_id_modelo_producto = NEW.id_modelo THEN

        RAISE EXCEPTION
            'El modelo ya corresponde al modelo principal del producto';

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_compatibilidad
ON compatibilidad;

CREATE TRIGGER trg_validar_compatibilidad
BEFORE INSERT OR UPDATE
ON compatibilidad
FOR EACH ROW
EXECUTE FUNCTION fn_validar_compatibilidad();


-- ============================================================
-- 5. CREAR EXISTENCIA AUTOMÁTICAMENTE AL CREAR PRODUCTO
-- ============================================================

CREATE OR REPLACE FUNCTION fn_crear_existencia_producto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO existencia (
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


DROP TRIGGER IF EXISTS trg_crear_existencia_producto
ON producto;

CREATE TRIGGER trg_crear_existencia_producto
AFTER INSERT
ON producto
FOR EACH ROW
EXECUTE FUNCTION fn_crear_existencia_producto();


-- ============================================================
-- 6. VALIDAR CANTIDADES FRACCIONARIAS
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_cantidad_unidad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_permite_fraccion boolean;
BEGIN

    SELECT um.permite_fraccion
    INTO v_permite_fraccion
    FROM producto p
    INNER JOIN unidad_medida um
        ON um.id_unidad_medida = p.id_unidad_medida
    WHERE p.id_producto = NEW.id_producto;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El producto o su unidad de medida no existe';
    END IF;

    IF v_permite_fraccion = false
       AND NEW.cantidad <> trunc(NEW.cantidad) THEN

        RAISE EXCEPTION
            'El producto no permite cantidades fraccionarias';

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_cantidad_detalle_compra
ON detalle_compra;

CREATE TRIGGER trg_validar_cantidad_detalle_compra
BEFORE INSERT OR UPDATE OF id_producto, cantidad
ON detalle_compra
FOR EACH ROW
EXECUTE FUNCTION fn_validar_cantidad_unidad();


DROP TRIGGER IF EXISTS trg_validar_cantidad_detalle_venta
ON detalle_venta;

CREATE TRIGGER trg_validar_cantidad_detalle_venta
BEFORE INSERT OR UPDATE OF id_producto, cantidad
ON detalle_venta
FOR EACH ROW
EXECUTE FUNCTION fn_validar_cantidad_unidad();


DROP TRIGGER IF EXISTS trg_validar_cantidad_solicitud
ON solicitud_producto;

CREATE TRIGGER trg_validar_cantidad_solicitud
BEFORE INSERT OR UPDATE OF id_producto, cantidad
ON solicitud_producto
FOR EACH ROW
EXECUTE FUNCTION fn_validar_cantidad_unidad();


-- ============================================================
-- 7. VALIDAR SOLICITUD DE PRODUCTO
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_solicitud_producto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_activo boolean;
    v_modelo_producto uuid;
    v_compatibilidad boolean;
BEGIN

    -- Si no hay producto concreto,
    -- se permite una solicitud libre.
    IF NEW.id_producto IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT activo, id_modelo
    INTO v_activo, v_modelo_producto
    FROM producto
    WHERE id_producto = NEW.id_producto;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El producto indicado no existe';
    END IF;

    IF v_activo = false THEN
        RAISE EXCEPTION
            'No se puede solicitar un producto que está inactivo';
    END IF;

    -- Si se especifica modelo, verificar relación
    IF NEW.id_modelo IS NOT NULL THEN

        IF v_modelo_producto = NEW.id_modelo THEN
            RETURN NEW;
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM compatibilidad
            WHERE id_producto = NEW.id_producto
              AND id_modelo = NEW.id_modelo
        )
        INTO v_compatibilidad;

        IF NOT v_compatibilidad THEN
            RAISE EXCEPTION
                'El modelo indicado no corresponde al producto ni a una compatibilidad registrada';
        END IF;

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_solicitud_producto
ON solicitud_producto;

CREATE TRIGGER trg_validar_solicitud_producto
BEFORE INSERT OR UPDATE OF id_producto, id_modelo
ON solicitud_producto
FOR EACH ROW
EXECUTE FUNCTION fn_validar_solicitud_producto();


-- ============================================================
-- 8. VALIDAR ESTADOS DE COMPRA
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_estado_compra()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF OLD.estado = 'RECIBIDA'
       AND NEW.estado <> 'RECIBIDA' THEN

        RAISE EXCEPTION
            'Una compra RECIBIDA no puede cambiar nuevamente de estado';

    END IF;

    IF OLD.estado = 'CANCELADA'
       AND NEW.estado <> 'CANCELADA' THEN

        RAISE EXCEPTION
            'Una compra CANCELADA no puede cambiar nuevamente de estado';

    END IF;

    IF OLD.estado = 'PENDIENTE'
       AND NEW.estado NOT IN ('PENDIENTE', 'RECIBIDA', 'CANCELADA') THEN

        RAISE EXCEPTION
            'Transición de estado de compra no permitida';

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_estado_compra
ON compra;

CREATE TRIGGER trg_validar_estado_compra
BEFORE UPDATE OF estado
ON compra
FOR EACH ROW
EXECUTE FUNCTION fn_validar_estado_compra();


-- ============================================================
-- 9. VALIDAR ESTADOS DE VENTA
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_estado_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF OLD.estado = 'ANULADA'
       AND NEW.estado <> 'ANULADA' THEN

        RAISE EXCEPTION
            'Una venta ANULADA no puede volver a otro estado';

    END IF;

    IF OLD.estado = 'CONFIRMADA'
       AND NEW.estado NOT IN ('CONFIRMADA', 'ANULADA') THEN

        RAISE EXCEPTION
            'Una venta CONFIRMADA solamente puede permanecer confirmada o ser anulada';

    END IF;

    IF OLD.estado = 'BORRADOR'
       AND NEW.estado NOT IN ('BORRADOR', 'CONFIRMADA', 'ANULADA') THEN

        RAISE EXCEPTION
            'Transición de estado de venta no permitida';

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_estado_venta
ON venta;

CREATE TRIGGER trg_validar_estado_venta
BEFORE UPDATE OF estado
ON venta
FOR EACH ROW
EXECUTE FUNCTION fn_validar_estado_venta();


-- ============================================================
-- 10. IMPEDIR MODIFICAR DETALLES DE COMPRA RECIBIDA/CANCELADA
-- ============================================================

CREATE OR REPLACE FUNCTION fn_proteger_detalle_compra()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado varchar(120);
BEGIN

    SELECT estado
    INTO v_estado
    FROM compra
    WHERE id_compra = COALESCE(OLD.id_compra, NEW.id_compra);

    IF v_estado IN ('RECIBIDA', 'CANCELADA') THEN

        RAISE EXCEPTION
            'No se pueden modificar detalles de una compra RECIBIDA o CANCELADA';

    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_proteger_detalle_compra
ON detalle_compra;

CREATE TRIGGER trg_proteger_detalle_compra
BEFORE INSERT OR UPDATE OR DELETE
ON detalle_compra
FOR EACH ROW
EXECUTE FUNCTION fn_proteger_detalle_compra();


-- ============================================================
-- 11. IMPEDIR MODIFICAR DETALLES DE VENTA CONFIRMADA/ANULADA
-- ============================================================

CREATE OR REPLACE FUNCTION fn_proteger_detalle_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado varchar(120);
BEGIN

    SELECT estado
    INTO v_estado
    FROM venta
    WHERE id_venta = COALESCE(OLD.id_venta, NEW.id_venta);

    IF v_estado IN ('CONFIRMADA', 'ANULADA') THEN

        RAISE EXCEPTION
            'No se pueden modificar detalles de una venta CONFIRMADA o ANULADA';

    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_proteger_detalle_venta
ON detalle_venta;

CREATE TRIGGER trg_proteger_detalle_venta
BEFORE INSERT OR UPDATE OR DELETE
ON detalle_venta
FOR EACH ROW
EXECUTE FUNCTION fn_proteger_detalle_venta();


-- ============================================================
-- 12. VALIDAR COSTO HISTÓRICO DE VENTA
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_costo_historico_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado varchar(120);
BEGIN

    SELECT estado
    INTO v_estado
    FROM venta
    WHERE id_venta = NEW.id_venta;

    IF v_estado IN ('CONFIRMADA', 'ANULADA')
       AND NEW.costo_unitario_historico
           <> OLD.costo_unitario_historico THEN

        RAISE EXCEPTION
            'No se puede modificar el costo histórico de una venta confirmada o anulada';

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_costo_historico_venta
ON detalle_venta;

CREATE TRIGGER trg_validar_costo_historico_venta
BEFORE UPDATE OF costo_unitario_historico
ON detalle_venta
FOR EACH ROW
EXECUTE FUNCTION fn_validar_costo_historico_venta();


-- ============================================================
-- 13. VALIDAR PAGOS CONFIRMADOS CONTRA TOTAL DE VENTA
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_pago_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_venta numeric(18,4);
    v_total_pagado numeric(18,4);
    v_estado_venta varchar(120);
BEGIN

    SELECT estado
    INTO v_estado_venta
    FROM venta
    WHERE id_venta = NEW.id_venta;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La venta indicada no existe';
    END IF;

    IF v_estado_venta = 'ANULADA' THEN
        RAISE EXCEPTION
            'No se puede registrar un pago para una venta anulada';
    END IF;

    -- Solo se valida el límite cuando el pago queda confirmado
    IF NEW.estado = 'CONFIRMADO' THEN

        SELECT COALESCE(
            SUM(cantidad * precio_unitario),
            0
        )
        INTO v_total_venta
        FROM detalle_venta
        WHERE id_venta = NEW.id_venta;

        SELECT COALESCE(
            SUM(monto),
            0
        )
        INTO v_total_pagado
        FROM pago
        WHERE id_venta = NEW.id_venta
          AND estado = 'CONFIRMADO'
          AND (TG_OP = 'INSERT' OR id_pago <> NEW.id_pago);

        IF v_total_pagado + NEW.monto > v_total_venta THEN

            RAISE EXCEPTION
                'El total de pagos confirmados supera el total de la venta';

        END IF;

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_pago_venta
ON pago;

CREATE TRIGGER trg_validar_pago_venta
BEFORE INSERT OR UPDATE OF monto, estado, id_venta
ON pago
FOR EACH ROW
EXECUTE FUNCTION fn_validar_pago_venta();


