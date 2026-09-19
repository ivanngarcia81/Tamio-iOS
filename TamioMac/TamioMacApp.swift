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

    /// **La base se abre ANTES de dibujar nada**, por el mismo motivo que en
    /// iOS: el aviso de "la base se cayó a memoria" lee un `static` que no es
    /// observable, así que si la caída se descubre después del primer dibujo
    /// el aviso no sale nunca.
    init() {
        _ = BaseLocal.compartida
    }

    var body: some Scene {
        WindowGroup {
            contenido
                .preferredColorScheme(prefs.tema.esquema)
                // Cambiar de idioma reconstruye el árbol: `L.t` son funciones
                // estáticas que cientos de vistas llaman dentro de su `body`,
                // y SwiftUI no tiene forma de saber que su resultado cambió.
                .id(prefs.idioma)
                .task {
                    // La clase de protección de los archivos, lo primero: es
                    // barato y no depende de la sesión.
                    ProteccionArchivos.aplicar()
                    await sesion.restaurar()
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands { ComandosTamio(estado: estado, sesion: sesion) }

        // **Ventana y no hoja.** Se puede dejar abierta mientras se mira la
        // lista de detrás, que es como se captura un domingo de ofrendas.
        Window(L.t("Captura rápida", "Quick capture"), id: CapturaRapida.idVentana) {
            CapturaRapida()
        }
        .defaultSize(width: 596, height: 520)
        .windowResizability(.contentSize)
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
        }
    }
}
