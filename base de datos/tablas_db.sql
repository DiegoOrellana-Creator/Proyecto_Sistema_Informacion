-- =============================================================================
-- Electrónica Central AZ — esquema completo (migraciones 001 → 010)
-- =============================================================================
-- =====================================================================
-- PostgreSQL 16 - Esquema: electronica_az
-- Orden de ejecución: 1) este archivo  2) triggers  3) procedimientos
-- =====================================================================
 
BEGIN;
 
CREATE SCHEMA electronica_az;
REVOKE ALL ON SCHEMA electronica_az FROM PUBLIC;
 
-- Seguridad / ROL
 
CREATE TABLE electronica_az.rol (
    id_rol uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    descripcion text,
    CONSTRAINT pk_rol PRIMARY KEY (id_rol),
    CONSTRAINT uq_rol_nombre UNIQUE (nombre)
);
 
-- Seguridad / PERMISO
 
CREATE TABLE electronica_az.permiso (
    id_permiso uuid NOT NULL DEFAULT gen_random_uuid(),
    codigo varchar(120) NOT NULL,
    descripcion text,
    CONSTRAINT pk_permiso PRIMARY KEY (id_permiso),
    CONSTRAINT uq_permiso_codigo UNIQUE (codigo)
);
 
-- Seguridad / USUARIO
 
CREATE TABLE electronica_az.usuario (
    id_usuario uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre_usuario varchar(120) NOT NULL,
    correo varchar(254) NOT NULL,
    hash_contrasena text NOT NULL,
    activo boolean NOT NULL DEFAULT true,
    intentos_fallidos integer NOT NULL DEFAULT 0,          -- NUEVO
    bloqueado_hasta timestamptz,                            -- NUEVO
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_nombre_usuario UNIQUE (nombre_usuario),
    CONSTRAINT uq_usuario_correo UNIQUE (correo),
    CONSTRAINT ck_usuario_correo CHECK (btrim(correo) <> ''),
    CONSTRAINT ck_usuario_nombre CHECK (btrim(nombre_usuario) <> ''),
    CONSTRAINT ck_usuario_hash CHECK (btrim(hash_contrasena) <> ''),
    CONSTRAINT ck_usuario_intentos CHECK (intentos_fallidos >= 0)   -- NUEVO
);
 
CREATE TABLE electronica_az.token_recuperacion (
    id_token uuid NOT NULL DEFAULT gen_random_uuid(),
    id_usuario uuid NOT NULL,
    hash_token text NOT NULL,
    fecha_creacion timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_en timestamptz NOT NULL,
    usado_en timestamptz,
    CONSTRAINT pk_token_recuperacion PRIMARY KEY (id_token),
    CONSTRAINT uq_token_recuperacion_hash UNIQUE (hash_token),
    CONSTRAINT ck_token_recuperacion_expira CHECK (expira_en > fecha_creacion)
);
 
-- Seguridad / USUARIO_ROL
 
CREATE TABLE electronica_az.usuario_rol (
    id_usuario uuid NOT NULL,
    id_rol uuid NOT NULL,
    CONSTRAINT pk_usuario_rol PRIMARY KEY (id_usuario, id_rol)
);
 
-- Seguridad / ROL_PERMISO
 
CREATE TABLE electronica_az.rol_permiso (
    id_rol uuid NOT NULL,
    id_permiso uuid NOT NULL,
    CONSTRAINT pk_rol_permiso PRIMARY KEY (id_rol, id_permiso)
);
 
-- Seguridad / CLIENTE
 
CREATE TABLE electronica_az.cliente (
    id_cliente uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    documento varchar(120),
    telefono varchar(120),
    correo varchar(254),
    id_usuario uuid,
    CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
    CONSTRAINT uq_cliente_id_usuario UNIQUE (id_usuario)
);
 
-- Seguridad / REGISTRO_BITACORA
 
CREATE TABLE electronica_az.registro_bitacora (
    id_registro uuid NOT NULL DEFAULT gen_random_uuid(),
    fecha_hora timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    accion varchar(120) NOT NULL,
    objeto_afectado text NOT NULL,
    resultado text NOT NULL,
    direccion_ip inet,
    id_usuario uuid,
    CONSTRAINT pk_registro_bitacora PRIMARY KEY (id_registro)
);
 
