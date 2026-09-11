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
    /// Se lee de `UserDefaults` al arrancar y se guarda al terminar el
    /// recorrido. Es `@State` para que la raíz se redibuje al cambiarla: la
    /// propiedad estática sola no es observable.
    @State private var bienvenidaVista = PreferenciasApp.bienvenidaVista
    /// Si hay que pedir la configuración inicial de la iglesia. Lo decide
    /// `decidirConfiguracionInicial()`, y solo después de la primera bajada.
    @State private var pedirConfiguracion = false
    @Environment(\.scenePhase) private var fase

    /// **Abrir la base ANTES de dibujar nada.**
    ///
    /// `BaseLocal.compartida` es perezosa: se construye la primera vez que
    /// alguien la toca, que hasta ahora era dentro del `.task` de más abajo, o
    /// sea **después** del primer dibujo. La franja que avisa de que la base se
    /// cayó a memoria (`RootView.avisoBaseCaida`) lee un `static`, no algo
    /// observable, así que si la caída se descubre después del primer dibujo el
    /// aviso no aparece nunca. Forzándola aquí el estado está decidido antes de
    /// que exista la primera vista, y la franja sale a la primera.
    ///
    /// **También en modo revisión**, aunque ahí los datos los sirvan los
    /// `Mock*`. Cuesta lo mismo, y hace que una migración rota se vea al
    /// arrancar en vez de esconderse: el §3 del traspaso decía "en modo revisión
    /// la base ni se abre", y era justo lo que impedía notarlo.
    init() {
        _ = BaseLocal.compartida
    }

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

    /// La regla, con su porqué, en `ConfiguracionInicialView.haceFalta`.
    private func decidirConfiguracionInicial() {
        pedirConfiguracion = ConfiguracionInicialView.haceFalta(
            nombre: ConfiguracionIglesiaViewModel.compartido.config.nombre,
            ultimaSincronizacion: MotorSincronizacion.compartido.ultimaSincronizacion,
            yaConfigurado: PreferenciasApp.iglesiaConfigurada,
            baseCaida: BaseLocal.caida != nil)
    }

    @ViewBuilder
    private var contenido: some View {
        Group {
            switch sesion.estado {
            case .comprobando:
                ProgressView()
                    .task { await sesion.restaurar() }
            case .sinSesion:
                // **La bienvenida ANTES de las credenciales.** Pedirle la
                // contraseña a alguien que todavía no sabe qué es esto es
                // pedirle que confíe a ciegas; y sin sesión no se puede
                // enseñar nada más, porque RLS exige `auth.uid()`.
                if bienvenidaVista {
                    AccesoView(sesion: sesion)
                } else {
                    BienvenidaView {
                        PreferenciasApp.bienvenidaVista = true
                        bienvenidaVista = true
                    }
                        .transition(.opacity)
                }
            case .autenticada:
                VStack(spacing: 0) {
                    // La base caída va PRIMERO: el modo revisión es una nota
                    // para quien desarrolla, esta es la que le cuesta el día a
                    // la tesorera.
                    RootView.avisoBaseCaida
                    RootView.avisoRevision
                    RootView()
                }
                .environment(sesion)
                .environment(navegacion)
                // **La configuración inicial, encima y sin poder esquivarla.**
                // Va aquí y no dentro de `RootView` porque tapa la app entera:
                // una iglesia sin nombre no tiene membrete, así que cualquier
                // PDF que se emitiera antes saldría sin encabezado.
                .fullScreenCover(isPresented: $pedirConfiguracion) {
                    ConfiguracionInicialView { pedirConfiguracion = false }
                }
                // Al entrar y cada vez que la app vuelve al frente: es cuando
                // más probable es que haya red otra vez tras un rato sin ella.
                .task {
                    // El candado, antes que nada: una app que arranca con las
                    // cuentas a la vista y las tapa un segundo después no está
                    // protegida, y además ese parpadeo se fotografía.
                    bloqueo.alArrancar()
                    // **La clase de protección de los archivos, antes de nada
                    // más.** Es barato y no depende de la sesión; y si el
                    // aparato se bloquea a media sincronización, lo que ya
                    // estaba abierto sigue funcionando. Ver `ProteccionArchivos`.
                    ProteccionArchivos.aplicar()
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
                    // **Los recurrentes al día, DESPUÉS de sincronizar**, y no
                    // antes: la idempotencia vive en `ultimoMesGenerado`, y esa
                    // marca la puede haber movido otro aparato. Materializando
                    // primero, el iPhone y el iPad registrarían cada uno la
                    // renta del mismo mes sin saberlo. Bajar antes es lo que
                    // hace que la marca sea de la iglesia y no del aparato.
                    //
                    // Si el mes cambió mientras la app estaba cerrada, aquí es
                    // donde se registran los meses ya concluidos. No hay tarea
                    // programada de por medio: si la app no se abre en tres
                    // meses, al abrirla se ponen los tres al día de una vez.
                    // **Aquí y no antes.** La iglesia se juzga vacía DESPUÉS
                    // de bajar: `cargar()` de arriba lee la base local, que en
                    // el primer arranque de un aparato está en blanco aunque el
                    // servidor tenga tres años de datos. Preguntar antes le
                    // pediría al segundo miembro de una iglesia ya montada que
                    // la configurara otra vez, y de paso pisaría su nombre.
                    decidirConfiguracionInicial()
                    let hecho = await MaterializadorRecurrentes.alDia()
                    // Y una segunda vuelta SOLO si de verdad se generó algo,
                    // para que las rentas nuevas no esperen al próximo arranque
                    // para llegar al servidor.
                    if hecho.generados > 0 {
                        await MotorSincronizacion.compartido.sincronizar()
                    }
                    await CategoriasViewModel.compartido.cargar()
                }
                .onChange(of: fase) { _, nueva in
                    // `.background` y no `.inactive`: lo segundo salta con
                    // bajar el centro de control o con una notificación, y
                    // pedir la cara cada vez que aparece un aviso convierte el
                    // candado en un castigo.
                    if nueva == .background { bloqueo.alIrseAlFondo() }
                    if nueva == .active {
                        // **La cara se pide AQUÍ, no al aparecer la pantalla de
                        // bloqueo.** Esa pantalla se pone al irse al fondo, así
                        // que su `.task` preguntaba con la app todavía detrás y
                        // el sistema devolvía `notInteractive`; el diálogo no
                        // salía y en su lugar quedaba el error. Al volver al
                        // frente sí se puede preguntar. El `.task` se queda
                        // para el arranque en frío, donde este `onChange` no
                        // llega a dispararse.
                        if bloqueo.cerrado { Task { await bloqueo.abrir() } }
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
