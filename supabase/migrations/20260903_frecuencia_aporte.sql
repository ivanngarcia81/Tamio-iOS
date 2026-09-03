-- Aplicada el 2026-09-03. Ritmo de aporte esperado, por persona.
alter table public.members
    add column if not exists frecuencia_aporte text
        check (frecuencia_aporte in ('semanal', 'quincenal', 'mensual', 'ocasional'));
