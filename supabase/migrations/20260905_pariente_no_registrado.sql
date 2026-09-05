-- SIN APLICAR. Nombre del pariente cuando no tiene ficha en el padrón.
--
-- Es el mismo agujero que `transactions.aportante_nombre` tapó el 3 de
-- septiembre, en la otra punta de la app. `parentescos` solo sabe unir dos
-- filas de `members` —`member_uid` y `pariente_uid`—, pero la hoja "Añadir
-- pariente" promete por escrito lo contrario:
--
--     "Si el pariente no congrega, escribe su nombre: se guarda sin ficha en
--      el padrón."
--
-- Y tiene razón en prometerlo: el hijo pequeño de alguien, o un cónyuge que no
-- congrega, no van a tener ficha, y exigirla obligaría a dar de alta a un bebé
-- para poder decir que es su hijo. Sin esta columna ese nombre no tiene dónde
-- caer y se pierde al subir, que es exactamente lo que pasaba con el nombre
-- del aportante visitante.
alter table public.parentescos
    add column if not exists pariente_nombre text;

comment on column public.parentescos.pariente_nombre is
    'Nombre libre del pariente sin ficha en members. Excluyente con pariente_uid: '
    'si el pariente está en el padrón se usa pariente_uid y esta columna queda nula.';
