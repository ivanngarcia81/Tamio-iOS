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
                .task {
                    // Las categorías de la iglesia, ANTES de sincronizar: son
                    // parte del catálogo que ofrecen los `Picker`, y cargarlas
                    // solo al entrar en Ajustes dejaría "Nuevo gasto" sin ellas
                    // hasta que alguien pasara por esa pantalla. Y otra vez
                    // DESPUÉS, porque la bajada puede traer alguna nueva y los
                    // conteos dependen de los movimientos que acaban de llegar.
                    await CategoriasViewModel.compartido.cargar()
                    await MotorSincronizacion.compartido.sincronizar()
                    await CategoriasViewModel.compartido.cargar()
                }
                .onChange(of: fase) { _, nueva in
                    if nueva == .active {
                        Task {
                            await MotorSincronizacion.compartido.sincronizar()
                            // Después de bajar: una categoría creada en la app
                            // web tiene que aparecer aquí sin relanzar nada.
                            await CategoriasViewModel.compartido.cargar()
                        }
                    }
                }
            }
        }
    }
}
