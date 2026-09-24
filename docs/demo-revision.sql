-- La iglesia de demostración para la revisión de App Store.
--
-- Qué es: una congregación INVENTADA, con padrón, libros, cortes, actas,
-- cultos y agenda, para que el revisor de Apple pueda entrar, mirarlo todo y
-- —sobre todo— **probar el borrado de cuenta**, que es el requisito 5.1.1(v)
-- y es exactamente lo que va a hacer.
--
-- ── Por qué no se reutiliza «Iglesia de prueba» ─────────────────────────────
-- Es la candidata obvia: 5 perfiles, 30 miembros, 114 movimientos, ya hecha.
-- Y no sirve. Mirado el 18-sep-2026: de sus 30 miembros, 14 tienen teléfono y
-- los 14 son DISTINTOS, con 10 dígitos; solo 2 son del tipo «1234». Uno de sus
-- perfiles es el tesorero de una congregación real. Ese padrón guarda además
-- bautismo, estado de membresía y ministerios, que es justo lo que la ficha
-- declara como INFORMACIÓN SENSIBLE en el cuestionario de privacidad de Apple.
--
-- Darle esas credenciales al revisor es mandarle datos personales sensibles de
-- personas reales que no son quien publica la app. No se hace, aunque cueste
-- media hora más.
--
-- Aquí los nombres son inventados, los teléfonos van en el bloque 555 y los
-- correos en `example.com`, que la RFC 2606 reserva para que no puedan ser de
-- nadie.
--
-- ── El dinero va en CÉNTIMOS · las dos columnas ─────────────────────────────
-- `transactions.monto` va en **CÉNTIMOS**, aunque la columna sea
-- `double precision`: $1,200.00 se guarda como `120000`. Y
-- `iglesias.saldo_inicial` también, que es `bigint`. **Las dos en lo mismo.**
--
-- Esto tiene una historia y conviene saberla, porque la primera versión de
-- este archivo se equivocó justo aquí. Hasta el 13-sep iOS DIVIDÍA entre cien
-- al subir y el web no, así que el mismo importe valía cien veces más o cien
-- veces menos según qué app lo escribiera (`docs/ACUERDO-CON-EL-WEB.md` §1).
-- Se resolvió quitando las siete conversiones del lado iOS. El contrato de hoy
-- lo dicen estos dos sitios, y son los que hay que creer:
--
--     SupabaseMovimientosRepository.swift:297  subir → «En CÉNTIMOS […] aquí
--                                              se dividía entre 100»
--     SupabaseMovimientosRepository.swift:227  bajar → «En céntimos, sin
--                                              convertir: la columna remota ya lo está»
--
-- **Lo que NO hay que creer es el comentario de `DepositoRemoto`** en
-- `MotorSincronizacion.swift`, que decía «va en UNIDADES […] y solo divide
-- aquí» mientras el código de tres líneas más abajo subía sin dividir. Ese
-- comentario caducó con el cambio del 13-sep y es de otra tabla; leerlo y
-- generalizarlo a `transactions` es exactamente cómo se sembró esta demo cien
-- veces más barata la primera vez. Corregido el 18-sep.
--
-- ── La categoría va en CLAVE, y son las CLAVES DE iOS ───────────────────────
-- `diezmo`, no «Diezmo» ni «Tithe». Lo que hay hoy en producción es una sopa
-- —`Limpieza`, `limpieza`, `Supplies`, `Tithe`, `donacion`— de antes de que la
-- clave existiera.
--
-- **Pero no se llaman «canónicas», porque el vocabulario no está cerrado.**
-- `docs/ACUERDO-CON-EL-WEB.md` lo tiene todavía en «Qué hay que decidir»: iOS
-- dice `donativo` y `otro` donde el web dice `donacion` y `otros`, y hay
-- cuatro `id` del web cuyo nombre ya no significa lo que dice —`eventos` es
-- «Alimentos» allá, `musicos` es «Suministros», `pastores` es «Compensación»,
-- `administracion` es «Varios»—. Esta semilla usa **tres de esos cuatro**
-- (`eventos`, `musicos`, `pastores`) con el significado de iOS, que es el que
-- verá el revisor porque entra por la app de iOS.
--
-- Es correcto para lo que hace falta hoy y **no decide nada**: si el acuerdo
-- con el web sale por el otro lado, esas tres líneas hay que cambiarlas aquí
-- también.
--
-- ── Cómo se usa ─────────────────────────────────────────────────────────────
-- 1. Iván da de alta la cuenta del revisor. El disparador `al_crear_usuario`
--    le crea una iglesia vacía, y ESA es la que se rellena aquí.
-- 2. Se pega el id de esa iglesia en la línea marcada abajo.
-- 3. Se corre entero en el editor SQL de Supabase.
--
-- Es **idempotente**: vuelve a correrse encima cuantas veces haga falta, y se
-- para sola si el id apunta a una iglesia que ya tiene datos o a una de las
-- tres reales. Ese guardia es el que impide que un id mal pegado borre la
-- contabilidad de alguien.

do $$
declare
  -- ▼▼▼ LO ÚNICO QUE SE EDITA ▼▼▼
  v_iglesia uuid := '00000000-0000-0000-0000-000000000000';
  -- ▲▲▲ ------------------- ▲▲▲
  v_miembros int;
  v_nombre   text;
