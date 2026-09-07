-- Aplicada el 2026-09-07 por Iván desde el SQL Editor.
--
-- **`iglesias` tenía RLS activo y UNA sola política: leer.**
--
-- Sin política de UPDATE, un `update` desde el cliente NO da error: afecta a
-- cero filas y PostgREST devuelve 204. La app lo tomaba por bueno, borraba la
-- operación de la cola, y en la siguiente bajada el servidor le devolvía los
-- valores viejos, que pisaban lo editado.
--
-- Visto en el aparato de Iván el 7 de septiembre de 2026: la moneda volvía a
-- MXN en cada arranque y el logo desaparecía a los pocos segundos. Nada de lo
-- que se escribe en Ajustes · Iglesia se había guardado NUNCA desde iOS, y no
-- había forma de notarlo desde el simulador — allí el repositorio es un mock en
-- memoria y no llega a hablar con Supabase.
--
-- `logo_path` en null y `updated_at` congelado en el 3 de septiembre fueron las
-- dos huellas que lo delataron.

create policy actualizar_mi_iglesia on public.iglesias
  for update
  using  (id = (select church_id from public.perfiles where id = auth.uid()))
  with check (id = (select church_id from public.perfiles where id = auth.uid()));

-- **Y lo que el cliente NO administra se congela aquí.** Abrir el update sin
-- esto dejaría que cualquiera se cambiara el plan, la suscripción o sus propios
-- permisos desde su teléfono — que es exactamente lo que documenta
-- `ConfiguracionIglesia` y la razón de que los permisos vayan por RPC.
create or replace function public.iglesias_congelar_administradas()
returns trigger
language plpgsql
as $$
begin
  new.id         := old.id;
  new.plan       := old.plan;
  new.sub_estado := old.sub_estado;
  new.sub_vence  := old.sub_vence;

  -- Los dos permisos solo se mueven por `fijar_permisos_tesoreria`, que se
  -- anuncia con esta marca local a su transacción. Sin ella, se congelan.
  if coalesce(current_setting('tamio.permisos_por_rpc', true), '') <> 'on' then
    new.tesorero_ve_padron      := old.tesorero_ve_padron;
    new.tesorero_puede_eliminar := old.tesorero_puede_eliminar;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists iglesias_congelar_administradas on public.iglesias;
create trigger iglesias_congelar_administradas
  before update on public.iglesias
  for each row execute function public.iglesias_congelar_administradas();

-- El RPC de los permisos, que ahora tiene que anunciarse para que el trigger
-- le deje pasar. Es el mismo de antes con una línea más.
create or replace function public.fijar_permisos_tesoreria(p_ve_padron boolean, p_puede_eliminar boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  yo record;
begin
  select rol, church_id into yo from public.perfiles where id = auth.uid();
  if yo.church_id is null then
    raise exception 'sin iglesia';
  end if;
  if yo.rol is distinct from 'administrador' then
    raise exception 'solo el administrador cambia los permisos';
  end if;
  perform set_config('tamio.permisos_por_rpc', 'on', true);
  update public.iglesias
     set tesorero_ve_padron = p_ve_padron,
         tesorero_puede_eliminar = p_puede_eliminar
   where id = yo.church_id;
end;
$$;