-- Catalogo / CATEGORIA
 
CREATE TABLE electronica_az.categoria (
    id_categoria uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    descripcion text,
    activo boolean NOT NULL DEFAULT true,                   -- NUEVO
    id_categoria_padre uuid,                                -- NUEVO
    CONSTRAINT pk_categoria PRIMARY KEY (id_categoria),
    CONSTRAINT uq_categoria_nombre UNIQUE (nombre),         -- NUEVO
    CONSTRAINT ck_categoria_padre CHECK (id_categoria_padre IS NULL
                                         OR id_categoria_padre <> id_categoria)  -- NUEVO
);
 
-- Catalogo / MARCA
 
CREATE TABLE electronica_az.marca (
    id_marca uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    CONSTRAINT pk_marca PRIMARY KEY (id_marca),
    CONSTRAINT uq_marca_nombre UNIQUE (nombre)              -- NUEVO
);
 
-- Catalogo / MODELO
 
CREATE TABLE electronica_az.modelo (
    id_modelo uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    descripcion text,
    id_marca uuid NOT NULL,
    CONSTRAINT pk_modelo PRIMARY KEY (id_modelo),
    CONSTRAINT uq_modelo_marca_nombre UNIQUE (id_marca, nombre)   -- NUEVO
);
 
-- Catalogo / UNIDAD_MEDIDA
 
CREATE TABLE electronica_az.unidad_medida (
    id_unidad_medida uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre varchar(120) NOT NULL,
    simbolo varchar(120) NOT NULL,
    permite_fraccion boolean NOT NULL DEFAULT false,
    activo boolean NOT NULL DEFAULT true,                   -- NUEVO
    CONSTRAINT pk_unidad_medida PRIMARY KEY (id_unidad_medida),
    CONSTRAINT uq_unidad_medida_nombre UNIQUE (nombre),     -- NUEVO
    CONSTRAINT uq_unidad_medida_simbolo UNIQUE (simbolo)    -- NUEVO
);
 
-- Catalogo / UBICACION
 
CREATE TABLE electronica_az.ubicacion (
    id_ubicacion uuid NOT NULL DEFAULT gen_random_uuid(),
    codigo varchar(120) NOT NULL,
    pasillo varchar(120) NOT NULL,
    estante varchar(120) NOT NULL,
    CONSTRAINT pk_ubicacion PRIMARY KEY (id_ubicacion),
    CONSTRAINT uq_ubicacion_codigo UNIQUE (codigo)          -- NUEVO
);
 
-- Catalogo / PRODUCTO
 
CREATE TABLE electronica_az.producto (
    id_producto uuid NOT NULL DEFAULT gen_random_uuid(),
    codigo varchar(120) NOT NULL,
    nombre varchar(120) NOT NULL,
    descripcion text,
    precio_venta numeric(18,4) NOT NULL,
    activo boolean NOT NULL DEFAULT true,
    id_categoria uuid NOT NULL,
    id_unidad_medida uuid NOT NULL,
    id_ubicacion uuid,                                      -- CAMBIO: antes NOT NULL
    id_marca uuid,
    id_modelo uuid,
    CONSTRAINT pk_producto PRIMARY KEY (id_producto),
    CONSTRAINT uq_producto_codigo UNIQUE (codigo),
    CONSTRAINT ck_producto_precio_venta CHECK (precio_venta >= 0 AND precio_venta <> 'NaN'::numeric)
);
 
-- Catalogo / COMPATIBILIDAD
 
CREATE TABLE electronica_az.compatibilidad (
    id_producto uuid NOT NULL,
    id_modelo uuid NOT NULL,
    observaciones text,
    CONSTRAINT pk_compatibilidad PRIMARY KEY (id_producto, id_modelo)
);
 
-- Inventario / EXISTENCIA
 
