-- ============================================================
-- BASE DE DATOS - TIENDA DE COMPONENTES ELECTRÓNICOS
-- ESQUEMA
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================
-- SEGURIDAD
-- ============================================================

CREATE TABLE rol (
    id_rol uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    descripcion text,

    CONSTRAINT pk_rol PRIMARY KEY (id_rol),
    CONSTRAINT uq_rol_nombre UNIQUE (nombre)
);


CREATE TABLE permiso (
    id_permiso uuid NOT NULL DEFAULT gen_random_uuid(),
    codigo varchar(120) NOT NULL,
    descripcion text,

    CONSTRAINT pk_permiso PRIMARY KEY (id_permiso),
    CONSTRAINT uq_permiso_codigo UNIQUE (codigo)
);


CREATE TABLE usuario (
    id_usuario uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre_usuario varchar(120) NOT NULL,
    correo varchar(254) NOT NULL,
    hash_contrasena text NOT NULL,
    activo boolean NOT NULL DEFAULT true,

    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_nombre_usuario UNIQUE (nombre_usuario),
    CONSTRAINT uq_usuario_correo UNIQUE (correo),

    CONSTRAINT ck_usuario_correo
        CHECK (btrim(correo) <> ''),

    CONSTRAINT ck_usuario_nombre
        CHECK (btrim(nombre_usuario) <> ''),

    CONSTRAINT ck_usuario_hash
        CHECK (btrim(hash_contrasena) <> '')
);


CREATE TABLE usuario_rol (
    id_usuario uuid NOT NULL,
    id_rol uuid NOT NULL,

    CONSTRAINT pk_usuario_rol
        PRIMARY KEY (id_usuario, id_rol)
);


CREATE TABLE rol_permiso (
    id_rol uuid NOT NULL,
    id_permiso uuid NOT NULL,

    CONSTRAINT pk_rol_permiso
        PRIMARY KEY (id_rol, id_permiso)
);


CREATE TABLE cliente (
    id_cliente uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    documento varchar(120),
    telefono varchar(120),
    correo varchar(254),
    id_usuario uuid,

    CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
    CONSTRAINT uq_cliente_id_usuario UNIQUE (id_usuario)
);


CREATE TABLE registro_bitacora (
    id_registro uuid NOT NULL DEFAULT gen_random_uuid(),
    fecha_hora timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    accion varchar(120) NOT NULL,
    objeto_afectado text NOT NULL,
    resultado text NOT NULL,
    direccion_ip inet,
    id_usuario uuid,

    CONSTRAINT pk_registro_bitacora
        PRIMARY KEY (id_registro)
);


-- ============================================================
-- CATÁLOGO
-- ============================================================

CREATE TABLE categoria (
    id_categoria uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    descripcion text,

    CONSTRAINT pk_categoria PRIMARY KEY (id_categoria)
);


CREATE TABLE marca (
    id_marca uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,

    CONSTRAINT pk_marca PRIMARY KEY (id_marca)
);


CREATE TABLE modelo (
    id_modelo uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    descripcion text,
    id_marca uuid NOT NULL,

    CONSTRAINT pk_modelo PRIMARY KEY (id_modelo)
);


CREATE TABLE unidad_medida (
    id_unidad_medida uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    simbolo varchar(120) NOT NULL,
    permite_fraccion boolean NOT NULL DEFAULT false,

    CONSTRAINT pk_unidad_medida
        PRIMARY KEY (id_unidad_medida)
);


CREATE TABLE ubicacion (
    id_ubicacion uuid NOT NULL DEFAULT gen_random_uuid(),
    codigo varchar(120) NOT NULL,
    pasillo varchar(120) NOT NULL,
    estante varchar(120) NOT NULL,

    CONSTRAINT pk_ubicacion PRIMARY KEY (id_ubicacion)
);


-- ============================================================
-- PRODUCTOS
-- ============================================================

CREATE TABLE producto (
    id_producto uuid NOT NULL DEFAULT gen_random_uuid(),
    codigo varchar(120) NOT NULL,
    nombre varchar(120) NOT NULL,
    descripcion text,
    precio_venta numeric(18,4) NOT NULL,
    activo boolean NOT NULL DEFAULT true,
    id_categoria uuid NOT NULL,
    id_unidad_medida uuid NOT NULL,
    id_ubicacion uuid NOT NULL,
    id_marca uuid,
    id_modelo uuid,

    CONSTRAINT pk_producto PRIMARY KEY (id_producto),

    CONSTRAINT uq_producto_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_producto_precio_venta
        CHECK (
            precio_venta >= 0
            AND precio_venta <> 'NaN'::numeric
        )
);


