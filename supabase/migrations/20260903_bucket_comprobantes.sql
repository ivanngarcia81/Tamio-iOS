-- Aplicada el 2026-09-03.
-- Bucket de comprobantes (fotos del sobre, PDF de la transferencia, imagen del
-- cheque). Antes la app guardaba en `comprobante_path` solo el NOMBRE del
-- archivo elegido: el archivo nunca salía del teléfono y la ruta no apuntaba a
-- ninguna parte.
--
-- Privado a propósito: son documentos con datos de personas y de dinero. Se
-- leen con URL firmada de vida corta, no por URL pública.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('comprobantes', 'comprobantes', false, 10485760,
        array['image/jpeg', 'image/png', 'image/heic', 'image/heif',
              'image/webp', 'application/pdf'])
on conflict (id) do nothing;

-- La ruta es `<church_id>/<uuid>.<ext>`: el primer segmento decide de quién es
-- el archivo, y es lo que miran estas políticas. Así una iglesia no puede ver
-- ni escribir los comprobantes de otra.
drop policy if exists "comprobantes_leer"    on storage.objects;
drop policy if exists "comprobantes_subir"   on storage.objects;
drop policy if exists "comprobantes_borrar"  on storage.objects;

create policy "comprobantes_leer"
on storage.objects for select to authenticated
using (
    bucket_id = 'comprobantes'
    and (storage.foldername(name))[1] in (
        select church_id::text from public.perfiles where id = auth.uid()
    )
);

create policy "comprobantes_subir"
on storage.objects for insert to authenticated
with check (
    bucket_id = 'comprobantes'
    and (storage.foldername(name))[1] in (
        select church_id::text from public.perfiles where id = auth.uid()
    )
);

create policy "comprobantes_borrar"
on storage.objects for delete to authenticated
using (
    bucket_id = 'comprobantes'
    and (storage.foldername(name))[1] in (
        select church_id::text from public.perfiles where id = auth.uid()
    )
);
