import SwiftUI

/// **La barra de menús.**
///
/// Solo entran las órdenes que de verdad hacen algo hoy. La maqueta dibuja
/// siete menús completos —"Nuevo depósito…", "Importar aportantes…",
/// "Solicitar segunda firma…"— y todas ésas cuelgan de pantallas que aún no
/// existen en el Mac. **Un menú que no hace nada al pulsarlo es peor que un
/// menú corto**: el atajo se aprende, se usa a ciegas el día que hay prisa, y
/// no pasa nada. Entran cuando entre su pantalla.
struct ComandosTamio: Commands {
    let estado: EstadoVentana
    let sesion: SesionSupabase
    @Environment(\.openWindow) private var abrirVentana
    @State private var prefs = PreferenciasApp.compartidas

    var body: some Commands {

        // MARK: Archivo
        CommandGroup(replacing: .newItem) {
            Button(L.t("Nuevo movimiento…", "New movement…")) {
                abrirVentana(id: CapturaRapida.idVentana)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
        }

        // MARK: Ver
        CommandGroup(after: .toolbar) {
            Button(estado.inspectorAbierto
                   ? L.t("Ocultar inspector", "Hide inspector")
                   : L.t("Mostrar inspector", "Show inspector")) {
                estado.inspectorAbierto.toggle()
            }
            .keyboardShortcut("i", modifiers: .command)

            Divider()

            // La densidad de las filas. Las tres de la maqueta.
            Picker(L.t("Densidad", "Density"), selection: Binding(
                get: { estado.densidad },
                set: { estado.densidad = $0 }
            )) {
                ForEach(EstadoVentana.Densidad.allCases) { d in
                    Text(d.titulo).tag(d)
                }
            }

            Divider()

            // **"Cambiar apariencia" salta entre claro y oscuro, y nunca
            // aterriza en automático.** Quien pulsa ⇧⌘L está pidiendo la otra,
            // no "la que diga el sistema": desde automático se va a oscuro, y
            // de ahí en adelante alterna.
            Button(L.t("Cambiar apariencia", "Switch appearance")) {
                prefs.tema = (prefs.tema == .oscuro) ? .claro : .oscuro
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Picker(L.t("Apariencia", "Appearance"), selection: Binding(
                get: { prefs.tema },
                set: { prefs.tema = $0 }
            )) {
                ForEach(PreferenciasApp.Tema.allCases, id: \.self) { t in
                    Text(t.etiqueta).tag(t)
                }
            }
        }

        // MARK: Cerrar sesión
        //
        // Va en el menú de la app, junto a Configuración, que es donde lo
        // busca cualquiera en un Mac. **Sin atajo a propósito**: cerrar sesión
        // por un resbalón del teclado, a media captura de un domingo, no se
        // puede deshacer con ⌘Z.
        CommandGroup(after: .appSettings) {
            Divider()
            Button(L.t("Cerrar sesión", "Sign out")) {
                Task { await sesion.cerrarSesion() }
            }
        }

        // MARK: Ir
        //
        // La maqueta no dibuja este menú —enseña los ⌘1…⌘9 escritos al lado de
        // cada fila de la barra lateral, y ahí es donde están declarados—.
        // Aquí solo vive Configuración, porque su ⌘, es el del sistema entero
        // y tiene que funcionar aunque la barra lateral esté oculta.
        CommandGroup(replacing: .appSettings) {
            Button(L.t("Configuración…", "Settings…")) {
                estado.seccion = .config
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