CREATE TABLE compatibilidad (
    id_producto uuid NOT NULL,
    id_modelo uuid NOT NULL,
    observaciones text,

    CONSTRAINT pk_compatibilidad
        PRIMARY KEY (id_producto, id_modelo)
);


-- ============================================================
-- INVENTARIO
-- ============================================================

CREATE TABLE existencia (
    id_producto uuid NOT NULL,
    stock_actual numeric(18,4) NOT NULL DEFAULT 0,
    stock_minimo numeric(18,4) NOT NULL DEFAULT 0,
    costo_promedio numeric(18,4) NOT NULL DEFAULT 0,

    CONSTRAINT pk_existencia
        PRIMARY KEY (id_producto),

    CONSTRAINT ck_existencia_stock_actual
        CHECK (
            stock_actual >= 0
            AND stock_actual <> 'NaN'::numeric
        ),

    CONSTRAINT ck_existencia_stock_minimo
        CHECK (
            stock_minimo >= 0
            AND stock_minimo <> 'NaN'::numeric
        ),

    CONSTRAINT ck_existencia_costo_promedio
        CHECK (
            costo_promedio >= 0
            AND costo_promedio <> 'NaN'::numeric
        )
);


CREATE TABLE movimiento_inventario (
    id_movimiento uuid NOT NULL DEFAULT gen_random_uuid(),
    fecha_hora timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo varchar(120) NOT NULL,
    cantidad numeric(18,4) NOT NULL,
    motivo text NOT NULL,
    costo_unitario numeric(18,4) NOT NULL,
    id_producto uuid NOT NULL,
    id_usuario uuid NOT NULL,
    id_detalle_compra uuid,
    id_detalle_venta uuid,

    CONSTRAINT pk_movimiento_inventario
        PRIMARY KEY (id_movimiento),

    CONSTRAINT ck_movimiento_inventario_cantidad
        CHECK (
            cantidad > 0
            AND cantidad <> 'NaN'::numeric
        ),

    CONSTRAINT ck_movimiento_inventario_costo_unitario
        CHECK (
            costo_unitario >= 0
            AND costo_unitario <> 'NaN'::numeric
        ),

    CONSTRAINT ck_movimiento_tipo
        CHECK (tipo IN ('ENTRADA', 'SALIDA')),

    CONSTRAINT ck_movimiento_origen
        CHECK (
            id_detalle_compra IS NULL
            OR id_detalle_venta IS NULL
        )
);


-- ============================================================
-- COMPRAS
-- ============================================================

CREATE TABLE proveedor (
    id_proveedor uuid NOT NULL DEFAULT gen_random_uuid(),
    razon_social varchar(120) NOT NULL,
    documento varchar(120),
    telefono varchar(120),
    correo varchar(254),
    direccion varchar(300),
    activo boolean NOT NULL DEFAULT true,

    CONSTRAINT pk_proveedor PRIMARY KEY (id_proveedor)
);


CREATE TABLE compra (
    id_compra uuid NOT NULL DEFAULT gen_random_uuid(),
    fecha timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado varchar(120) NOT NULL DEFAULT 'PENDIENTE',
    id_proveedor uuid NOT NULL,
    id_usuario uuid NOT NULL,

    CONSTRAINT pk_compra PRIMARY KEY (id_compra),

    CONSTRAINT ck_compra_estado
        CHECK (estado IN (
            'PENDIENTE',
            'RECIBIDA',
            'CANCELADA'
        ))
);


CREATE TABLE detalle_compra (
    id_detalle_compra uuid NOT NULL DEFAULT gen_random_uuid(),
    id_compra uuid NOT NULL,
    id_producto uuid NOT NULL,
    cantidad numeric(18,4) NOT NULL,
    costo_unitario numeric(18,4) NOT NULL,

    CONSTRAINT pk_detalle_compra
        PRIMARY KEY (id_detalle_compra),

    CONSTRAINT ck_detalle_compra_cantidad
        CHECK (
            cantidad > 0
            AND cantidad <> 'NaN'::numeric
        ),

    CONSTRAINT ck_detalle_compra_costo_unitario
        CHECK (
            costo_unitario >= 0
            AND costo_unitario <> 'NaN'::numeric
        )
);


