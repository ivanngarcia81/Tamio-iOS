import SwiftUI

extension View {
    /// Título + subtítulo en la barra de navegación, de forma nativa, con
    /// `navigationSubtitle`: el sistema lo centra y lo espacia solo, sin tocar
    /// los bordes. Sustituye al `VStack` manual en el toolbar, que se apretaba
    /// contra el borde superior.
    /// El subtítulo es opcional: una pantalla que ya enseña ese dato en un
    /// control tocable no tiene que repetirlo aquí (Ingresos decía el mes en
    /// la barra y otra vez en el chip, justo debajo).
    func encabezadoNav(_ titulo: String, _ subtitulo: String?) -> some View {
        modifier(EncabezadoNav(titulo: titulo, subtitulo: subtitulo))
    }

    /// Colchón bajo el contenido scrolleable para que la última fila no quede
    /// pegada al tab bar. Es un `safeAreaInset` y no un `padding` para que el
    /// scroll siga llegando hasta el borde: solo desplaza el área segura.
    func colchonInferior(_ alto: CGFloat = 12) -> some View {
        safeAreaInset(edge: .bottom) { Color.clear.frame(height: alto) }
    }

    // MARK: - Las tres formas de hoja
    //
    // **El tamaño lo pide el CONTENIDO, no la pantalla que la abre.** Antes
    // había tres tratamientos conviviendo sin criterio: quince hojas con
    // `hojaFormulario()`, cuatro con detents escritos a mano y nueve sin declarar
    // nada, saliendo cada una como el sistema decidiera. Estos tres
    // modificadores son la regla, y llevan el nombre de la familia para que al
    // escribir una hoja nueva haya que elegir a cuál pertenece.

    /// **Formulario de captura**: nuevo movimiento, nuevo corte, nuevo
    /// aportante, importar… Todo lo que se rellena y se guarda.
    ///
    /// `.form` es angosta y CENTRADA (no ocupa todo el ancho como `.page`), con
    /// altura estándar que ya acomoda los campos con poco scroll. (`.fitted`
    /// colapsaba el `Form` interno.) En iPhone sale casi a pantalla completa,
    /// que es lo que un formulario necesita; en iPad, centrada.
    func hojaFormulario() -> some View {
        presentationSizing(.form)
    }

    /// **Elección corta**: filtros, un rango de fechas, un selector. Se abre,
    /// se elige y se cierra.
    ///
    /// Dos detents SIEMPRE, nunca uno: con uno solo, una lista que no cabe se
    /// corta y no hay a dónde arrastrar — las últimas opciones quedan
    /// inalcanzables, que es lo que pasaba en la hoja de filtros. `grande`
    /// arranca en `.large` cuando el contenido no cabe en media pantalla: una
    /// hoja que nace cortada es lo mismo que no poder crecer.
    ///
    /// El material va más opaco que el de por omisión porque el sistema
    /// desenfoca lo de detrás pero no le baja el contraste, y sobre una lista
    /// de montos verdes y badges naranjas el texto de las opciones competía con
    /// la fila de debajo.
    func hojaEleccion(grande: Bool = false) -> some View {
        modifier(HojaEleccion(grande: grande))
    }

    /// **Documento o previa**: el PDF de un reporte, una constancia, la vista
    /// previa de una carta. No se rellena nada: se mira y se comparte.
    ///
    /// `.page` y no `.form`: un documento se lee a lo ancho, y recortarlo a la
    /// anchura de un formulario obligaría a escalar la hoja de papel todavía
    /// más de lo que ya la escala la previa.
    func hojaDocumento() -> some View {
        presentationSizing(.page)
    }
}

/// El tamaño de una hoja de elección. Es un `ViewModifier` y no una cadena de
/// modificadores sueltos porque el detent vigente necesita estado propio: sin
/// `selection`, `presentationDetents` no puede abrir en grande y dejar que el
/// usuario la baje después.
private struct HojaEleccion: ViewModifier {
    let grande: Bool
    @State private var detent: PresentationDetent = .medium

    func body(content: Content) -> some View {
        content
            .presentationDetents([.medium, .large], selection: $detent)
            .presentationDragIndicator(.visible)
            .presentationBackground(.thickMaterial)
            .onAppear { detent = grande ? .large : .medium }
            .onChange(of: grande) { _, g in detent = g ? .large : .medium }
    }
}

/// **La barra ya no se pinta de verde.**
///
/// Un color liso es la superficie sobre la que el glass menos puede funcionar:
/// necesita contenido con textura pasando por detrás para refractar, y sobre un
/// relleno plano se resuelve como una cápsula gris pegada encima de un
/// rectángulo de color. Ese es el halo doble que se le veía al botón "Nuevo".
/// Sin fondo, lo que se difumina bajo las cápsulas son las filas de la lista al
/// desplazarse, que es lo que hace que se vea vivo — y por eso este cambio no
/// se sostiene sin el recapado del scroll del bloque anterior: quitar el verde
/// sin nada que pase por debajo solo deja la barra vacía.
///
/// El verde no se va de la app: pasa al SÍMBOLO del botón principal, sobre una
/// cápsula de glass limpia, y sigue donde ya estaba (montos, fila
/// seleccionada, sidebar activa, chips activos).
///
/// **También en iPad**, donde había una razón de más para quitarlo: allí el
/// maestro-detalle es un `HStack` dentro de un solo `NavigationStack`, así que
/// la barra no pertenece a la columna sino a la pantalla entera. El listón
/// verde cruzaba por encima del panel de detalle, donde no encabezaba nada
/// —un rectángulo de color sobre la ficha, que ya trae su propio titular— y
/// arrancaba por encima del `Divider` vertical, soldando visualmente las dos
/// mitades justo por encima de la única línea que dice que son dos.
///
/// Lo que sí se queda en iPad es la tira de controles de la columna con su
/// material: es lo que la lista atraviesa al desplazarse. Antes había dos
/// bandas apiladas, el verde y esa; ahora queda una.
private struct EncabezadoNav: ViewModifier {
    let titulo: String
    let subtitulo: String?

    func body(content: Content) -> some View {
        content
            .navigationTitle(titulo)
            .navigationSubtitle(subtitulo ?? "")
    }
}
