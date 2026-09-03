-- Aplicada el 2026-09-03.
-- Nombre del aportante cuando no tiene ficha en el padrón (un visitante, o una
-- fuente externa como una aseguradora).
--
-- La hoja de captura ya prometía esto —"Si es un visitante, escribe su nombre:
-- se guarda sin ficha en el padrón"— pero no había ninguna columna donde
-- ponerlo: `member_uid` es para fichas y `beneficiario` es del lado del gasto.
-- El nombre simplemente se perdía al guardar.
alter table public.transactions
    add column if not exists aportante_nombre text;

comment on column public.transactions.aportante_nombre is
    'Nombre libre del aportante sin ficha en members. Excluyente con member_uid: '
    'si el aportante está en el padrón se usa member_uid y esta columna queda nula.';
