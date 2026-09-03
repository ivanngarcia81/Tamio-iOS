import SwiftUI

@main
struct TamioApp: App {
    /// La sesión vive en el arranque porque decide qué se muestra: sin ella los
    /// repositorios reales no pueden leer nada (RLS exige `auth.uid()`).
    @State private var sesion = SesionSupabase()

    var body: some Scene {
        WindowGroup {
            switch sesion.estado {
            case .comprobando:
                ProgressView()
                    .task { await sesion.restaurar() }
            case .sinSesion:
                AccesoView(sesion: sesion)
            case .autenticada:
                RootView()
                    .environment(sesion)
            }
        }
    }
}