-- ============================================================
-- VENTAS
-- ============================================================

CREATE TABLE venta (
    id_venta uuid NOT NULL DEFAULT gen_random_uuid(),
    fecha_hora timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado varchar(120) NOT NULL DEFAULT 'BORRADOR',
    id_cliente uuid NOT NULL,
    id_usuario uuid NOT NULL,

    CONSTRAINT pk_venta PRIMARY KEY (id_venta),

    CONSTRAINT ck_venta_estado
        CHECK (estado IN (
            'BORRADOR',
            'CONFIRMADA',
            'ANULADA'
        ))
);


CREATE TABLE detalle_venta (
    id_detalle_venta uuid NOT NULL DEFAULT gen_random_uuid(),
    id_venta uuid NOT NULL,
    id_producto uuid NOT NULL,
    cantidad numeric(18,4) NOT NULL,
    precio_unitario numeric(18,4) NOT NULL,
    costo_unitario_historico numeric(18,4) NOT NULL,

    CONSTRAINT pk_detalle_venta
        PRIMARY KEY (id_detalle_venta),

    CONSTRAINT ck_detalle_venta_cantidad
        CHECK (
            cantidad > 0
            AND cantidad <> 'NaN'::numeric
        ),

    CONSTRAINT ck_detalle_venta_precio_unitario
        CHECK (
            precio_unitario >= 0
            AND precio_unitario <> 'NaN'::numeric
        ),

    CONSTRAINT ck_detalle_venta_costo_unitario_historico
        CHECK (
            costo_unitario_historico >= 0
            AND costo_unitario_historico <> 'NaN'::numeric
        )
);


CREATE TABLE pago (
    id_pago uuid NOT NULL DEFAULT gen_random_uuid(),
    fecha_hora timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto numeric(18,2) NOT NULL,
    metodo varchar(120) NOT NULL,
    estado varchar(120) NOT NULL DEFAULT 'PENDIENTE',
    referencia_externa varchar(200),
    id_venta uuid NOT NULL,
    id_usuario uuid NOT NULL,

    CONSTRAINT pk_pago PRIMARY KEY (id_pago),

    CONSTRAINT uq_pago_referencia_externa
        UNIQUE (referencia_externa),

    CONSTRAINT ck_pago_monto
        CHECK (
            monto > 0
            AND monto <> 'NaN'::numeric
        ),

    CONSTRAINT ck_pago_estado
        CHECK (estado IN (
            'PENDIENTE',
            'CONFIRMADO',
            'RECHAZADO'
        )),

    CONSTRAINT ck_pago_metodo
        CHECK (metodo IN ('EFECTIVO', 'QR'))
);


CREATE TABLE comprobante (
    id_venta uuid NOT NULL,
    numero varchar(120) NOT NULL,
    fecha_emision timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_comprobante
        PRIMARY KEY (id_venta),

    CONSTRAINT uq_comprobante_numero
        UNIQUE (numero)
);


-- ============================================================
-- SOLICITUDES
-- ============================================================

CREATE TABLE solicitud_producto (
    id_solicitud uuid NOT NULL DEFAULT gen_random_uuid(),
    fecha_hora timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descripcion_producto text NOT NULL,
    cantidad numeric(18,4) NOT NULL,
    estado varchar(120) NOT NULL DEFAULT 'PENDIENTE',
    observaciones text,
    id_cliente uuid NOT NULL,
    id_usuario uuid NOT NULL,
    id_producto uuid,
    id_modelo uuid,

    CONSTRAINT pk_solicitud_producto
        PRIMARY KEY (id_solicitud),

    CONSTRAINT ck_solicitud_producto_cantidad
        CHECK (
            cantidad > 0
            AND cantidad <> 'NaN'::numeric
        ),

    CONSTRAINT ck_solicitud_producto_estado
        CHECK (estado IN (
            'PENDIENTE',
            'ATENDIDA',
            'CANCELADA'
        ))
);


-- ============================================================
-- LLAVES FORÁNEAS
-- ============================================================