CREATE TABLE electronica_az.existencia (
    id_producto uuid NOT NULL,
    stock_actual numeric(18,4) NOT NULL DEFAULT 0,
    stock_minimo numeric(18,4) NOT NULL DEFAULT 0,
    costo_promedio numeric(18,4) NOT NULL DEFAULT 0,
    CONSTRAINT pk_existencia PRIMARY KEY (id_producto),
    CONSTRAINT ck_existencia_stock_actual CHECK (stock_actual >= 0 AND stock_actual <> 'NaN'::numeric),
    CONSTRAINT ck_existencia_stock_minimo CHECK (stock_minimo >= 0 AND stock_minimo <> 'NaN'::numeric),
    CONSTRAINT ck_existencia_costo_promedio CHECK (costo_promedio >= 0 AND costo_promedio <> 'NaN'::numeric)
);
 
-- Inventario / MOVIMIENTO_INVENTARIO
 
CREATE TABLE electronica_az.movimiento_inventario (
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
    CONSTRAINT pk_movimiento_inventario PRIMARY KEY (id_movimiento),
    CONSTRAINT ck_movimiento_inventario_cantidad CHECK (cantidad > 0 AND cantidad <> 'NaN'::numeric),
    CONSTRAINT ck_movimiento_inventario_costo_unitario CHECK (costo_unitario >= 0 AND costo_unitario <> 'NaN'::numeric),
    CONSTRAINT ck_movimiento_tipo CHECK (tipo IN ('ENTRADA', 'SALIDA')),
    CONSTRAINT ck_movimiento_origen CHECK (id_detalle_compra IS NULL OR id_detalle_venta IS NULL)
);
 
-- Compras / PROVEEDOR
 
CREATE TABLE electronica_az.proveedor (
    id_proveedor uuid NOT NULL DEFAULT gen_random_uuid(),
    razon_social varchar(120) NOT NULL,
    documento varchar(120),
    telefono varchar(120),
    correo varchar(254),
    direccion varchar(300),
    activo boolean NOT NULL DEFAULT true,
    CONSTRAINT pk_proveedor PRIMARY KEY (id_proveedor)
);
 
-- Compras / COMPRA
 
CREATE TABLE electronica_az.compra (
    id_compra uuid NOT NULL DEFAULT gen_random_uuid(),
    fecha timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado varchar(120) NOT NULL DEFAULT 'PENDIENTE',
    id_proveedor uuid NOT NULL,
    id_usuario uuid NOT NULL,
    CONSTRAINT pk_compra PRIMARY KEY (id_compra),
    CONSTRAINT ck_compra_estado CHECK (estado IN ('PENDIENTE', 'RECIBIDA', 'CANCELADA'))
);
 
-- Compras / DETALLE_COMPRA
 
CREATE TABLE electronica_az.detalle_compra (
    id_detalle_compra uuid NOT NULL DEFAULT gen_random_uuid(),
    id_compra uuid NOT NULL,
    id_producto uuid NOT NULL,
    cantidad numeric(18,4) NOT NULL,
    costo_unitario numeric(18,4) NOT NULL,
    CONSTRAINT pk_detalle_compra PRIMARY KEY (id_detalle_compra),
    CONSTRAINT ck_detalle_compra_cantidad CHECK (cantidad > 0 AND cantidad <> 'NaN'::numeric),
    CONSTRAINT ck_detalle_compra_costo_unitario CHECK (costo_unitario >= 0 AND costo_unitario <> 'NaN'::numeric)
);
 
-- Ventas / VENTA
 
CREATE TABLE electronica_az.venta (
    id_venta uuid NOT NULL DEFAULT gen_random_uuid(),
    fecha_hora timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado varchar(120) NOT NULL DEFAULT 'BORRADOR',
    id_cliente uuid NOT NULL,
    id_usuario uuid NOT NULL,
    CONSTRAINT pk_venta PRIMARY KEY (id_venta),
    CONSTRAINT ck_venta_estado CHECK (estado IN ('BORRADOR', 'CONFIRMADA', 'ANULADA'))
);
 
-- Ventas / DETALLE_VENTA
 
