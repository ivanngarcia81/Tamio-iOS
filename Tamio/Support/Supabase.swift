import Foundation
import Supabase

/// Singleton del cliente Supabase. Todas las capas de repositorio lo usan.
///
/// La clave es la `anon key` del proyecto: no concede acceso por sí misma. Las
/// políticas RLS de `transactions`, `members` y `perfiles` exigen `auth.uid()`,
/// así que sin sesión iniciada el backend devuelve cero filas y rechaza las
/// escrituras. Ver `SesionSupabase`.
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://hkpbkpojeierxqtbmagh.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrcGJrcG9qZWllcnhxdGJtYWdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjE0NzUsImV4cCI6MjA5OTYzNzQ3NX0.z0SGP_XB16wYNFVygqZ8WY2Xev4bfd2J5hR1-2edcso"
)

/// Iglesia activa, por la que filtran todas las queries. La fuente de verdad es
/// `perfiles.church_id` del usuario autenticado: `SesionSupabase` lo reescribe
/// al iniciar sesión. El valor inicial solo cubre el arranque previo a la sesión.
var churchIdActivo = "84c92ad0-5362-49f8-8962-0c7b8c34b858"