ALTER TABLE usuario_rol
    ADD CONSTRAINT fk_usuario_rol_id_usuario
    FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE usuario_rol
    ADD CONSTRAINT fk_usuario_rol_id_rol
    FOREIGN KEY (id_rol)
    REFERENCES rol(id_rol)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE rol_permiso
    ADD CONSTRAINT fk_rol_permiso_id_rol
    FOREIGN KEY (id_rol)
    REFERENCES rol(id_rol)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE rol_permiso
    ADD CONSTRAINT fk_rol_permiso_id_permiso
    FOREIGN KEY (id_permiso)
    REFERENCES permiso(id_permiso)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE cliente
    ADD CONSTRAINT fk_cliente_id_usuario
    FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE registro_bitacora
    ADD CONSTRAINT fk_registro_bitacora_id_usuario
    FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE modelo
    ADD CONSTRAINT fk_modelo_id_marca
    FOREIGN KEY (id_marca)
    REFERENCES marca(id_marca)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE producto
    ADD CONSTRAINT fk_producto_id_categoria
    FOREIGN KEY (id_categoria)
    REFERENCES categoria(id_categoria)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE producto
    ADD CONSTRAINT fk_producto_id_unidad_medida
    FOREIGN KEY (id_unidad_medida)
    REFERENCES unidad_medida(id_unidad_medida)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE producto
    ADD CONSTRAINT fk_producto_id_ubicacion
    FOREIGN KEY (id_ubicacion)
    REFERENCES ubicacion(id_ubicacion)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE producto
    ADD CONSTRAINT fk_producto_id_marca
    FOREIGN KEY (id_marca)
    REFERENCES marca(id_marca)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE producto
    ADD CONSTRAINT fk_producto_id_modelo
    FOREIGN KEY (id_modelo)
    REFERENCES modelo(id_modelo)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE compatibilidad
    ADD CONSTRAINT fk_compatibilidad_id_producto
    FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE compatibilidad
    ADD CONSTRAINT fk_compatibilidad_id_modelo
    FOREIGN KEY (id_modelo)
    REFERENCES modelo(id_modelo)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE existencia
    ADD CONSTRAINT fk_existencia_id_producto
    FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE movimiento_inventario
    ADD CONSTRAINT fk_movimiento_inventario_id_producto
    FOREIGN KEY (id_producto)
    REFERENCES existencia(id_producto)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE movimiento_inventario
    ADD CONSTRAINT fk_movimiento_inventario_id_usuario
    FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE movimiento_inventario
    ADD CONSTRAINT fk_movimiento_inventario_id_detalle_compra
    FOREIGN KEY (id_detalle_compra)
    REFERENCES detalle_compra(id_detalle_compra)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE movimiento_inventario
    ADD CONSTRAINT fk_movimiento_inventario_id_detalle_venta
    FOREIGN KEY (id_detalle_venta)
    REFERENCES detalle_venta(id_detalle_venta)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE compra
    ADD CONSTRAINT fk_compra_id_proveedor
    FOREIGN KEY (id_proveedor)
    REFERENCES proveedor(id_proveedor)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE compra
    ADD CONSTRAINT fk_compra_id_usuario
    FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE detalle_compra
    ADD CONSTRAINT fk_detalle_compra_id_compra
    FOREIGN KEY (id_compra)
    REFERENCES compra(id_compra)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE detalle_compra
    ADD CONSTRAINT fk_detalle_compra_id_producto
    FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE venta
    ADD CONSTRAINT fk_venta_id_cliente
    FOREIGN KEY (id_cliente)
    REFERENCES cliente(id_cliente)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE venta
    ADD CONSTRAINT fk_venta_id_usuario
    FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE detalle_venta
    ADD CONSTRAINT fk_detalle_venta_id_venta
    FOREIGN KEY (id_venta)
    REFERENCES venta(id_venta)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE detalle_venta
    ADD CONSTRAINT fk_detalle_venta_id_producto
    FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE pago
    ADD CONSTRAINT fk_pago_id_venta
    FOREIGN KEY (id_venta)
    REFERENCES venta(id_venta)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE pago
    ADD CONSTRAINT fk_pago_id_usuario
    FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE comprobante
    ADD CONSTRAINT fk_comprobante_id_venta
    FOREIGN KEY (id_venta)
    REFERENCES venta(id_venta)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


