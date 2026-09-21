import SwiftUI

/// **El arranque de la app de Mac.**
///
/// Monta el mismo entorno que `TamioApp` en iOS —la base local antes de
/// dibujar, la sesión, las preferencias— y le añade lo que solo existe aquí:
/// la barra de menús y la ventana de captura rápida.
@main
struct TamioMacApp: App {
    /// Decide qué se muestra: sin ella los repositorios reales no pueden leer
    /// nada, porque RLS exige `auth.uid()`.
    @State private var sesion = SesionSupabase()
    @State private var navegacion = Navegacion()
    @State private var prefs = PreferenciasApp.compartidas
    /// Lo que solo sabe una ventana de Mac: inspector, filtro, densidad.
    @State private var estado = EstadoVentana()
    /// El candado de este Mac. Vive aquí porque tapa la app entera.
    @State private var bloqueo = BloqueoBiometrico.compartido

    /// **La base se abre ANTES de dibujar nada**, por el mismo motivo que en
    /// iOS: el aviso de "la base se cayó a memoria" lee un `static` que no es
    /// observable, así que si la caída se descubre después del primer dibujo
    /// el aviso no sale nunca.
    init() {
        _ = BaseLocal.compartida
    }

    var body: some Scene {
        WindowGroup {
            // **El candado SUSTITUYE a la app, no la tapa.** Con un `.overlay`
            // la barra de herramientas seguía a la vista y se podía pulsar:
            // SwiftUI la sube al marco de la ventana, así que ninguna vista de
            // dentro la cubre. Medido — con la app bloqueada, el ⌘N y el
            // selector de periodo respondían. Quitando la pantalla del árbol no
            // queda nada detrás que pulsar.
            //
            // **Aquí NO hay velo del conmutador.** En iOS hace falta porque el
            // sistema fotografía la pantalla al salir para la tarjeta del
            // multitarea; macOS no guarda esa foto, y Mission Control enseña la
            // ventana en vivo —ya sustituida por el candado—.
            Group {
                if bloqueo.cerrado {
                    CandadoMac(bloqueo: bloqueo)
                        .frame(minWidth: 520, minHeight: 360)
                } else {
                    contenido
                }
            }
                .preferredColorScheme(prefs.tema.esquema)
                // Cambiar de idioma reconstruye el árbol: `L.t` son funciones
                // estáticas que cientos de vistas llaman dentro de su `body`,
                // y SwiftUI no tiene forma de saber que su resultado cambió.
                .id(prefs.idioma)
                .task {
                    // La clase de protección de los archivos, lo primero: es
                    // barato y no depende de la sesión.
                    ProteccionArchivos.aplicar()
                    bloqueo.alArrancar()
                    await sesion.restaurar()
                }
                // **El candado del Mac se echa al bloquearse la pantalla, NO al
                // cambiar de app.**
                //
                // En iOS se echa al irse al fondo, y allí eso pasa cuando uno
                // guarda el teléfono. Aquí pasa cada vez que se mira el correo:
                // pedir la huella para volver a Tamio veinte veces por mañana
                // convierte el candado en un castigo, que es la misma razón por
                // la que iOS no lo echa en `.inactive`. Las dos señales de que
                // el Mac se queda solo de verdad son que se bloquee la sesión y
                // que se duerma la pantalla.
                .task { await vigilarElBloqueoDePantalla() }
        }
        .defaultSize(width: 1280, height: 820)
        .commands { ComandosTamio(estado: estado, sesion: sesion) }

        // **Ventana y no hoja.** Se puede dejar abierta mientras se mira la
        // lista de detrás, que es como se captura un domingo de ofrendas.
        Window(L.t("Captura rápida", "Quick capture"), id: CapturaRapida.idVentana) {
            // Se le pasan el estado y la sesión: el primero para avisar a la
            // ventana de atrás de que relea, la segunda para firmar el rastro
            // de auditoría con quien de verdad está capturando.
            // La captura rápida es otra escena, así que el candado de la
            // ventana principal no la alcanza: el ⌥⌘N del menú la abriría con
            // la app bloqueada. Lleva el suyo.
            Group {
                if bloqueo.cerrado {
                    CandadoMac(bloqueo: bloqueo)
                } else {
                    CapturaRapida(estado: estado, sesion: sesion)
                }
            }
            .preferredColorScheme(prefs.tema.esquema)
        }
        .defaultSize(width: 596, height: 520)
        .windowResizability(.contentSize)
    }

    /// Las dos señales de AppKit que sí significan "aquí no queda nadie". Van
    /// por el centro de notificaciones del `NSWorkspace`, que es el que las
    /// publica; el del `NotificationCenter.default` no las ve.
    private func vigilarElBloqueoDePantalla() async {
        let centro = NSWorkspace.shared.notificationCenter
        await withTaskGroup(of: Void.self) { grupo in
            for nombre in [NSWorkspace.screensDidSleepNotification,
                           NSWorkspace.sessionDidResignActiveNotification] {
                grupo.addTask { @MainActor in
                    for await _ in centro.notifications(named: nombre) {
                        bloqueo.alIrseAlFondo()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contenido: some View {
        switch sesion.estado {
        case .comprobando:
            // Mientras se mira si hay sesión guardada del arranque anterior.
            ProgressView()
                .frame(minWidth: 520, minHeight: 360)

        case .sinSesion:
            AccesoMac(sesion: sesion)
                .frame(minWidth: 520, minHeight: 480)

        case .autenticada:
            VentanaPrincipal()
                .environment(sesion)
                .environment(navegacion)
                .environment(estado)
                .task {
                    // **En este orden, y es el mismo que el de iOS.**
                    //
                    // La configuración de la iglesia primero: de ella salen el
                    // membrete, la moneda y los permisos, y hay pantallas que
                    // los leen antes de que nadie pase por Configuración. Las
                    // categorías ANTES de sincronizar, porque alimentan los
                    // selectores; y otra vez después, porque la bajada puede
                    // traer alguna nueva.
                    await ConfiguracionIglesiaViewModel.compartido.cargar()
                    await CategoriasViewModel.compartido.cargar()
                    await MotorSincronizacion.compartido.sincronizar()
                    await CategoriasViewModel.compartido.cargar()
                    // **Y ahora se avisa a las pantallas.** La sincronización
                    // escribe en la base por debajo; sin esto, una tabla que
                    // cargó mientras bajaban los datos se queda enseñando lo
                    // que había antes —en un Mac recién estrenado, nada— hasta
                    // que alguien cambia de sección y vuelve.
                    estado.recargar()
                }
                // **Y otra vez cada vez que la app vuelve al frente.**
                //
                // Esto existía en iOS (`onChange(of: fase)` con `.active`) y
                // aquí no. Con una sola vuelta, la del arranque, lo capturado
                // se quedaba en el `outbox` hasta que alguien cerrara y
                // abriera la app —medido: `intentos = 0`, o sea que ni se
                // intentaba—. Una ventana de Mac se queda abierta días, así
                // que eso es un domingo entero de ofrendas sin salir de aquí.
                .task {
                    let vueltas = NotificationCenter.default.notifications(
                        named: NSApplication.didBecomeActiveNotification)
                    for await _ in vueltas {
                        await MotorSincronizacion.compartido.sincronizar()
                        estado.recargar()
                    }
                }
        }
    }
}
