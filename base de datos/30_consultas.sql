-- =====================================================================


--                  CONSULTAS SIMPLES

-- 1: Listado de clientes ordenados alfabéticamente (CU14)
SELECT nombre, documento, telefono, correo
FROM cliente
ORDER BY nombre ASC;
-- Propósito: Permite a atención al cliente y facturación ubicar rápidamente
--   a un cliente ya registrado (por nombre) para evitar crear duplicados
--   al momento de generar una venta.


-- 2: Productos activos habilitados para la venta (CU4, CU10)
SELECT codigo, nombre, precio_venta, activo
FROM producto
WHERE activo = true
ORDER BY nombre ASC;
-- Propósito: El encargado de inventario usa esta consulta para verificar
--   qué productos están habilitados para mostrarse en el punto de venta,
--   evitando que artículos descontinuados aparezcan en el catálogo.


-- 3: Categorías de productos registradas (CU5)
SELECT nombre, descripcion
FROM categoria
ORDER BY nombre ASC;
-- Propósito: Da una vista consolidada de las categorías existentes en el
--   catálogo (por ejemplo, repuestos, accesorios, consumibles), útil para
--   la gerencia al momento de crear nuevos productos o auditar el catálogo.


-- 4: Bitácora de auditoría de los últimos 7 días (CU3)
SELECT accion, objeto_afectado, resultado, direccion_ip, fecha_hora
FROM registro_bitacora
WHERE fecha_hora >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY fecha_hora DESC;
-- Propósito: Los administradores revisan esta bitácora para detectar
--   actividad inusual reciente en el sistema y mantener trazabilidad de
--   acciones críticas como control interno contra manipulaciones no autorizadas.


-- 5: Proveedores activos registrados (CU12)
SELECT razon_social, documento, telefono, correo, direccion
FROM proveedor
WHERE activo = true
ORDER BY razon_social ASC;
-- Propósito: El área de compras mantiene un directorio actualizado de
--   proveedores vigentes para agilizar cotizaciones, órdenes de compra
--   y seguimiento de pedidos de mercadería.


--                  CONSULTAS DOBLES

-- 6: Catálogo de productos con su marca (CU4, CU6, CU10)
SELECT p.nombre AS producto, m.nombre AS marca, p.precio_venta, p.activo
FROM producto p
JOIN marca m ON p.id_marca = m.id_marca
ORDER BY m.nombre, p.nombre;
-- Propósito: Relaciona cada producto con su marca para dar al personal
--   de ventas una vista unificada del catálogo, útil cuando un cliente
--   busca una marca en específico. Solo incluye productos con marca asignada.


-- 7: Existencias frente a stock mínimo por producto (CU11)
SELECT p.codigo, p.nombre, e.stock_actual, e.stock_minimo
FROM producto p
JOIN existencia e ON p.id_producto = e.id_producto
ORDER BY e.stock_actual ASC;
-- Propósito: El personal de almacén compara constantemente el stock actual
--   contra el stock mínimo definido, para identificar rápidamente qué
--   productos requieren reposición urgente.


-- 8: Modelos agrupados por marca (CU6, CU7)
SELECT mo.nombre AS modelo, ma.nombre AS marca, mo.descripcion
FROM modelo mo
JOIN marca ma ON mo.id_marca = ma.id_marca
ORDER BY ma.nombre, mo.nombre;
-- Propósito: Permite a ventas y compras conocer qué modelos existen
--   registrados por cada marca, base para gestionar la compatibilidad
--   de productos y evaluar qué líneas de marca ampliar en el catálogo.


-- 9: Historial de compras por proveedor (CU12, CU13)
SELECT c.id_compra, pr.razon_social, c.fecha, c.estado
FROM compra c
JOIN proveedor pr ON c.id_proveedor = pr.id_proveedor
ORDER BY c.fecha DESC;
-- Propósito: La gerencia y abastecimiento revisan el historial cronológico
--   de compras por proveedor, útil para conciliar pagos y evaluar con
--   qué proveedores existe mayor frecuencia de operaciones comerciales.


-- 10: Ubicación física de cada producto en almacén (CU4, CU11)
SELECT p.codigo, p.nombre, u.codigo AS ubicacion, u.pasillo, u.estante
FROM producto p
JOIN ubicacion u ON p.id_ubicacion = u.id_ubicacion
ORDER BY u.pasillo, u.estante;
-- Propósito: El personal de bodega usa este listado para saber exactamente
--   en qué pasillo y estante se encuentra cada producto, agilizando el
--   picking al momento de despachar o reabastecer.


--               CONSULTAS MÚLTIPLES