ALTER TABLE solicitud_producto
    ADD CONSTRAINT fk_solicitud_producto_id_cliente
    FOREIGN KEY (id_cliente)
    REFERENCES cliente(id_cliente)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE solicitud_producto
    ADD CONSTRAINT fk_solicitud_producto_id_usuario
    FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE solicitud_producto
    ADD CONSTRAINT fk_solicitud_producto_id_producto
    FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

ALTER TABLE solicitud_producto
    ADD CONSTRAINT fk_solicitud_producto_id_modelo
    FOREIGN KEY (id_modelo)
    REFERENCES modelo(id_modelo)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;


-- ============================================================
-- ÍNDICES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_usuario_activo
    ON usuario(activo);

CREATE INDEX IF NOT EXISTS idx_cliente_usuario
    ON cliente(id_usuario);

CREATE INDEX IF NOT EXISTS idx_bitacora_fecha_hora
    ON registro_bitacora(fecha_hora DESC);

CREATE INDEX IF NOT EXISTS idx_bitacora_accion
    ON registro_bitacora(accion);

CREATE INDEX IF NOT EXISTS idx_bitacora_objeto
    ON registro_bitacora(objeto_afectado);

CREATE INDEX IF NOT EXISTS idx_bitacora_usuario
    ON registro_bitacora(id_usuario);


-- PRODUCTO
CREATE INDEX IF NOT EXISTS idx_producto_categoria
    ON producto(id_categoria);

CREATE INDEX IF NOT EXISTS idx_producto_marca
    ON producto(id_marca);

CREATE INDEX IF NOT EXISTS idx_producto_modelo
    ON producto(id_modelo);

CREATE INDEX IF NOT EXISTS idx_producto_ubicacion
    ON producto(id_ubicacion);

CREATE INDEX IF NOT EXISTS idx_producto_activo
    ON producto(activo);


-- MODELO / UBICACIÓN
CREATE INDEX IF NOT EXISTS idx_modelo_marca
    ON modelo(id_marca);

CREATE INDEX IF NOT EXISTS idx_ubicacion_pasillo_estante
    ON ubicacion(pasillo, estante);


-- COMPATIBILIDAD
CREATE INDEX IF NOT EXISTS idx_compatibilidad_modelo
    ON compatibilidad(id_modelo);


-- EXISTENCIA
CREATE INDEX IF NOT EXISTS idx_existencia_stock
    ON existencia(stock_actual);

CREATE INDEX IF NOT EXISTS idx_existencia_stock_minimo
    ON existencia(stock_minimo);


-- MOVIMIENTO
CREATE INDEX IF NOT EXISTS idx_movimiento_producto_fecha
    ON movimiento_inventario(id_producto, fecha_hora DESC);

CREATE INDEX IF NOT EXISTS idx_movimiento_usuario
    ON movimiento_inventario(id_usuario);

CREATE INDEX IF NOT EXISTS idx_movimiento_tipo
    ON movimiento_inventario(tipo);


-- COMPRA
CREATE INDEX IF NOT EXISTS idx_compra_proveedor
    ON compra(id_proveedor);

CREATE INDEX IF NOT EXISTS idx_compra_usuario
    ON compra(id_usuario);

CREATE INDEX IF NOT EXISTS idx_compra_fecha
    ON compra(fecha DESC);

CREATE INDEX IF NOT EXISTS idx_compra_estado
    ON compra(estado);


-- DETALLE COMPRA
CREATE INDEX IF NOT EXISTS idx_detalle_compra_compra
    ON detalle_compra(id_compra);

CREATE INDEX IF NOT EXISTS idx_detalle_compra_producto
    ON detalle_compra(id_producto);


-- VENTA
CREATE INDEX IF NOT EXISTS idx_venta_cliente
    ON venta(id_cliente);

CREATE INDEX IF NOT EXISTS idx_venta_usuario
    ON venta(id_usuario);

CREATE INDEX IF NOT EXISTS idx_venta_fecha
    ON venta(fecha_hora DESC);

CREATE INDEX IF NOT EXISTS idx_venta_estado
    ON venta(estado);


-- DETALLE VENTA
CREATE INDEX IF NOT EXISTS idx_detalle_venta_venta
    ON detalle_venta(id_venta);

CREATE INDEX IF NOT EXISTS idx_detalle_venta_producto
    ON detalle_venta(id_producto);


-- PAGO
CREATE INDEX IF NOT EXISTS idx_pago_venta
    ON pago(id_venta);

