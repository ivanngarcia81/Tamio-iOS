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
    /// El candado de este aparato. Vive aquí porque tapa la app entera.
    @State private var bloqueo = BloqueoBiometrico.compartido
    @Environment(\.scenePhase) private var fase

    var body: some Scene {
        WindowGroup {
            contenido
                // El velo va PRIMERO y el candado encima: iOS fotografía la
                // pantalla al salir para la tarjeta del conmutador, y esa foto
                // se toma con la app ya en `.inactive`. Sin el velo, el saldo
                // de la iglesia se queda visible ahí aunque esté bloqueada.
                .overlay {
                    if bloqueo.activo && fase != .active {
                        VeloConmutador().transition(.opacity)
                    }
                }
                .overlay {
                    if bloqueo.cerrado {
                        PantallaBloqueo(bloqueo: bloqueo).transition(.opacity)
                    }
                }
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
                    // El candado, antes que nada: una app que arranca con las
                    // cuentas a la vista y las tapa un segundo después no está
                    // protegida, y además ese parpadeo se fotografía.
                    bloqueo.alArrancar()
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
                    // **Los recurrentes al día, ANTES de subir.** Si el mes
                    // cambió mientras la app estaba cerrada, aquí es donde se
                    // registran las rentas de los meses que ya concluyeron; y
                    // poniéndolo antes de sincronizar viajan en la misma
                    // pasada en vez de esperar a la siguiente. No hay tarea
                    // programada de por medio: si la app no se abre en tres
                    // meses, al abrirla se ponen los tres al día de una vez.
                    await MaterializadorRecurrentes.alDia()
                    await MotorSincronizacion.compartido.sincronizar()
                    await CategoriasViewModel.compartido.cargar()
                }
                .onChange(of: fase) { _, nueva in
                    // `.background` y no `.inactive`: lo segundo salta con
                    // bajar el centro de control o con una notificación, y
                    // pedir la cara cada vez que aparece un aviso convierte el
                    // candado en un castigo.
                    if nueva == .background { bloqueo.alIrseAlFondo() }
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