begin
  -- Guardia 1: las tres iglesias reales, por id. Un id mal pegado no puede
  -- borrarle los libros a nadie.
  if v_iglesia in ('84c92ad0-5362-49f8-8962-0c7b8c34b858',
                   'bc682973-8ef8-449a-92f1-7b254fc79838',
                   'b496c2e4-cc09-4add-a5c4-2d73db2c81e4') then
    raise exception 'Ese id es de una iglesia REAL. La demo va en una nueva.';
  end if;

  select nombre into v_nombre from iglesias where id = v_iglesia;
  if not found then
    raise exception 'No existe la iglesia %. Créala dando de alta la cuenta del revisor.', v_iglesia;
  end if;

  -- Guardia 2: que esté vacía, o que ya sea esta misma demo (para poder
  -- volver a correrlo). Una iglesia con datos que NO es la demo se respeta.
  select count(*) into v_miembros from members where church_id = v_iglesia and not deleted;
  -- «Iglesia Nueva Vida» fue su nombre hasta el 24-sep, cuando Iván la pasó al
  -- inglés: se reconocen los dos para poder volver a correrlo.
  if v_miembros > 0 and v_nombre not in ('New Life Church', 'Iglesia Nueva Vida') then
    raise exception 'La iglesia % («%») ya tiene % miembros y no es la demo.', v_iglesia, v_nombre, v_miembros;
  end if;

  -- Limpieza de la corrida anterior. Solo de ESTA iglesia, y solo si ya era
  -- la demo: los guardias de arriba lo garantizan.
  delete from servicio_asistencia where church_id = v_iglesia;
  delete from servicios          where church_id = v_iglesia;
  delete from corte_movimientos  where church_id = v_iglesia;
  delete from cortes             where church_id = v_iglesia;
  delete from transactions       where church_id = v_iglesia;
  delete from actas              where church_id = v_iglesia;
  delete from agenda             where church_id = v_iglesia;
  delete from members            where church_id = v_iglesia;
  delete from registro           where church_id = v_iglesia;
  delete from folios_contador    where church_id = v_iglesia;


  -- ── La iglesia ─────────────────────────────────────────────────────────────
  -- En inglés desde el 24-sep, por decisión de Iván: nombre, dirección, moneda
  -- y cargos. Hasta entonces era «Iglesia Nueva Vida», Monterrey, en pesos,
  -- el nombre de las capturas de la ficha (`docs/capturas-tienda/`).
  -- `saldo_inicial` en CENTAVOS: 25,000.00 dólares.
  update iglesias set
    nombre            = 'New Life Church',
    direccion         = '1842 Main St',
    ciudad            = 'Houston',
    estado            = 'Texas',
    pais              = 'United States',
    codigo_postal     = '77002',
    telefono          = '(713) 555-0100',
    correo            = 'contact@example.com',
    moneda            = 'USD',
    saldo_inicial     = 2500000,
    pastor_nombre     = 'Miguel Ángel Ponce',
    pastor_cargo      = 'Pastor',
    tesorero_nombre   = 'Jorge Alberto Nava',
    tesorero_cargo    = 'Treasurer',
    secretario_nombre = 'Claudia Ibarra Solís',
    secretario_cargo  = 'Secretary',
    pie_institucional = 'New Life Church · Houston, TX',
    imprimir_firmas   = true,
    plan              = 'completo',
    sub_estado        = 'cortesia',
    updated_at        = now()
  where id = v_iglesia;

  -- ── El padrón: catorce personas inventadas ─────────────────────────────────
  -- `estado_civil`, `ministerios` y `cargos` van en CLAVE, y los dos últimos
  -- como lista JSON: `casado`, `["ensenanza", "ninos"]`. Hasta el 24-sep iban
  -- las etiquetas en español («Casado(a)», «Enseñanza, Niños»), que la app no
  -- sabe leer: los ministerios salían «Sin área» y el estado civil en español
  -- con la app en inglés. Lo que no está en el catálogo (`Padron`) va en
  -- inglés como texto libre: «Usher», «Choir», «Missions».
  insert into members (uid, church_id, nombre, email, telefono, direccion,
      fecha_ingreso, fecha_nacimiento, estado_civil, estado_membresia, activo,
      bautizado_agua, fecha_bautismo_agua, bautizado_espiritu, ministerios, cargos,
      fecha_congregacion, notas, created_at, updated_at, deleted) values
    ('demo-miembro-01', v_iglesia, 'María Hernández Ríos', 'maria.hernandez@example.com', '(713) 555-0101', '107 Westheimer Rd, Houston, TX', '2014-03-14', '1978-03-14', 'casado', 'activo', 1, 1, '2014-04-12', 1, '["ensenanza", "ninos"]', '["maestro"]', '2012-03-14', '', '2014-03-14T09:00:00Z', now(), false),
    ('demo-miembro-02', v_iglesia, 'Pedro Salas Aguirre', 'pedro.salas@example.com', '(713) 555-0102', '114 Richmond Ave, Houston, TX', '2021-05-09', '1985-11-02', 'casado', 'activo', 1, 1, '2021-06-20', 0, '["ujieres"]', '["Usher"]', '2019-05-09', '', '2021-05-09T09:00:00Z', now(), false),
    ('demo-miembro-03', v_iglesia, 'Ana Lucía Torres', 'ana.lucia@example.com', '(713) 555-0103', '121 Montrose Blvd, Houston, TX', '2016-08-21', '1990-07-30', 'soltero', 'activo', 1, 1, '2016-09-18', 1, '["intercesion"]', '[]', '2014-08-21', 'Serves on the Sunday service team.', '2016-08-21T09:00:00Z', now(), false),
    ('demo-miembro-04', v_iglesia, 'Lucía Márquez Peña', 'lucia.marquez@example.com', '(713) 555-0104', '128 Heights Blvd, Houston, TX', '2019-02-03', '1993-01-17', 'soltero', 'activo', 1, 1, '2019-03-10', 0, '["musica"]', '["Choir"]', '2017-02-03', '', '2019-02-03T09:00:00Z', now(), false),
    ('demo-miembro-05', v_iglesia, 'Javier Medina Cruz', 'javier.medina@example.com', '(713) 555-0105', '135 Washington Ave, Houston, TX', '2016-11-27', '1982-05-24', 'casado', 'activo', 1, 1, '2017-01-15', 1, '[]', '[]', '2014-11-27', '', '2016-11-27T09:00:00Z', now(), false),
    ('demo-miembro-06', v_iglesia, 'Daniel Salas Hernández', 'daniel.salas@example.com', '(713) 555-0106', '142 Navigation Blvd, Houston, TX', '2023-04-16', '1999-09-08', 'soltero', 'activo', 1, 1, '2023-05-21', 0, '["musica"]', '["Drummer"]', '2021-04-16', 'Serves on the Sunday service team.', '2023-04-16T09:00:00Z', now(), false),
    ('demo-miembro-07', v_iglesia, 'Rosa Elena Vega', 'rosa.elena@example.com', '(713) 555-0107', '149 Studewood St, Houston, TX', '2012-07-08', '1966-12-01', 'viudo', 'trasladado', 0, 1, '2012-08-19', 1, '["Women''s ministry"]', '[]', '2010-07-08', '', '2012-07-08T09:00:00Z', now(), false),
    ('demo-miembro-08', v_iglesia, 'Jorge Alberto Nava', 'jorge.alberto@example.com', '(713) 555-0108', '156 Westheimer Rd, Houston, TX', '2018-01-14', '1975-04-11', 'casado', 'activo', 1, 1, '2018-02-25', 0, '["mantenimiento"]', '["diacono"]', '2016-01-14', '', '2018-01-14T09:00:00Z', now(), false),
    ('demo-miembro-09', v_iglesia, 'Claudia Ibarra Solís', 'claudia.ibarra@example.com', '(713) 555-0109', '163 Richmond Ave, Houston, TX', '2020-09-06', '1988-10-19', 'casado', 'activo', 1, 1, '2020-10-11', 1, '["ninos"]', '["maestro"]', '2018-09-06', 'Serves on the Sunday service team.', '2020-09-06T09:00:00Z', now(), false),
    ('demo-miembro-10', v_iglesia, 'Miguel Ángel Ponce', 'miguel.angel@example.com', '(713) 555-0110', '170 Montrose Blvd, Houston, TX', '2015-06-28', '1971-02-06', 'casado', 'activo', 1, 1, '2015-07-26', 0, '["ensenanza"]', '["anciano"]', '2013-06-28', '', '2015-06-28T09:00:00Z', now(), false),
    ('demo-miembro-11', v_iglesia, 'Sofía Ramírez Gallardo', 'sofia.ramirez@example.com', '(713) 555-0111', '177 Heights Blvd, Houston, TX', '2022-03-20', '2001-08-23', 'soltero', 'activo', 1, 1, '2022-04-24', 1, '["jovenes"]', '[]', '2020-03-20', '', '2022-03-20T09:00:00Z', now(), false),
    ('demo-miembro-12', v_iglesia, 'Héctor Domínguez Lara', 'hector.dominguez@example.com', '(713) 555-0112', '184 Washington Ave, Houston, TX', '2017-10-01', '1980-06-15', 'casado', 'inactivo', 0, 1, '2017-11-12', 0, '["ujieres"]', '["Usher"]', '2015-10-01', 'Serves on the Sunday service team.', '2017-10-01T09:00:00Z', now(), false),
    ('demo-miembro-13', v_iglesia, 'Verónica Castañeda', 'veronica.castaneda@example.com', '(713) 555-0113', '191 Navigation Blvd, Houston, TX', '2024-02-11', '1995-03-29', 'soltero', 'activo', 1, 1, '2024-03-17', 1, '["musica"]', '["Choir"]', '2022-02-11', '', '2024-02-11T09:00:00Z', now(), false),
    ('demo-miembro-14', v_iglesia, 'Raúl Estrada Villalobos', 'raul.estrada@example.com', '(713) 555-0114', '198 Studewood St, Houston, TX', '2013-05-19', '1969-09-05', 'casado', 'activo', 1, 1, '2013-06-23', 0, '["Missions"]', '["diacono"]', '2011-05-19', '', '2013-05-19T09:00:00Z', now(), false);

  -- ── Los libros: 34 movimientos de los últimos tres meses ───────────────────
  -- `monto` en PESOS (ver la cabecera). `fecha` en ISO con Z, que es lo que
  -- escribe `Fechas.iso`; en producción conviven tres formatos y eso es
  -- exactamente lo que aquí no se quiere reproducir.
  -- `metodo_pago` va en ETIQUETA y no en clave: la app guarda lo que el usuario
  -- ve («Cash», «Check 8823») y lo enseña tal cual. Con `efectivo` la lista
  -- decía «Folio 1001 · efectivo» (visto el 24-sep).
  insert into transactions (uid, church_id, member_uid, tipo, categoria, concepto,
      fecha, monto, moneda, metodo_pago, estado, folio, folio_seq, aportante_nombre,
      beneficiario, notas, registrado_por, registrado_rol, comprobante_path,
      created_at, updated_at, deleted) values
    ('demo-ingreso-01', v_iglesia, 'demo-miembro-01', 'ingreso', 'diezmo', 'Tithe', '2026-09-18T11:00:00Z', 120000, 'USD', 'Cash', 'pendiente', '1001', 1001, 'María Hernández Ríos', null, 'Handed in a sealed envelope during the service.', 'Jorge Alberto Nava', 'tesorero', 'comprobantes/1001.jpg', '2026-09-18T11:00:00Z', now(), false),
    ('demo-ingreso-02', v_iglesia, null, 'ingreso', 'ofrenda', 'Sunday offering', '2026-09-17T12:07:00Z', 318000, 'USD', 'Cash', 'aprobado', '1002', 1002, null, null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-17T12:07:00Z', now(), false),
    ('demo-ingreso-03', v_iglesia, 'demo-miembro-02', 'ingreso', 'diezmo', 'Tithe', '2026-09-16T13:14:00Z', 250000, 'USD', 'Check', 'aprobado', '1003', 1003, 'Pedro Salas Aguirre', null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-16T13:14:00Z', now(), false),
    ('demo-ingreso-04', v_iglesia, null, 'ingreso', 'misiones', 'Missions offering', '2026-09-16T14:21:00Z', 684500, 'USD', 'Cash', 'aprobado', '1004', 1004, null, null, '', 'Jorge Alberto Nava', 'tesorero', 'comprobantes/1004.jpg', '2026-09-16T14:21:00Z', now(), false),
    ('demo-ingreso-05', v_iglesia, 'demo-miembro-03', 'ingreso', 'diezmo', 'Tithe', '2026-09-15T15:28:00Z', 90000, 'USD', 'Transfer', 'aprobado', '1005', 1005, 'Ana Lucía Torres', null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-15T15:28:00Z', now(), false),
    ('demo-ingreso-06', v_iglesia, 'demo-miembro-04', 'ingreso', 'diezmo', 'Tithe', '2026-09-14T16:35:00Z', 145000, 'USD', 'Cash', 'pendiente', '1006', 1006, 'Lucía Márquez Peña', null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-14T16:35:00Z', now(), false),
    ('demo-ingreso-07', v_iglesia, null, 'ingreso', 'ofrenda', 'Wednesday offering', '2026-09-13T17:42:00Z', 210000, 'USD', 'Cash', 'aprobado', '1007', 1007, null, null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-13T17:42:00Z', now(), false),
    ('demo-ingreso-08', v_iglesia, 'demo-miembro-05', 'ingreso', 'diezmo', 'Tithe', '2026-09-12T18:49:00Z', 180000, 'USD', 'Check', 'aprobado', '1008', 1008, 'Javier Medina Cruz', null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-12T18:49:00Z', now(), false),
    ('demo-ingreso-09', v_iglesia, null, 'ingreso', 'donativo', 'Building fund', '2026-09-11T11:56:00Z', 128000, 'USD', 'Check', 'aprobado', '1009', 1009, null, null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-11T11:56:00Z', now(), false),
    ('demo-ingreso-10', v_iglesia, 'demo-miembro-07', 'ingreso', 'diezmo', 'Tithe', '2026-09-10T12:03:00Z', 225000, 'USD', 'Cash', 'aprobado', '1010', 1010, 'Rosa Elena Vega', null, '', 'Jorge Alberto Nava', 'tesorero', 'comprobantes/1010.jpg', '2026-09-10T12:03:00Z', now(), false),
    ('demo-ingreso-11', v_iglesia, null, 'ingreso', 'ofrenda', 'General offering', '2026-09-09T13:10:00Z', 170000, 'USD', 'Cash', 'aprobado', '1011', 1011, null, null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-09T13:10:00Z', now(), false),
    ('demo-ingreso-12', v_iglesia, 'demo-miembro-08', 'ingreso', 'diezmo', 'Tithe', '2026-09-07T14:17:00Z', 310000, 'USD', 'Transfer', 'aprobado', '1012', 1012, 'Jorge Alberto Nava', null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-07T14:17:00Z', now(), false),
    ('demo-ingreso-13', v_iglesia, null, 'ingreso', 'eventos', 'Youth retreat', '2026-09-04T15:24:00Z', 440000, 'USD', 'Cash', 'pendiente', '1013', 1013, null, null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-04T15:24:00Z', now(), false),
    ('demo-ingreso-14', v_iglesia, 'demo-miembro-09', 'ingreso', 'diezmo', 'Tithe', '2026-09-02T16:31:00Z', 115000, 'USD', 'Cash', 'aprobado', '1014', 1014, 'Claudia Ibarra Solís', null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-02T16:31:00Z', now(), false),
    ('demo-ingreso-15', v_iglesia, null, 'ingreso', 'ofrenda', 'Sunday offering', '2026-08-31T17:38:00Z', 289000, 'USD', 'Cash', 'aprobado', '1015', 1015, null, null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-31T17:38:00Z', now(), false),
    ('demo-ingreso-16', v_iglesia, 'demo-miembro-10', 'ingreso', 'diezmo', 'Tithe', '2026-08-28T18:45:00Z', 197500, 'USD', 'Cash', 'aprobado', '1016', 1016, 'Miguel Ángel Ponce', null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-28T18:45:00Z', now(), false),
    ('demo-ingreso-17', v_iglesia, null, 'ingreso', 'misiones', 'Missions offering', '2026-08-26T11:52:00Z', 326000, 'USD', 'Cash', 'aprobado', '1017', 1017, null, null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-26T11:52:00Z', now(), false),
    ('demo-ingreso-18', v_iglesia, 'demo-miembro-11', 'ingreso', 'diezmo', 'Tithe', '2026-08-21T12:59:00Z', 240000, 'USD', 'Check', 'aprobado', '1018', 1018, 'Sofía Ramírez Gallardo', null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-21T12:59:00Z', now(), false),
    ('demo-ingreso-19', v_iglesia, null, 'ingreso', 'ofrenda', 'Sunday offering', '2026-08-19T13:06:00Z', 305000, 'USD', 'Cash', 'aprobado', '1019', 1019, null, null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-19T13:06:00Z', now(), false),
    ('demo-ingreso-20', v_iglesia, null, 'ingreso', 'donativo', 'Donation for chairs', '2026-08-14T14:13:00Z', 500000, 'USD', 'Transfer', 'aprobado', '1020', 1020, null, null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-14T14:13:00Z', now(), false),
    ('demo-ingreso-21', v_iglesia, 'demo-miembro-13', 'ingreso', 'diezmo', 'Tithe', '2026-08-11T15:20:00Z', 160000, 'USD', 'Cash', 'aprobado', '1021', 1021, 'Verónica Castañeda', null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-11T15:20:00Z', now(), false),
    ('demo-ingreso-22', v_iglesia, null, 'ingreso', 'ofrenda', 'Wednesday offering', '2026-08-07T16:27:00Z', 184000, 'USD', 'Cash', 'aprobado', '1022', 1022, null, null, '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-07T16:27:00Z', now(), false),
    ('demo-gasto-01', v_iglesia, null, 'gasto', 'utilidades', 'Electric bill', '2026-09-17T09:00:00Z', 341050, 'USD', 'Transfer', 'aprobado', '501', 501, null, 'CenterPoint Energy', '', 'Jorge Alberto Nava', 'tesorero', 'comprobantes/501.jpg', '2026-09-17T09:00:00Z', now(), false),
    ('demo-gasto-02', v_iglesia, null, 'gasto', 'renta', 'Building rent', '2026-09-15T10:11:00Z', 1200000, 'USD', 'Transfer', 'aprobado', '502', 502, null, 'Northside Properties', '', 'Jorge Alberto Nava', 'tesorero', 'comprobantes/502.jpg', '2026-09-15T10:11:00Z', now(), false),
    ('demo-gasto-03', v_iglesia, null, 'gasto', 'pastores', 'Pastoral support', '2026-09-13T11:22:00Z', 900000, 'USD', 'Transfer', 'pendiente', '503', 503, null, '', '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-13T11:22:00Z', now(), false),
    ('demo-gasto-04', v_iglesia, null, 'gasto', 'musicos', 'Musicians support', '2026-09-12T12:33:00Z', 250000, 'USD', 'Cash', 'aprobado', '504', 504, null, '', '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-12T12:33:00Z', now(), false),
    ('demo-gasto-05', v_iglesia, null, 'gasto', 'limpieza', 'Cleaning supplies', '2026-09-09T13:44:00Z', 86000, 'USD', 'Cash', 'aprobado', '505', 505, null, 'Main Street Grocery', '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-09T13:44:00Z', now(), false),
    ('demo-gasto-06', v_iglesia, null, 'gasto', 'suministros', 'Paper and toner', '2026-09-06T14:55:00Z', 124000, 'USD', 'Card', 'aprobado', '506', 506, null, 'Downtown Office Supply', '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-06T14:55:00Z', now(), false),
    ('demo-gasto-07', v_iglesia, null, 'gasto', 'mantenimiento', 'A/C repair', '2026-09-01T15:06:00Z', 380000, 'USD', 'Cash', 'aprobado', '507', 507, null, 'Bayou City HVAC', '', 'Jorge Alberto Nava', 'tesorero', null, '2026-09-01T15:06:00Z', now(), false),
    ('demo-gasto-08', v_iglesia, null, 'gasto', 'alimentos', 'Coffee and cookies', '2026-08-29T16:17:00Z', 54000, 'USD', 'Cash', 'aprobado', '508', 508, null, '', '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-29T16:17:00Z', now(), false),
    ('demo-gasto-09', v_iglesia, null, 'gasto', 'utilidades', 'Water and sewer', '2026-08-25T17:28:00Z', 69000, 'USD', 'Transfer', 'aprobado', '509', 509, null, 'Houston Public Works', '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-25T17:28:00Z', now(), false),
    ('demo-gasto-10', v_iglesia, null, 'gasto', 'tecnologia', 'HDMI cable and adapter', '2026-08-22T09:39:00Z', 98000, 'USD', 'Card', 'aprobado', '510', 510, null, 'TechNorth', '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-22T09:39:00Z', now(), false),
    ('demo-gasto-11', v_iglesia, null, 'gasto', 'misiones', 'Monthly missions support', '2026-08-18T10:50:00Z', 400000, 'USD', 'Transfer', 'aprobado', '511', 511, null, '', '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-18T10:50:00Z', now(), false),
    ('demo-gasto-12', v_iglesia, null, 'gasto', 'ayudaSocial', 'Groceries for a family', '2026-08-13T11:01:00Z', 150000, 'USD', 'Cash', 'aprobado', '512', 512, null, '', '', 'Jorge Alberto Nava', 'tesorero', null, '2026-08-13T11:01:00Z', now(), false);

  -- ── Tres cortes: dos ya depositados y uno pendiente ────────────────────────
  -- Un corte nace VACÍO y se llena desde su ficha: el total sale de la tabla
  -- puente `corte_movimientos`, nunca de una columna propia, así que aquí
  -- tampoco se escribe ningún importe. Es lo que impide que se desvíen.
  insert into cortes (uid, church_id, fecha, nombre, cuenta_banco, responsable,
      estado, notas, registrado_por, registrado_rol, created_at, updated_at,
      deleted, doble_firma_pedida) values
    ('demo-corte-1', v_iglesia, '2026-08-16', 'Sunday service, August 16', 'Chase ··4821', 'Jorge Alberto Nava', 'depositado', '', 'Jorge Alberto Nava', 'tesorero', '2026-08-16T18:30:00Z', now(), false, false),
    ('demo-corte-2', v_iglesia, '2026-08-30', 'Sunday service, August 30', 'Chase ··4821', 'Jorge Alberto Nava', 'depositado', '', 'Jorge Alberto Nava', 'tesorero', '2026-08-30T18:30:00Z', now(), false, false),
    ('demo-corte-3', v_iglesia, '2026-09-13', 'Sunday service, September 13', 'Chase ··4821', 'Jorge Alberto Nava', 'pendiente', '', 'Jorge Alberto Nava', 'tesorero', '2026-09-13T18:30:00Z', now(), false, false);

  -- El dinero de cada corte. Dos columnas y nada más: sin monto ni copia.
  insert into corte_movimientos (uid, church_id, corte_uid, tx_uid, updated_at, deleted) values
    ('demo-puente-01', v_iglesia, 'demo-corte-1', 'demo-ingreso-20', now(), false),
    ('demo-puente-02', v_iglesia, 'demo-corte-1', 'demo-ingreso-21', now(), false),
    ('demo-puente-03', v_iglesia, 'demo-corte-1', 'demo-ingreso-22', now(), false),
    ('demo-puente-04', v_iglesia, 'demo-corte-2', 'demo-ingreso-16', now(), false),
    ('demo-puente-05', v_iglesia, 'demo-corte-2', 'demo-ingreso-17', now(), false),
    ('demo-puente-06', v_iglesia, 'demo-corte-2', 'demo-ingreso-18', now(), false),
    ('demo-puente-07', v_iglesia, 'demo-corte-2', 'demo-ingreso-19', now(), false),
    ('demo-puente-08', v_iglesia, 'demo-corte-3', 'demo-ingreso-07', now(), false),
    ('demo-puente-09', v_iglesia, 'demo-corte-3', 'demo-ingreso-08', now(), false),
    ('demo-puente-10', v_iglesia, 'demo-corte-3', 'demo-ingreso-09', now(), false),
    ('demo-puente-11', v_iglesia, 'demo-corte-3', 'demo-ingreso-10', now(), false);

  -- ── Dos actas: una firmada y una en borrador ───────────────────────────────
  -- `acuerdos`, `mociones`, `firmas`, `presentes` y `ausentes` son JSON dentro
  -- de una columna de texto, y cada uno tiene SU forma: los acuerdos y las
  -- mociones son objetos (`{"texto":…}`), las firmas llevan `rol`/`firmado`/
  -- `fecha`, y las listas de nombres sí son cadenas sueltas. Escribir una
  -- lista de cadenas donde van objetos no da error: el acta abre con los
  -- acuerdos vacíos y parece que se perdieron.
  --
  -- Y el `estado` que viaja al servidor no es el de la app: `firmada` sube como
  -- `aprobada` y `cerrada` como `archivada`. El matiz de la firma vive en la
  -- columna `firmas`.
  insert into actas (uid, church_id, folio, tipo, titulo, fecha, hora_inicio,
      hora_cierre, lugar, preside, secretario, testigo, presentes, ausentes,
      invitados, quorum, agenda, resumen, mociones, acuerdos, estado,
      confidencial, fecha_aprobacion, firmas, creado_en, updated_at, deleted) values
    ('demo-acta-1', v_iglesia, 'ACTA-2026-001', 'administrativa', 'Council meeting · August', '2026-08-21', '19:00', '20:40', 'Annex hall', 'Miguel Ángel Ponce', 'Claudia Ibarra Solís', 'Raúl Estrada Villalobos', '["Miguel Ángel Ponce", "Claudia Ibarra Solís", "Jorge Alberto Nava", "Raúl Estrada Villalobos", "María Hernández Ríos"]', '["Héctor Domínguez Lara"]', '[]', 1, '1. Reading of the previous minutes
2. Treasury report
3. Youth retreat
4. Other business', 'The July treasury report was read and approved unanimously. The youth retreat budget was agreed.', '[{"texto": "Approve the July treasury report", "presenta": "Jorge Alberto Nava", "secunda": "Raúl Estrada Villalobos", "resultado": "aprobada"}]', '[{"texto": "Approve the July treasury report.", "responsable": "", "fecha_limite": null}, {"texto": "Allocate $4,400.00 to the September 26 youth retreat.", "responsable": "", "fecha_limite": null}, {"texto": "Get quotes to repair the main hall air conditioning.", "responsable": "", "fecha_limite": null}, {"texto": "Appoint Claudia Ibarra Solís to lead the children''s ministry.", "responsable": "", "fecha_limite": null}]', 'aprobada', 0, '2026-08-21', '[{"rol": "preside", "firmado": true, "fecha": "2026-08-21"}, {"rol": "secretario", "firmado": true, "fecha": "2026-08-21"}, {"rol": "testigo", "firmado": true, "fecha": "2026-08-21"}]', '2026-08-21T21:00:00Z', now(), false),
    ('demo-acta-2', v_iglesia, 'ACTA-2026-002', 'administrativa', 'Council meeting · September', '2026-09-14', '19:00', null, 'Annex hall', 'Miguel Ángel Ponce', 'Claudia Ibarra Solís', '', '["Miguel Ángel Ponce", "Claudia Ibarra Solís", "Jorge Alberto Nava"]', '[]', '["Sofía Ramírez Gallardo"]', 1, '1. August treasury report
2. Transfer of Sister Rosa Elena Vega
3. Other business', 'Pending closing.', '[]', '[{"texto": "Follow up on the transfer letter for Sister Rosa Elena Vega.", "responsable": "", "fecha_limite": null}, {"texto": "Review the membership roll before the annual report.", "responsable": "", "fecha_limite": null}]', 'borrador', 0, null, '[]', '2026-09-14T21:00:00Z', now(), false);

  -- ── La agenda del mes ──────────────────────────────────────────────────────
  -- `fecha` aquí es SOLO EL DÍA (`YYYY-MM-DD`), no un instante: es la columna
  -- que la app acota por prefijo. Meterle una hora con Z la corre de día al
  -- oeste de Greenwich y la actividad del día 1 aparece el 30 del mes anterior.
  insert into agenda (uid, church_id, nombre, tipo, fecha, hora_inicio, hora_fin,
      dia_completo, lugar, descripcion, responsable_persona, responsable_ministerio,
      estado, es_fecha_importante, creado_en, updated_at, deleted) values
    ('demo-agenda-01', v_iglesia, 'Morning service', 'culto', '2026-09-16', '10:00', '12:00', 0, 'Sanctuary', 'Sunday service with communion.', 'Miguel Ángel Ponce', '', 'programada', 0, '2026-08-29T12:00:00Z', now(), false),
    ('demo-agenda-02', v_iglesia, 'Elders council', 'reunion', '2026-09-21', '19:00', '20:30', 0, 'Annex hall', 'Take minutes.', 'Claudia Ibarra Solís', '', 'programada', 0, '2026-08-29T12:00:00Z', now(), false),
    ('demo-agenda-03', v_iglesia, 'Prayer service', 'culto', '2026-09-23', '19:30', '21:00', 0, 'Sanctuary', '', '', 'Intercession', 'programada', 0, '2026-08-29T12:00:00Z', now(), false),
    ('demo-agenda-04', v_iglesia, 'Worship rehearsal', 'ensayo', '2026-09-24', '18:00', '20:00', 0, 'Music room', '', 'Lucía Márquez Peña', 'Music', 'programada', 0, '2026-08-29T12:00:00Z', now(), false),
    ('demo-agenda-05', v_iglesia, 'Youth retreat', 'evento', '2026-09-26', '08:00', '20:00', 0, 'Pine Hollow Camp', 'Budget approved in the minutes.', 'Sofía Ramírez Gallardo', 'Youth', 'programada', 0, '2026-08-29T12:00:00Z', now(), false),
    ('demo-agenda-06', v_iglesia, 'Sunday school', 'clase', '2026-09-30', '09:00', '10:00', 0, 'Classrooms', '', 'María Hernández Ríos', 'Teaching', 'programada', 0, '2026-08-29T12:00:00Z', now(), false),
    ('demo-agenda-07', v_iglesia, 'Visit to Sister Rosa Elena', 'visita', '2026-10-02', '17:00', '18:30', 0, 'At home', 'Transfer follow-up.', 'Claudia Ibarra Solís', '', 'programada', 0, '2026-08-29T12:00:00Z', now(), false),
    ('demo-agenda-08', v_iglesia, 'Bank deposit', 'administrativo', '2026-09-22', '11:00', '12:00', 0, 'Chase, Downtown branch', 'Deposit from Sunday the 14th.', 'Jorge Alberto Nava', '', 'programada', 0, '2026-08-29T12:00:00Z', now(), false);

  -- ── Tres cultos con su lista de asistencia ─────────────────────────────────
  insert into servicios (uid, church_id, fecha, tipo, dirige, predica,
      titulo_mensaje, texto_biblico, ninos, jovenes, adultos, visitantes,
      creado_en, updated_at, deleted) values
    ('demo-culto-1', v_iglesia, '2026-09-02', 'dominical', 'Raúl Estrada Villalobos', 'Miguel Ángel Ponce', 'The house built on the rock', 'Matthew 7:24-27', 12, 9, 34, '2', '2026-09-02T13:00:00Z', now(), false),
    ('demo-culto-2', v_iglesia, '2026-09-09', 'oracion', 'Ana Lucía Torres', 'Ana Lucía Torres', 'Night of intercession', 'Ephesians 6:18', 4, 7, 21, '0', '2026-09-09T13:00:00Z', now(), false),
    ('demo-culto-3', v_iglesia, '2026-09-16', 'dominical', 'Jorge Alberto Nava', 'Miguel Ángel Ponce', 'The faithful servant', 'Luke 16:10', 14, 11, 38, '3', '2026-09-16T13:00:00Z', now(), false);

  -- Quién vino: una fila por persona y culto, con el nombre congelado.
  insert into servicio_asistencia (uid, church_id, servicio_uid, member_uid,
      presente, razon, nombre_snapshot, seguimiento, updated_at, deleted) values
    ('demo-asis-001', v_iglesia, 'demo-culto-1', 'demo-miembro-01', 0, 'enfermedad', 'María Hernández Ríos', 1, now(), false),
    ('demo-asis-002', v_iglesia, 'demo-culto-1', 'demo-miembro-02', 1, '', 'Pedro Salas Aguirre', 0, now(), false),
    ('demo-asis-003', v_iglesia, 'demo-culto-1', 'demo-miembro-03', 1, '', 'Ana Lucía Torres', 0, now(), false),
    ('demo-asis-004', v_iglesia, 'demo-culto-1', 'demo-miembro-04', 1, '', 'Lucía Márquez Peña', 0, now(), false),
    ('demo-asis-005', v_iglesia, 'demo-culto-1', 'demo-miembro-05', 1, '', 'Javier Medina Cruz', 0, now(), false),
    ('demo-asis-006', v_iglesia, 'demo-culto-1', 'demo-miembro-06', 1, '', 'Daniel Salas Hernández', 0, now(), false),
    ('demo-asis-007', v_iglesia, 'demo-culto-1', 'demo-miembro-08', 0, 'enfermedad', 'Jorge Alberto Nava', 1, now(), false),
    ('demo-asis-008', v_iglesia, 'demo-culto-1', 'demo-miembro-09', 1, '', 'Claudia Ibarra Solís', 0, now(), false),
    ('demo-asis-009', v_iglesia, 'demo-culto-1', 'demo-miembro-10', 1, '', 'Miguel Ángel Ponce', 0, now(), false),
    ('demo-asis-010', v_iglesia, 'demo-culto-1', 'demo-miembro-11', 1, '', 'Sofía Ramírez Gallardo', 0, now(), false),
    ('demo-asis-011', v_iglesia, 'demo-culto-1', 'demo-miembro-12', 1, '', 'Héctor Domínguez Lara', 0, now(), false),
    ('demo-asis-012', v_iglesia, 'demo-culto-1', 'demo-miembro-13', 1, '', 'Verónica Castañeda', 0, now(), false),
    ('demo-asis-013', v_iglesia, 'demo-culto-1', 'demo-miembro-14', 1, '', 'Raúl Estrada Villalobos', 0, now(), false),
    ('demo-asis-014', v_iglesia, 'demo-culto-2', 'demo-miembro-01', 1, '', 'María Hernández Ríos', 0, now(), false),
    ('demo-asis-015', v_iglesia, 'demo-culto-2', 'demo-miembro-02', 0, 'enfermedad', 'Pedro Salas Aguirre', 1, now(), false),
    ('demo-asis-016', v_iglesia, 'demo-culto-2', 'demo-miembro-03', 1, '', 'Ana Lucía Torres', 0, now(), false),
    ('demo-asis-017', v_iglesia, 'demo-culto-2', 'demo-miembro-04', 1, '', 'Lucía Márquez Peña', 0, now(), false),
    ('demo-asis-018', v_iglesia, 'demo-culto-2', 'demo-miembro-05', 1, '', 'Javier Medina Cruz', 0, now(), false),
    ('demo-asis-019', v_iglesia, 'demo-culto-2', 'demo-miembro-06', 1, '', 'Daniel Salas Hernández', 0, now(), false),
    ('demo-asis-020', v_iglesia, 'demo-culto-2', 'demo-miembro-08', 1, '', 'Jorge Alberto Nava', 0, now(), false),
    ('demo-asis-021', v_iglesia, 'demo-culto-2', 'demo-miembro-09', 0, 'enfermedad', 'Claudia Ibarra Solís', 1, now(), false),
    ('demo-asis-022', v_iglesia, 'demo-culto-2', 'demo-miembro-10', 1, '', 'Miguel Ángel Ponce', 0, now(), false),
    ('demo-asis-023', v_iglesia, 'demo-culto-2', 'demo-miembro-11', 1, '', 'Sofía Ramírez Gallardo', 0, now(), false),
    ('demo-asis-024', v_iglesia, 'demo-culto-2', 'demo-miembro-12', 1, '', 'Héctor Domínguez Lara', 0, now(), false),
    ('demo-asis-025', v_iglesia, 'demo-culto-2', 'demo-miembro-13', 1, '', 'Verónica Castañeda', 0, now(), false),
    ('demo-asis-026', v_iglesia, 'demo-culto-2', 'demo-miembro-14', 1, '', 'Raúl Estrada Villalobos', 0, now(), false),
    ('demo-asis-027', v_iglesia, 'demo-culto-3', 'demo-miembro-01', 1, '', 'María Hernández Ríos', 0, now(), false),
    ('demo-asis-028', v_iglesia, 'demo-culto-3', 'demo-miembro-02', 1, '', 'Pedro Salas Aguirre', 0, now(), false),
    ('demo-asis-029', v_iglesia, 'demo-culto-3', 'demo-miembro-03', 0, 'enfermedad', 'Ana Lucía Torres', 1, now(), false),
    ('demo-asis-030', v_iglesia, 'demo-culto-3', 'demo-miembro-04', 1, '', 'Lucía Márquez Peña', 0, now(), false),
    ('demo-asis-031', v_iglesia, 'demo-culto-3', 'demo-miembro-05', 1, '', 'Javier Medina Cruz', 0, now(), false),
    ('demo-asis-032', v_iglesia, 'demo-culto-3', 'demo-miembro-06', 1, '', 'Daniel Salas Hernández', 0, now(), false),
    ('demo-asis-033', v_iglesia, 'demo-culto-3', 'demo-miembro-08', 1, '', 'Jorge Alberto Nava', 0, now(), false),
    ('demo-asis-034', v_iglesia, 'demo-culto-3', 'demo-miembro-09', 1, '', 'Claudia Ibarra Solís', 0, now(), false),
    ('demo-asis-035', v_iglesia, 'demo-culto-3', 'demo-miembro-10', 0, 'enfermedad', 'Miguel Ángel Ponce', 1, now(), false),
    ('demo-asis-036', v_iglesia, 'demo-culto-3', 'demo-miembro-11', 1, '', 'Sofía Ramírez Gallardo', 0, now(), false),
    ('demo-asis-037', v_iglesia, 'demo-culto-3', 'demo-miembro-12', 1, '', 'Héctor Domínguez Lara', 0, now(), false),
    ('demo-asis-038', v_iglesia, 'demo-culto-3', 'demo-miembro-13', 1, '', 'Verónica Castañeda', 0, now(), false),
    ('demo-asis-039', v_iglesia, 'demo-culto-3', 'demo-miembro-14', 1, '', 'Raúl Estrada Villalobos', 0, now(), false);

  -- ── Los contadores de folio ────────────────────────────────────────────────
  -- Por encima del último folio sembrado, o el siguiente movimiento que capture
  -- el revisor reutilizaría un número que ya está en uso. `ingreso` y `gasto`
  -- no llevan año (`anio = 0`); `acta` y `carta` sí.
  insert into folios_contador (church_id, serie, ultimo, anio, updated_at) values
    (v_iglesia, 'ingreso', 1022, 0,    now()),
    (v_iglesia, 'gasto',    512, 0,    now()),
    (v_iglesia, 'acta',       2, 2026, now()),
    (v_iglesia, 'carta',      0, 2026, now());

  raise notice 'New Life Church sembrada en %: 14 miembros, 34 movimientos, 3 cortes, 2 actas, 3 cultos, 8 actividades.', v_iglesia;
end $$;

-- ── Comprobación, para correr después y mirar ────────────────────────────────
-- Pega el mismo id. **Estas son las cifras que tiene que dar**, y están aquí
-- porque la primera versión sembró el dinero cien veces más barato y nada lo
-- habría dicho: la app habría enseñado $488.20 de ingresos con toda naturalidad.
-- Un número esperado escrito al lado es lo que convierte esta consulta en una
-- comprobación en vez de en un vistazo.
--
--   miembros           14
--   movimientos        34   (22 ingresos, 12 gastos)
--   ingresos aprobados  4 882 000 céntimos =  $48,820.00
--   gastos aprobados    3 152 050 céntimos =  $31,520.50
--   balance             1 729 950 céntimos =  $17,299.50
--   sin aprobar         3 ingresos ($7,050.00) y 1 gasto ($9,000.00)
--   perfiles           ≥ 2
--
-- Si la app enseña **$488.20 en vez de $48,820.00**, el dinero se sembró en
-- pesos y no en céntimos: es el fallo del 18-sep, y se arregla multiplicando
-- por cien la columna `monto` de esta iglesia.
--
--   select
--     (select count(*) from members      where church_id = '…' and not deleted) miembros,
--     (select count(*) from transactions where church_id = '…' and not deleted) movimientos,
--     (select round(sum(monto)::numeric, 2) from transactions
--        where church_id = '…' and tipo='ingreso' and estado='aprobado' and not deleted) ingresos,
--     (select round(sum(monto)::numeric, 2) from transactions
--        where church_id = '…' and tipo='gasto'   and estado='aprobado' and not deleted) gastos,
--     (select count(*) from perfiles     where church_id = '…') perfiles;
--
-- **`perfiles` tiene que dar 2 o más.** Con uno solo, el revisor prueba el
-- borrado de cuenta —que es justo lo que va a hacer— y la función
-- `borrar-cuenta` se lleva la iglesia entera en cascada: hay que rehacer la
-- demo para la siguiente ronda.