CREATE INDEX IF NOT EXISTS idx_pago_usuario
    ON pago(id_usuario);

CREATE INDEX IF NOT EXISTS idx_pago_fecha
    ON pago(fecha_hora DESC);

CREATE INDEX IF NOT EXISTS idx_pago_metodo
    ON pago(metodo);

CREATE INDEX IF NOT EXISTS idx_pago_estado
    ON pago(estado);


-- COMPROBANTE
CREATE INDEX IF NOT EXISTS idx_comprobante_fecha
    ON comprobante(fecha_emision DESC);


-- SOLICITUD
CREATE INDEX IF NOT EXISTS idx_solicitud_cliente
    ON solicitud_producto(id_cliente);

CREATE INDEX IF NOT EXISTS idx_solicitud_producto
    ON solicitud_producto(id_producto);

CREATE INDEX IF NOT EXISTS idx_solicitud_modelo
    ON solicitud_producto(id_modelo);

CREATE INDEX IF NOT EXISTS idx_solicitud_estado
    ON solicitud_producto(estado);

CREATE INDEX IF NOT EXISTS idx_solicitud_fecha
    ON solicitud_producto(fecha_hora DESC);

--============
-- TRIGGERS
--============


-- ============================================================
-- TRIGGER 1
-- VALIDAR STOCK ANTES DE UNA SALIDA
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_stock_salida()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock numeric(18,4);
    v_stock_disponible numeric(18,4);
BEGIN

    IF NEW.tipo = 'SALIDA' THEN

        SELECT stock_actual
        INTO v_stock
        FROM existencia
        WHERE id_producto = NEW.id_producto
        FOR UPDATE;

        IF v_stock IS NULL THEN
            RAISE EXCEPTION
                'No existe existencia para el producto %',
                NEW.id_producto;
        END IF;


        v_stock_disponible := v_stock;


        -- Si estamos modificando una salida existente,
        -- devolvemos temporalmente su cantidad anterior.
        IF TG_OP = 'UPDATE'
           AND OLD.tipo = 'SALIDA'
           AND OLD.id_producto = NEW.id_producto
        THEN
            v_stock_disponible :=
                v_stock_disponible + OLD.cantidad;
        END IF;


        -- Si estamos cambiando una entrada por una salida,
        -- debemos quitar la entrada anterior.
        IF TG_OP = 'UPDATE'
           AND OLD.tipo = 'ENTRADA'
           AND OLD.id_producto = NEW.id_producto
        THEN
            v_stock_disponible :=
                v_stock_disponible - OLD.cantidad;
        END IF;


        IF NEW.cantidad > v_stock_disponible THEN

            RAISE EXCEPTION
                'Stock insuficiente. Producto: %, stock disponible: %, cantidad solicitada: %',
                NEW.id_producto,
                v_stock_disponible,
                NEW.cantidad;

        END IF;

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_stock_salida
ON movimiento_inventario;


CREATE TRIGGER trg_validar_stock_salida
BEFORE INSERT OR UPDATE OF tipo, cantidad, id_producto
ON movimiento_inventario
FOR EACH ROW
EXECUTE FUNCTION fn_validar_stock_salida();



-- ============================================================
-- TRIGGER 2
-- RECALCULAR EXISTENCIA
-- ============================================================

CREATE OR REPLACE FUNCTION fn_recalcular_existencia_producto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_producto uuid;
    v_stock numeric(18,4);
    v_costo numeric(18,4);
