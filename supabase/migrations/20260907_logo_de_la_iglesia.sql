-- Aplicada el 2026-09-07. Ver Tamio/Data/LogoIglesia.swift.
--
-- El logo de la iglesia: la RUTA dentro del bucket `comprobantes`, no la
-- imagen. El archivo vive en `<church_id>/logo/<uuid>.png`, así que las tres
-- políticas del bucket —que miran el primer segmento de la ruta— ya lo aíslan
-- por iglesia sin tocar Storage.
--
-- A diferencia de las firmas, que son locales a cada aparato a propósito, el
-- logo SÍ viaja: es la identidad de la congregación en el papel, no un sello
-- que valga por sí mismo, y tiene que salir igual desde cualquier aparato.
alter table public.iglesias
    add column if not exists logo_path text;