CREATE TABLE electronica_az.detalle_venta (
    id_detalle_venta uuid NOT NULL DEFAULT gen_random_uuid(),
    id_venta uuid NOT NULL,
    id_producto uuid NOT NULL,
    cantidad numeric(18,4) NOT NULL,
    precio_unitario numeric(18,4) NOT NULL,
    costo_unitario_historico numeric(18,4) NOT NULL,
    CONSTRAINT pk_detalle_venta PRIMARY KEY (id_detalle_venta),
    CONSTRAINT ck_detalle_venta_cantidad CHECK (cantidad > 0 AND cantidad <> 'NaN'::numeric),
    CONSTRAINT ck_detalle_venta_precio_unitario CHECK (precio_unitario >= 0 AND precio_unitario <> 'NaN'::numeric),
    CONSTRAINT ck_detalle_venta_costo_unitario_historico CHECK (costo_unitario_historico >= 0 AND costo_unitario_historico <> 'NaN'::numeric)
);
 
-- Ventas / PAGO
 
CREATE TABLE electronica_az.pago (
    id_pago uuid NOT NULL DEFAULT gen_random_uuid(),
    fecha_hora timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto numeric(18,2) NOT NULL,
    metodo varchar(120) NOT NULL,
    estado varchar(120) NOT NULL DEFAULT 'PENDIENTE',
    referencia_externa varchar(200),
    id_venta uuid NOT NULL,
    id_usuario uuid NOT NULL,
    CONSTRAINT pk_pago PRIMARY KEY (id_pago),
    CONSTRAINT uq_pago_referencia_externa UNIQUE (referencia_externa),
    CONSTRAINT ck_pago_monto CHECK (monto > 0 AND monto <> 'NaN'::numeric),
    CONSTRAINT ck_pago_estado CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'RECHAZADO')),
    CONSTRAINT ck_pago_metodo CHECK (metodo IN ('EFECTIVO', 'QR'))
);
 
-- Ventas / COMPROBANTE
 
CREATE TABLE electronica_az.comprobante (
    id_venta uuid NOT NULL,
    numero varchar(120) NOT NULL,
    fecha_emision timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_comprobante PRIMARY KEY (id_venta),
    CONSTRAINT uq_comprobante_numero UNIQUE (numero)
);
 
-- Solicitudes / SOLICITUD_PRODUCTO
 
CREATE TABLE electronica_az.solicitud_producto (
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
    CONSTRAINT pk_solicitud_producto PRIMARY KEY (id_solicitud),
    CONSTRAINT ck_solicitud_producto_cantidad CHECK (cantidad > 0 AND cantidad <> 'NaN'::numeric),
    CONSTRAINT ck_solicitud_producto_estado CHECK (estado IN ('PENDIENTE', 'ATENDIDA', 'CANCELADA'))
);
 
-- CLAVES FORANEAS
 
-- Se agregan despues de todas las tablas para resolver referencias adelantadas.
 
-- RESTRICT protege el historial; no se borran ventas, compras ni movimientos en cascada.
 
