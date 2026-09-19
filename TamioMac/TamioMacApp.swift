import SwiftUI

/// **El arranque de la app de Mac.**
///
/// Monta el mismo entorno que `TamioApp` en iOS —la base local antes de
/// dibujar, las preferencias, la navegación— y le añade lo que solo existe
/// aquí: la barra de menús y la ventana de captura rápida.
@main
struct TamioMacApp: App {
    /// Igual que en iOS: decide qué se muestra, porque sin ella los
    /// repositorios reales no pueden leer nada (RLS exige `auth.uid()`).
    @State private var sesion = SesionSupabase()
    /// Compartida con iOS. Aquí todavía no la mueve nadie, pero es la que
    /// leerán las pantallas cuando se escriban.
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
            VentanaPrincipal()
                .environment(sesion)
                .environment(navegacion)
                .environment(estado)
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
                    await ConfiguracionIglesiaViewModel.compartido.cargar()
                    await CategoriasViewModel.compartido.cargar()
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands { ComandosTamio(estado: estado) }

        // **Ventana y no hoja.** Se puede dejar abierta mientras se mira la
        // lista de detrás, que es como se captura un domingo de ofrendas.
        Window(L.t("Captura rápida", "Quick capture"), id: CapturaRapida.idVentana) {
            CapturaRapida()
        }
        .defaultSize(width: 596, height: 520)
        .windowResizability(.contentSize)
    }
}