-- 11: Ventas con cliente y usuario vendedor (CU15, CU14)
SELECT v.id_venta, v.fecha_hora, v.estado, c.nombre AS cliente, u.nombre_usuario AS vendedor
FROM venta v
JOIN cliente c ON v.id_cliente = c.id_cliente
JOIN usuario u ON v.id_usuario = u.id_usuario
ORDER BY v.fecha_hora DESC;
-- Propósito: Cruza cada venta con el cliente que la realizó y el usuario
--   que la registró, dando un panorama completo de la transacción, útil
--   para el cierre de caja diario y para medir desempeño por vendedor.


-- 12: Detalle de compras con proveedor y producto (CU13, CU12)
SELECT c.id_compra, pr.razon_social AS proveedor, p.nombre AS producto,
       dc.cantidad, dc.costo_unitario
FROM compra c
JOIN proveedor pr ON c.id_proveedor = pr.id_proveedor
JOIN detalle_compra dc ON c.id_compra = dc.id_compra
JOIN producto p ON dc.id_producto = p.id_producto
ORDER BY c.fecha DESC;
-- Propósito: Desglosa cada compra mostrando qué productos se adquirieron,
--   a qué costo unitario y de qué proveedor. Es vital para auditorías de
--   almacén, verificando qué ingresó en cada lote y a qué costo.


-- 13: Kardex — movimientos de inventario con producto y responsable (CU11)
SELECT mi.fecha_hora, mi.tipo, mi.motivo, u.nombre_usuario AS responsable,
       p.nombre AS producto, mi.cantidad
FROM movimiento_inventario mi
JOIN existencia e ON mi.id_producto = e.id_producto
JOIN producto p ON e.id_producto = p.id_producto
JOIN usuario u ON mi.id_usuario = u.id_usuario
ORDER BY mi.fecha_hora DESC;
-- Propósito: Es el corazón del control de inventario (Kardex). Integra
--   cada movimiento con el producto afectado y el usuario responsable,
--   garantizando trazabilidad ante pérdidas o descuadres de stock.
-- Nota: el FK de movimiento_inventario apunta a existencia(id_producto),
--   por eso se pasa por esa tabla antes de llegar a producto.


-- 14: Jerarquía de catálogo — categoría, marca, modelo y producto (CU4, CU5, CU6, CU7)
SELECT cat.nombre AS categoria, ma.nombre AS marca, mo.nombre AS modelo,
       p.nombre AS producto, p.precio_venta
FROM producto p
JOIN categoria cat ON p.id_categoria = cat.id_categoria
LEFT JOIN marca ma ON p.id_marca = ma.id_marca
LEFT JOIN modelo mo ON p.id_modelo = mo.id_modelo
ORDER BY cat.nombre, p.nombre;
-- Propósito: Genera una vista panorámica de todo el catálogo, desde la
--   categoría hasta el modelo específico. Se usa para exportar listas de
--   precios estructuradas o actualizar catálogos externos.
-- Nota: LEFT JOIN porque marca y modelo son opcionales en producto.


-- 15: Compatibilidad de productos por modelo y marca (CU9)
SELECT p.nombre AS producto, mo.nombre AS modelo, ma.nombre AS marca,
       comp.observaciones
FROM compatibilidad comp
JOIN producto p ON comp.id_producto = p.id_producto
JOIN modelo mo ON comp.id_modelo = mo.id_modelo
JOIN marca ma ON mo.id_marca = ma.id_marca
ORDER BY ma.nombre, mo.nombre;
-- Propósito: El área de ventas consulta esta relación para confirmar de
--   inmediato con qué modelos y marcas es compatible un producto/repuesto,
--   evitando vender un artículo incorrecto al cliente.


-- 16: Detalle de línea de venta con cliente y producto (CU15, CU14)
SELECT v.id_venta, c.nombre AS cliente, p.nombre AS producto,
       dv.cantidad, dv.precio_unitario
FROM venta v
JOIN cliente c ON v.id_cliente = c.id_cliente
JOIN detalle_venta dv ON v.id_venta = dv.id_venta
JOIN producto p ON dv.id_producto = p.id_producto
ORDER BY v.fecha_hora DESC;
-- Propósito: Muestra cada línea/artículo vendido junto al cliente que lo
--   compró. Sirve como hoja de detalle para revisar qué se despachó en
--   cada venta, útil ante reclamos o devoluciones.


-- 17: Matriz de seguridad — permisos asignados por rol (CU2)
SELECT r.nombre AS rol, pe.codigo AS permiso, pe.descripcion
FROM rol r
JOIN rol_permiso rp ON r.id_rol = rp.id_rol
JOIN permiso pe ON rp.id_permiso = pe.id_permiso
ORDER BY r.nombre, pe.codigo;
-- Propósito: Construye la matriz de seguridad que lista todos los permisos
--   habilitados por rol. El administrador técnico la usa para diagnosticar
--   problemas de acceso y confirmar que las políticas de seguridad se cumplen.