ALTER TABLE electronica_az.usuario_rol
    ADD CONSTRAINT fk_usuario_rol_id_usuario
    FOREIGN KEY (id_usuario) REFERENCES electronica_az.usuario (id_usuario)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.usuario_rol
    ADD CONSTRAINT fk_usuario_rol_id_rol
    FOREIGN KEY (id_rol) REFERENCES electronica_az.rol (id_rol)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.rol_permiso
    ADD CONSTRAINT fk_rol_permiso_id_rol
    FOREIGN KEY (id_rol) REFERENCES electronica_az.rol (id_rol)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.rol_permiso
    ADD CONSTRAINT fk_rol_permiso_id_permiso
    FOREIGN KEY (id_permiso) REFERENCES electronica_az.permiso (id_permiso)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.cliente
    ADD CONSTRAINT fk_cliente_id_usuario
    FOREIGN KEY (id_usuario) REFERENCES electronica_az.usuario (id_usuario)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.registro_bitacora
    ADD CONSTRAINT fk_registro_bitacora_id_usuario
    FOREIGN KEY (id_usuario) REFERENCES electronica_az.usuario (id_usuario)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.modelo
    ADD CONSTRAINT fk_modelo_id_marca
    FOREIGN KEY (id_marca) REFERENCES electronica_az.marca (id_marca)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.producto
    ADD CONSTRAINT fk_producto_id_categoria
    FOREIGN KEY (id_categoria) REFERENCES electronica_az.categoria (id_categoria)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.producto
    ADD CONSTRAINT fk_producto_id_unidad_medida
    FOREIGN KEY (id_unidad_medida) REFERENCES electronica_az.unidad_medida (id_unidad_medida)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.producto
    ADD CONSTRAINT fk_producto_id_ubicacion
    FOREIGN KEY (id_ubicacion) REFERENCES electronica_az.ubicacion (id_ubicacion)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.producto
    ADD CONSTRAINT fk_producto_id_marca
    FOREIGN KEY (id_marca) REFERENCES electronica_az.marca (id_marca)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.producto
    ADD CONSTRAINT fk_producto_id_modelo
    FOREIGN KEY (id_modelo) REFERENCES electronica_az.modelo (id_modelo)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.compatibilidad
    ADD CONSTRAINT fk_compatibilidad_id_producto
    FOREIGN KEY (id_producto) REFERENCES electronica_az.producto (id_producto)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.compatibilidad
    ADD CONSTRAINT fk_compatibilidad_id_modelo
    FOREIGN KEY (id_modelo) REFERENCES electronica_az.modelo (id_modelo)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.existencia
    ADD CONSTRAINT fk_existencia_id_producto
    FOREIGN KEY (id_producto) REFERENCES electronica_az.producto (id_producto)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.movimiento_inventario
    ADD CONSTRAINT fk_movimiento_inventario_id_producto
    FOREIGN KEY (id_producto) REFERENCES electronica_az.existencia (id_producto)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.movimiento_inventario
    ADD CONSTRAINT fk_movimiento_inventario_id_usuario
    FOREIGN KEY (id_usuario) REFERENCES electronica_az.usuario (id_usuario)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.movimiento_inventario
    ADD CONSTRAINT fk_movimiento_inventario_id_detalle_compra
    FOREIGN KEY (id_detalle_compra) REFERENCES electronica_az.detalle_compra (id_detalle_compra)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.movimiento_inventario
    ADD CONSTRAINT fk_movimiento_inventario_id_detalle_venta
    FOREIGN KEY (id_detalle_venta) REFERENCES electronica_az.detalle_venta (id_detalle_venta)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.compra
    ADD CONSTRAINT fk_compra_id_proveedor
    FOREIGN KEY (id_proveedor) REFERENCES electronica_az.proveedor (id_proveedor)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.compra
    ADD CONSTRAINT fk_compra_id_usuario
    FOREIGN KEY (id_usuario) REFERENCES electronica_az.usuario (id_usuario)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.detalle_compra
    ADD CONSTRAINT fk_detalle_compra_id_compra
    FOREIGN KEY (id_compra) REFERENCES electronica_az.compra (id_compra)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.detalle_compra
    ADD CONSTRAINT fk_detalle_compra_id_producto
    FOREIGN KEY (id_producto) REFERENCES electronica_az.producto (id_producto)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.venta
    ADD CONSTRAINT fk_venta_id_cliente
    FOREIGN KEY (id_cliente) REFERENCES electronica_az.cliente (id_cliente)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.venta
    ADD CONSTRAINT fk_venta_id_usuario
    FOREIGN KEY (id_usuario) REFERENCES electronica_az.usuario (id_usuario)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.detalle_venta
    ADD CONSTRAINT fk_detalle_venta_id_venta
    FOREIGN KEY (id_venta) REFERENCES electronica_az.venta (id_venta)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.detalle_venta
    ADD CONSTRAINT fk_detalle_venta_id_producto
    FOREIGN KEY (id_producto) REFERENCES electronica_az.producto (id_producto)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.pago
    ADD CONSTRAINT fk_pago_id_venta
    FOREIGN KEY (id_venta) REFERENCES electronica_az.venta (id_venta)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.pago
    ADD CONSTRAINT fk_pago_id_usuario
    FOREIGN KEY (id_usuario) REFERENCES electronica_az.usuario (id_usuario)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.comprobante
    ADD CONSTRAINT fk_comprobante_id_venta
    FOREIGN KEY (id_venta) REFERENCES electronica_az.venta (id_venta)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.solicitud_producto
    ADD CONSTRAINT fk_solicitud_producto_id_cliente
    FOREIGN KEY (id_cliente) REFERENCES electronica_az.cliente (id_cliente)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.solicitud_producto
    ADD CONSTRAINT fk_solicitud_producto_id_usuario
    FOREIGN KEY (id_usuario) REFERENCES electronica_az.usuario (id_usuario)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.solicitud_producto
    ADD CONSTRAINT fk_solicitud_producto_id_producto
    FOREIGN KEY (id_producto) REFERENCES electronica_az.producto (id_producto)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.solicitud_producto
    ADD CONSTRAINT fk_solicitud_producto_id_modelo
    FOREIGN KEY (id_modelo) REFERENCES electronica_az.modelo (id_modelo)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
