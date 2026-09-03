import Foundation
import Supabase

/// Singleton del cliente Supabase. Todas las capas de repositorio lo usan.
/// Credenciales del proyecto Tamio (anon key — solo lectura pública con RLS).
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://hkpbkpojeierxqtbmagh.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrcGJrcG9qZWllcnhxdGJtYWdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjE0NzUsImV4cCI6MjA5OTYzNzQ3NX0.z0SGP_XB16wYNFVygqZ8WY2Xev4bfd2J5hR1-2edcso"
)

/// ID de la iglesia activa. Todas las queries filtran por esta FK.
let churchId = "84c92ad0-5362-49f8-8962-0c7b8c34b858"