-- 18: Auditoría de ventas anuladas (CU15, CU3)
SELECT v.id_venta, c.nombre AS cliente, rb.fecha_hora AS fecha_anulacion,
       u.nombre_usuario AS anulado_por, rb.resultado
FROM venta v
JOIN cliente c ON v.id_cliente = c.id_cliente
JOIN registro_bitacora rb
     ON rb.objeto_afectado = v.id_venta::text
    AND rb.accion = 'ANULAR_VENTA'
LEFT JOIN usuario u ON rb.id_usuario = u.id_usuario
WHERE v.estado = 'ANULADA'
ORDER BY rb.fecha_hora DESC;
-- Propósito: Audita las ventas que fueron revertidas, mostrando quién
--   ejecutó la anulación y cuándo, previniendo fraudes o cancelaciones
--   no autorizadas.
-- Nota importante: la tabla venta NO tiene columnas propias de anulación
--   (fecha/motivo/usuario), así que este reporte se apoya en registro_bitacora
--   guardando el id_venta como texto en "objeto_afectado" y un valor de
--   convención en "accion" (aquí 'ANULAR_VENTA'). Ajusta ese valor al que
--   realmente registre tu aplicación, o mejor aún, agrega columnas
--   fecha_anulacion / id_usuario_anulacion / motivo_anulacion a "venta"
--   si necesitas este reporte de forma confiable.


-- 19: Solicitudes de producto por cliente con atención de usuario (CU17, CU14)
SELECT s.id_solicitud, c.nombre AS cliente, s.descripcion_producto,
       p.nombre AS producto_sugerido, mo.nombre AS modelo_sugerido,
       s.estado, u.nombre_usuario AS atendido_por
FROM solicitud_producto s
JOIN cliente c ON s.id_cliente = c.id_cliente
JOIN usuario u ON s.id_usuario = u.id_usuario
LEFT JOIN producto p ON s.id_producto = p.id_producto
LEFT JOIN modelo mo ON s.id_modelo = mo.id_modelo
ORDER BY s.fecha_hora DESC;
-- Propósito: Consolida los pedidos especiales o solicitudes de productos
--   no disponibles, cruzando quién los pidió, qué usuario los atendió y a
--   qué producto/modelo se asociaron finalmente (si aplica).


-- 20: Comprobantes emitidos con cliente y total pagado (CU16, CU18)
SELECT co.numero, co.fecha_emision, cl.nombre AS cliente, v.estado,
       SUM(pg.monto) AS total_pagado
FROM comprobante co
JOIN venta v ON co.id_venta = v.id_venta
JOIN cliente cl ON v.id_cliente = cl.id_cliente
JOIN pago pg ON v.id_venta = pg.id_venta
GROUP BY co.numero, co.fecha_emision, cl.nombre, v.estado
ORDER BY co.fecha_emision DESC;
-- Propósito: Une el comprobante fiscal con la venta, el cliente y la suma
--   de todos los pagos asociados (una venta puede tener más de un pago).
--   Es la base para el cierre de caja y la conciliación contable diaria.


--                       SUBCONSULTAS

-- 21: Clientes registrados sin compras realizadas (CU14)
SELECT nombre, telefono, correo
FROM cliente
WHERE id_cliente NOT IN (SELECT id_cliente FROM venta)
ORDER BY nombre;
-- Propósito: Identifica clientes registrados que aún no han concretado
--   ninguna venta, información valiosa para campañas de marketing que
--   busquen incentivar su primera compra.


-- 22: Inventario inmovilizado — productos sin historial de ventas (CU11, CU20)
SELECT p.codigo, p.nombre, e.stock_actual
FROM producto p
JOIN existencia e ON p.id_producto = e.id_producto
WHERE p.id_producto NOT IN (SELECT id_producto FROM detalle_venta)
ORDER BY e.stock_actual DESC;
-- Propósito: Detecta productos con stock disponible que nunca han figurado
--   en una venta. Permite decidir aplicar descuentos, armar combos o dejar
--   de reabastecer artículos de nula rotación.


-- 23: Top 5 proveedores con mayor volumen de compra (CU13, CU12)
SELECT pr.razon_social, sub.total_comprado
FROM proveedor pr
JOIN (
    SELECT c.id_proveedor, SUM(dc.cantidad * dc.costo_unitario) AS total_comprado
    FROM compra c
    JOIN detalle_compra dc ON c.id_compra = dc.id_compra
    GROUP BY c.id_proveedor
) sub ON pr.id_proveedor = sub.id_proveedor
ORDER BY sub.total_comprado DESC
LIMIT 5;
-- Propósito: Calcula el volumen económico movido con cada proveedor para
--   identificar el top 5, útil al negociar mejores márgenes, líneas de
--   crédito o beneficios exclusivos respaldados por el historial de compra.


