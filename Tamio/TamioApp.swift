import SwiftUI

@main
struct TamioApp: App {
    /// La sesión vive en el arranque porque decide qué se muestra: sin ella los
    /// repositorios reales no pueden leer nada (RLS exige `auth.uid()`).
    @State private var sesion = SesionSupabase()
    /// Vive junto a la sesión porque su estado debe sobrevivir a que las
    /// pantallas se creen y destruyan al navegar.
    @State private var navegacion = Navegacion()
    @Environment(\.scenePhase) private var fase

    var body: some Scene {
        WindowGroup {
            switch sesion.estado {
            case .comprobando:
                ProgressView()
                    .task { await sesion.restaurar() }
            case .sinSesion:
                AccesoView(sesion: sesion)
            case .autenticada:
                VStack(spacing: 0) {
                    RootView.avisoRevision
                    RootView()
                }
                .environment(sesion)
                .environment(navegacion)
                // Al entrar y cada vez que la app vuelve al frente: es cuando
                // más probable es que haya red otra vez tras un rato sin ella.
                .task { await MotorSincronizacion.compartido.sincronizar() }
                .onChange(of: fase) { _, nueva in
                    if nueva == .active {
                        Task { await MotorSincronizacion.compartido.sincronizar() }
                    }
                }
            }
        }
    }
}