-- INDICES DE APOYO PARA FK
 
-- Las PK y UNIQUE ya crean sus propios indices.
 
CREATE INDEX ix_usuario_rol_id_rol ON electronica_az.usuario_rol (id_rol);
 
CREATE INDEX ix_rol_permiso_id_permiso ON electronica_az.rol_permiso (id_permiso);
 
CREATE INDEX ix_registro_bitacora_id_usuario ON electronica_az.registro_bitacora (id_usuario);
 
CREATE INDEX ix_modelo_id_marca ON electronica_az.modelo (id_marca);
 
CREATE INDEX ix_producto_id_categoria ON electronica_az.producto (id_categoria);
 
CREATE INDEX ix_producto_id_unidad_medida ON electronica_az.producto (id_unidad_medida);
 
CREATE INDEX ix_producto_id_ubicacion ON electronica_az.producto (id_ubicacion);
 
CREATE INDEX ix_producto_id_marca ON electronica_az.producto (id_marca);
 
CREATE INDEX ix_producto_id_modelo ON electronica_az.producto (id_modelo);
 
CREATE INDEX ix_compatibilidad_id_modelo ON electronica_az.compatibilidad (id_modelo);
 
CREATE INDEX ix_movimiento_inventario_id_producto ON electronica_az.movimiento_inventario (id_producto);
 
CREATE INDEX ix_movimiento_inventario_id_usuario ON electronica_az.movimiento_inventario (id_usuario);
 
CREATE INDEX ix_movimiento_inventario_id_detalle_compra ON electronica_az.movimiento_inventario (id_detalle_compra);
 
CREATE INDEX ix_movimiento_inventario_id_detalle_venta ON electronica_az.movimiento_inventario (id_detalle_venta);
 
CREATE INDEX ix_compra_id_proveedor ON electronica_az.compra (id_proveedor);
 
CREATE INDEX ix_compra_id_usuario ON electronica_az.compra (id_usuario);
 
CREATE INDEX ix_detalle_compra_id_compra ON electronica_az.detalle_compra (id_compra);
 
CREATE INDEX ix_detalle_compra_id_producto ON electronica_az.detalle_compra (id_producto);
 
CREATE INDEX ix_venta_id_cliente ON electronica_az.venta (id_cliente);
 
CREATE INDEX ix_venta_id_usuario ON electronica_az.venta (id_usuario);
 
CREATE INDEX ix_detalle_venta_id_venta ON electronica_az.detalle_venta (id_venta);
 
CREATE INDEX ix_detalle_venta_id_producto ON electronica_az.detalle_venta (id_producto);
 
CREATE INDEX ix_pago_id_venta ON electronica_az.pago (id_venta);
 
CREATE INDEX ix_pago_id_usuario ON electronica_az.pago (id_usuario);
 
CREATE INDEX ix_solicitud_producto_id_cliente ON electronica_az.solicitud_producto (id_cliente);
 
CREATE INDEX ix_solicitud_producto_id_usuario ON electronica_az.solicitud_producto (id_usuario);
 
CREATE INDEX ix_solicitud_producto_id_producto ON electronica_az.solicitud_producto (id_producto);
 
