import SwiftUI

@main
struct TamioApp: App {
    /// La sesión vive en el arranque porque decide qué se muestra: sin ella los
    /// repositorios reales no pueden leer nada (RLS exige `auth.uid()`).
    @State private var sesion = SesionSupabase()
    /// Vive junto a la sesión porque su estado debe sobrevivir a que las
    /// pantallas se creen y destruyan al navegar.
    @State private var navegacion = Navegacion()
    /// Tema, idioma y tamaño de letra. Viven aquí porque se aplican a la app
    /// entera y no a una pantalla.
    @State private var prefs = PreferenciasApp.compartidas
    @Environment(\.scenePhase) private var fase

    var body: some Scene {
        WindowGroup {
            contenido
                .preferredColorScheme(prefs.tema.esquema)
                // `nil` en "Normal": sin el modificador, la app respeta el
                // ajuste de accesibilidad del sistema. Solo se sustituye
                // cuando alguien ha pedido otro tamaño expresamente.
                .modifier(TamanoTexto(tamano: prefs.tamano.dynamicType))
                // Cambiar de idioma reconstruye el árbol. `L.t` son funciones
                // estáticas que cientos de vistas llaman dentro de su `body`:
                // SwiftUI no tiene forma de saber que su resultado cambió, así
                // que sin esto la app se quedaría en el idioma anterior hasta
                // relanzarla.
                .id(prefs.idioma)
        }
    }

    @ViewBuilder
    private var contenido: some View {
        Group {
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
                    // La configuración de la iglesia, la primera: de ella salen
                    // el membrete, la moneda y los permisos, y hay pantallas
                    // —la sidebar, Ingresos— que los leen antes de que nadie
                    // pase por Ajustes.
                    await ConfiguracionIglesiaViewModel.compartido.cargar()
                    // Las categorías, ANTES de sincronizar: son parte del
                    // catálogo que ofrecen los `Picker`, y cargarlas solo al
                    // entrar en Ajustes dejaría "Nuevo gasto" sin ellas hasta
                    // que alguien pasara por esa pantalla. Y otra vez DESPUÉS,
                    // porque la bajada puede traer alguna nueva y los conteos
                    // dependen de los movimientos que acaban de llegar.
                    await CategoriasViewModel.compartido.cargar()
                    await MotorSincronizacion.compartido.sincronizar()
                    await CategoriasViewModel.compartido.cargar()
                }
                .onChange(of: fase) { _, nueva in
                    if nueva == .active {
                        Task {
                            await MotorSincronizacion.compartido.sincronizar()
                            // Después de bajar: una categoría creada en la app
                            // web, o un permiso que le quitaron al tesorero,
                            // tienen que aparecer aquí sin relanzar nada.
                            await ConfiguracionIglesiaViewModel.compartido.recargar()
                            await CategoriasViewModel.compartido.cargar()
                        }
                    }
                }
            }
        }
    }
}

/// El tamaño de letra, aplicado solo si hay uno elegido. Es un `ViewModifier`
/// porque `dynamicTypeSize(_:)` no acepta `nil`, y "no aplicar nada" es
/// justamente lo que tiene que pasar en "Normal".
private struct TamanoTexto: ViewModifier {
    let tamano: DynamicTypeSize?

    func body(content: Content) -> some View {
        if let tamano {
            content.dynamicTypeSize(tamano)
        } else {
            content
        }
    }
}