-- 24: Ventas cuyo monto pagado supera el promedio general (CU18)
SELECT v.id_venta, v.fecha_hora, pg.monto
FROM venta v
JOIN pago pg ON v.id_venta = pg.id_venta
WHERE pg.monto > (SELECT AVG(monto) FROM pago)
ORDER BY pg.monto DESC;
-- Propósito: Identifica pagos que superan el ticket promedio de la tienda,
--   útil para reconocer clientes "mayoristas" o VIP a quienes ofrecer
--   atención preferencial.


-- 25: Resumen de compras y montos por cada proveedor (CU13, CU12)
SELECT pr.razon_social,
       (SELECT COUNT(*) FROM compra c WHERE c.id_proveedor = pr.id_proveedor) AS cantidad_compras,
       (SELECT COALESCE(SUM(dc.cantidad * dc.costo_unitario), 0)
        FROM compra c
        JOIN detalle_compra dc ON c.id_compra = dc.id_compra
        WHERE c.id_proveedor = pr.id_proveedor) AS monto_total
FROM proveedor pr
ORDER BY monto_total DESC;
-- Propósito: Construye un tablero resumido con subconsultas en el SELECT
--   que indica cuántas compras y qué monto total se ha invertido por
--   proveedor, agilizando el cierre contable de cuentas por pagar.


-- 26: Productos con stock por debajo del promedio general (CU11, CU20)
SELECT p.codigo, p.nombre, e.stock_actual
FROM producto p
JOIN existencia e ON p.id_producto = e.id_producto
WHERE e.stock_actual < (SELECT AVG(stock_actual) FROM existencia)
ORDER BY e.stock_actual ASC;
-- Propósito: Detecta productos cuyo stock está por debajo de la media de
--   todo el inventario, funcionando como alerta temprana ante posibles
--   quiebres de stock en artículos de rotación más rápida.


-- 27: Top 5 clientes con mayor gasto total (pagos confirmados) (CU18, CU19)
SELECT c.nombre, sub.total_pagado
FROM cliente c
JOIN (
    SELECT v.id_cliente, SUM(pg.monto) AS total_pagado
    FROM venta v
    JOIN pago pg ON v.id_venta = pg.id_venta
    WHERE pg.estado = 'CONFIRMADO'
    GROUP BY v.id_cliente
) sub ON c.id_cliente = sub.id_cliente
ORDER BY sub.total_pagado DESC
LIMIT 5;
-- Propósito: Genera el ranking de los 5 clientes que más ingresos
--   confirmados han aportado, base para estrategias de fidelización (CRM)
--   o beneficios preferenciales de fin de año.


-- 28: Último pago registrado por cada cliente (CU16, CU14)
SELECT c.nombre, pg.fecha_hora, pg.monto
FROM cliente c
JOIN venta v ON c.id_cliente = v.id_cliente
JOIN pago pg ON v.id_venta = pg.id_venta
WHERE pg.fecha_hora = (
    SELECT MAX(pg2.fecha_hora)
    FROM pago pg2
    JOIN venta v2 ON pg2.id_venta = v2.id_venta
    WHERE v2.id_cliente = c.id_cliente
)
ORDER BY pg.fecha_hora DESC;
-- Propósito: Extrae, con una subconsulta correlacionada, la fecha del
--   último pago de cada cliente. Ideal para detectar clientes inactivos
--   y reactivar su interés comercial.


-- 29: Utilidad bruta exacta calculada por cada venta (CU19)
SELECT v.id_venta, v.fecha_hora,
       sub.ingreso_total, sub.costo_total,
       (sub.ingreso_total - sub.costo_total) AS utilidad_bruta
FROM venta v
JOIN (
    SELECT id_venta,
           SUM(cantidad * precio_unitario) AS ingreso_total,
           SUM(cantidad * costo_unitario_historico) AS costo_total
    FROM detalle_venta
    GROUP BY id_venta
) sub ON v.id_venta = sub.id_venta
WHERE v.estado = 'CONFIRMADA'
ORDER BY utilidad_bruta DESC;
-- Propósito: Calcula, venta por venta, el ingreso total y el costo
--   histórico registrado en cada línea, entregando a la dirección la
--   utilidad bruta real de cada operación.


-- 30: Métodos de pago más frecuentes en número de transacciones (CU16, CU18)
SELECT sub.metodo, sub.cantidad_pagos
FROM (
    SELECT metodo, COUNT(*) AS cantidad_pagos
    FROM pago
    GROUP BY metodo
) sub
ORDER BY sub.cantidad_pagos DESC;
-- Propósito: Cuenta cuántas veces se ha usado cada medio de pago
--   (EFECTIVO, QR). Le indica a la gerencia si los pagos digitales están
--   ganando adopción, justificando o no mayor inversión en puntos QR/POS.