CREATE INDEX ix_solicitud_producto_id_modelo ON electronica_az.solicitud_producto (id_modelo);
 
-- Historiales y filtros habituales.
 
CREATE INDEX ix_venta_fecha_hora ON electronica_az.venta (fecha_hora);
 
CREATE INDEX ix_compra_fecha ON electronica_az.compra (fecha);
 
CREATE INDEX ix_movimiento_producto_fecha ON electronica_az.movimiento_inventario (id_producto, fecha_hora);
 
CREATE INDEX ix_bitacora_fecha_hora ON electronica_az.registro_bitacora (fecha_hora);
 
CREATE INDEX ix_solicitud_estado_fecha ON electronica_az.solicitud_producto (estado, fecha_hora);
 
-- Comentarios del modelo.
 
COMMENT ON SCHEMA electronica_az IS 'Electronica Central AZ: tablas del modelo original, importes en BOB';
 
COMMENT ON COLUMN electronica_az.usuario.hash_contrasena IS 'Hash generado por el backend; nunca una contrasena en texto plano';
 
COMMENT ON COLUMN electronica_az.existencia.id_producto IS 'PK/FK compartida: una existencia por producto';
 
COMMENT ON COLUMN electronica_az.comprobante.id_venta IS 'PK/FK compartida: como maximo un comprobante por venta';
 
COMMENT ON COLUMN electronica_az.detalle_venta.costo_unitario_historico IS 'Costo promedio en BOB copiado al confirmar la venta; no recalcular con costos actuales';
 
COMMENT ON COLUMN electronica_az.pago.referencia_externa IS 'Referencia opcional de comprobacion manual; no implica conexion con pasarela';
 
COMMENT ON COLUMN electronica_az.solicitud_producto.id_producto IS 'Opcional: se puede solicitar un producto aun no incorporado al catalogo';
 
COMMENT ON TABLE electronica_az.compatibilidad IS 'Relacion del producto con modelos compatibles; pareja unica por PK compuesta';
 
-- CLAVES FORANEAS NUEVAS  (agregar en la seccion "CLAVES FORANEAS")
 
-- =====================================================================
 
ALTER TABLE electronica_az.categoria
    ADD CONSTRAINT fk_categoria_id_categoria_padre
    FOREIGN KEY (id_categoria_padre) REFERENCES electronica_az.categoria (id_categoria)
    ON UPDATE RESTRICT ON DELETE RESTRICT;
 
ALTER TABLE electronica_az.token_recuperacion
    ADD CONSTRAINT fk_token_recuperacion_id_usuario
    FOREIGN KEY (id_usuario) REFERENCES electronica_az.usuario (id_usuario)
    ON UPDATE RESTRICT ON DELETE CASCADE;
 
-- =====================================================================
 
-- INDICES NUEVOS  (agregar en la seccion "INDICES DE APOYO PARA FK")
 
-- =====================================================================
 
CREATE INDEX ix_categoria_id_categoria_padre ON electronica_az.categoria (id_categoria_padre);
 
CREATE INDEX ix_token_recuperacion_id_usuario ON electronica_az.token_recuperacion (id_usuario);
 
-- ix_modelo_id_marca ya no hace falta: lo cubre uq_modelo_marca_nombre (id_marca, nombre).
 
-- =====================================================================
 
-- COMENTARIOS  (agregar al final, antes de COMMIT)
 
-- =====================================================================
 
COMMENT ON COLUMN electronica_az.usuario.bloqueado_hasta IS 'Fin del bloqueo tras 3 intentos fallidos (3 minutos); NULL = sin bloqueo';
 
COMMENT ON COLUMN electronica_az.categoria.id_categoria_padre IS 'Opcional: categoria padre para formar subcategorias';
 
COMMENT ON COLUMN electronica_az.producto.id_ubicacion IS 'Opcional: se asigna con CU-21 Gestionar ubicaciones (Ciclo 2)';
 
COMMENT ON TABLE electronica_az.token_recuperacion IS 'Enlaces de recuperacion de contrasena (CU-22); se guarda solo el hash del token';
 
COMMIT;
 
Claude terminó la respuesta

-- =============================================================================

