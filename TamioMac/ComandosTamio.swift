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

    /// Abre el alta de la sección donde estemos; donde no hay ninguna, la
    /// ventana de captura rápida, que es el "nuevo" de Tesorería.
    private func nuevoDeLaSeccion() {
        // **El Registro también tiene alta propia, y es una nota.** Lo único
        // que una persona puede añadir ahí: lo demás lo escribe la app sola.
        // Su botón de la barra ya lo hacía y el atajo abría la captura rápida,
        // que es otra cosa — dos caminos para el mismo sitio dando destinos
        // distintos.
        if estado.seccion == .registro || estado.seccion.altaTitulo != nil {
            estado.pidiendoAlta = true
        } else {
            abrirVentana(id: CapturaRapida.idVentana)
        }
    }

    var body: some Commands {

        // MARK: Archivo
        //
        // Los atajos son los de `handoff7`, que los declara en su manejador de
        // teclado. **⌥⌘N es "lo nuevo de donde estoy"** y no el movimiento: el
        // handoff lo manda a `newForScreen()`, que abre la hoja de la sección y
        // cae en la captura rápida donde no hay ninguna. Por eso el rótulo
        // cambia y el atajo nunca está apagado.
        //
        // El primer intento fue un ⌘N contextual inventado aquí; el handoff ya
        // lo tenía resuelto con ⌥⌘N, que además es lo que un Mac espera para
        // "nuevo" cuando ⌘N no está libre.
        CommandGroup(replacing: .newItem) {
            Button(estado.seccion.altaTituloOMovimiento) { nuevoDeLaSeccion() }
                .keyboardShortcut("n", modifiers: [.command, .option])

            // **Las dos que el handoff pone como globales**, para poder
            // levantar un acta o una carta sin salir de donde estás.
            Button(L.t("Nueva acta…", "New minutes entry…")) {
                estado.seccion = .actas
                estado.pidiendoAlta = true
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            // **⇧⌘T y no el ⇧⌘L del handoff.** Allá ⇧⌘L está en dos sitios a la
            // vez —"New letter…" en Archivo y "Switch appearance" en Ver— y su
            // propio teclado lo manda a cambiar el tema, así que el atajo de la
            // carta no funciona ni en la maqueta. ⇧⌘T (transfer) está libre.
            Button(L.t("Nueva carta…", "New letter…")) {
                estado.seccion = .cartas
                estado.pidiendoAlta = true
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Divider()
            // En Archivo, como lo dibuja el handoff «Trae tus datos» (M6). Ya
            // no cambia de sección: el importador cuelga de la ventana y abre
            // el selector esté donde esté.
            Button(L.t("Importar personas…", "Import people…")) {
                estado.pidiendoImportarAportantes = true
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(!Permisos.vigentes(sesion).administraPadron)
            Button(L.t("Importar aportes…", "Import gifts…")) {
                estado.pidiendoImportarAportes = true
            }
            .disabled(!(Permisos.vigentes(sesion).administraPadron
                        && Permisos.vigentes(sesion).ve(.tesoreria)))
            Button(L.t("Descargar las plantillas…", "Download the templates…")) {
                PlantillaImportar.guardarAmbas()
            }
        }

        // MARK: Ver
        CommandGroup(after: .toolbar) {
            Button(estado.inspectorAbierto
                   ? L.t("Ocultar inspector", "Hide inspector")
                   : L.t("Mostrar inspector", "Show inspector")) {
                estado.inspectorAbierto.toggle()
            }
            .keyboardShortcut("i", modifiers: .command)
            // Apagado donde no hay inspector (Reportes, Configuración, Actas),
            // igual que el botón de la barra: la misma regla, `SeccionMac`.
            .disabled(!estado.seccion.alimentaInspector)

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
        // MARK: Ayuda
        //
        // De los cuatro del handoff solo entra éste: "Tamio Help", "Keyboard
        // shortcuts" y "Contact support" no tienen todavía adónde llevar.
        CommandGroup(before: .help) {
            Button(L.t("Bienvenida a Tamio", "Welcome to Tamio")) {
                estado.viendoBienvenida = true
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button(L.t("Configuración…", "Settings…")) {
                estado.seccion = .config
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