BEGIN

    -- Producto anterior
    IF TG_OP IN ('UPDATE', 'DELETE') THEN

        v_id_producto := OLD.id_producto;


        SELECT COALESCE(
            SUM(
                CASE
                    WHEN tipo = 'ENTRADA'
                        THEN cantidad
                    WHEN tipo = 'SALIDA'
                        THEN -cantidad
                    ELSE 0
                END
            ),
            0
        )
        INTO v_stock
        FROM movimiento_inventario
        WHERE id_producto = v_id_producto;


        SELECT COALESCE(
            SUM(cantidad * costo_unitario)
            / NULLIF(SUM(cantidad), 0),
            0
        )
        INTO v_costo
        FROM movimiento_inventario
        WHERE id_producto = v_id_producto
          AND tipo = 'ENTRADA';


        UPDATE existencia
        SET
            stock_actual = v_stock,
            costo_promedio = v_costo
        WHERE id_producto = v_id_producto;

    END IF;


    -- Producto nuevo
    IF TG_OP IN ('INSERT', 'UPDATE') THEN

        v_id_producto := NEW.id_producto;


        SELECT COALESCE(
            SUM(
                CASE
                    WHEN tipo = 'ENTRADA'
                        THEN cantidad
                    WHEN tipo = 'SALIDA'
                        THEN -cantidad
                    ELSE 0
                END
            ),
            0
        )
        INTO v_stock
        FROM movimiento_inventario
        WHERE id_producto = v_id_producto;


        SELECT COALESCE(
            SUM(cantidad * costo_unitario)
            / NULLIF(SUM(cantidad), 0),
            0
        )
        INTO v_costo
        FROM movimiento_inventario
        WHERE id_producto = v_id_producto
          AND tipo = 'ENTRADA';


        UPDATE existencia
        SET
            stock_actual = v_stock,
            costo_promedio = v_costo
        WHERE id_producto = v_id_producto;

    END IF;


    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;

END;
$$;


DROP TRIGGER IF EXISTS trg_recalcular_existencia
ON movimiento_inventario;


CREATE TRIGGER trg_recalcular_existencia
AFTER INSERT OR UPDATE OR DELETE
ON movimiento_inventario
FOR EACH ROW
EXECUTE FUNCTION fn_recalcular_existencia_producto();



-- ============================================================
-- TRIGGER 3
-- VALIDAR STOCK RESULTANTE
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_stock_resultante()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock numeric(18,4);
    v_id_producto uuid;
BEGIN

    IF TG_OP = 'DELETE' THEN
        v_id_producto := OLD.id_producto;
    ELSE
        v_id_producto := NEW.id_producto;
    END IF;


    SELECT stock_actual
    INTO v_stock
    FROM existencia
    WHERE id_producto = v_id_producto;


    IF v_stock IS NOT NULL AND v_stock < 0 THEN

        RAISE EXCEPTION
            'El stock del producto % no puede ser negativo. Stock resultante: %',
            v_id_producto,
            v_stock;

    END IF;


    RETURN NULL;

END;
$$;


DROP TRIGGER IF EXISTS trg_validar_stock_resultante
ON movimiento_inventario;


CREATE CONSTRAINT TRIGGER trg_validar_stock_resultante
AFTER INSERT OR UPDATE OR DELETE
ON movimiento_inventario
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_validar_stock_resultante();



-- ============================================================
-- TRIGGER 4
-- AUDITAR CAMBIO DE PRECIO
-- ============================================================

CREATE OR REPLACE FUNCTION fn_auditar_cambio_precio_producto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF OLD.precio_venta IS DISTINCT FROM NEW.precio_venta THEN

        INSERT INTO registro_bitacora (
            id_registro,
            fecha_hora,
            accion,
            objeto_afectado,
            resultado,
            direccion_ip,
            id_usuario
        )
        VALUES (
            gen_random_uuid(),
            CURRENT_TIMESTAMP,
            'CAMBIO_PRECIO',
            NEW.id_producto::text,
            'Precio cambiado de '
                || OLD.precio_venta::text
                || ' a '
                || NEW.precio_venta::text,
            NULL,
            NULL
        );

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_auditar_cambio_precio
ON producto;


CREATE TRIGGER trg_auditar_cambio_precio
AFTER UPDATE OF precio_venta
ON producto
FOR EACH ROW
EXECUTE FUNCTION fn_auditar_cambio_precio_producto();



-- ============================================================
-- RECONCILIACIÓN FINAL DE EXISTENCIA
-- ============================================================

UPDATE existencia e
SET
    stock_actual = COALESCE(
        (
            SELECT SUM(
                CASE
                    WHEN mi.tipo = 'ENTRADA'
                        THEN mi.cantidad
                    WHEN mi.tipo = 'SALIDA'
                        THEN -mi.cantidad
                    ELSE 0
                END
            )
            FROM movimiento_inventario mi
            WHERE mi.id_producto = e.id_producto
        ),
        0
    ),

    costo_promedio = COALESCE(
        (
            SELECT
                SUM(mi.cantidad * mi.costo_unitario)
                / NULLIF(SUM(mi.cantidad), 0)
            FROM movimiento_inventario mi
            WHERE mi.id_producto = e.id_producto
              AND mi.tipo = 'ENTRADA'
        ),
        0
    );