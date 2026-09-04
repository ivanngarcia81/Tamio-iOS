import SwiftUI

/// **La escala de espaciado de la app.** Sin valores intermedios.
///
/// Antes había quince márgenes horizontales distintos repartidos en 138 usos
/// —16, 12, 18, 14, 13, 11, 10, 9…—, y diferencias de uno o dos puntos no son
/// decisiones de diseño sino deriva: son la razón por la que los bordes no se
/// alineaban entre las secciones de una misma pantalla.
///
/// 16 pt es el valor más usado y el margen estándar de iOS, así que es el que
/// rompe menos. Los tres roles —margen de pantalla, interior de tarjeta,
/// interior de fila— comparten número pero no significado: se nombran aparte
/// para que un cambio de uno no arrastre a los otros.
enum Esp {
    /// Margen lateral de pantalla. El borde contra el que todo se alinea.
    static let pantalla: CGFloat = 16
    /// Padding interior de una tarjeta.
    static let tarjeta: CGFloat = 16
    /// Padding interior de una fila de lista.
    static let fila: CGFloat = 16
    /// Margen interior de un panel de detalle: el contenido de un `ScrollView`
    /// a pantalla completa o de la columna derecha del maestro-detalle. 16 se
    /// queda corto ahí, así que es un rol propio y no un valor suelto — pero
    /// era UNO, no dos: había veinte usos de 24 y nueve de 20 haciendo
    /// exactamente lo mismo, más un 22 y un 28 sueltos.
    static let panel: CGFloat = 24

    /// Margen de una hoja impresa (los PDF de reporte y constancia). No es
    /// espaciado de interfaz: es el margen del papel.
    static let hoja: CGFloat = 40

    /// Padding interior de una píldora o chip.
    static let chip: CGFloat = 12
    /// Separación entre elementos hermanos.
    static let hueco: CGFloat = 8

    /// Radio de la tarjeta de fila, para que el fondo, el recorte y la barra de
    /// selección compartan el mismo.
    static let radioFila: CGFloat = 10

    // MARK: - Maestro-detalle

    /// A partir de este ancho caben la columna maestra y el detalle a la vez;
    /// por debajo, la lista ocupa la pantalla y el detalle se empuja. Estaba
    /// escrito como `640` en las once pantallas que lo usan.
    static let anchoMaestroDetalle: CGFloat = 640

    /// Ancho de la columna maestra. Había **siete** valores para el mismo rol
    /// —296, 300, 320, 340, 360, 380 y 400— y todos detrás del mismo
    /// breakpoint, así que la diferencia no respondía a nada: al pasar de una
    /// pantalla a otra el detalle daba un salto lateral de hasta 104 pt.
    static let columnaMaestra: CGFloat = 320

    /// La excepción: las filas de "Por revisar" son tarjetas con tres botones
    /// dentro (Aprobar · Devolver · Pedir dato) y a 320 se apilan.
    static let columnaMaestraAncha: CGFloat = 400
}

extension View {
    /// Cierra una fila de lista: margen, fondo de tarjeta y estado seleccionado.
    ///
    /// **Por qué existe.** Las ocho listas de la app usaban
    /// `sizeClass == .regular ? .plain : .insetGrouped`. En iPhone,
    /// `insetGrouped` aplica su propio inset lateral —unos 20 pt— que no
    /// respeta el padding del contenedor, así que las tarjetas de la lista
    /// quedaban un escalón más metidas que la cabecera y el pie de la misma
    /// pantalla, que sí lo respetan. Ahora las ocho van en `.plain` y el margen
    /// lo pone la app, con `Esp.pantalla`, en un solo sitio.
    ///
    /// Es también el arreglo de fondo del rectángulo plano que asomaba al
    /// deslizar y de la barra de selección que se salía por la esquina: los
    /// tres eran el mismo conflicto entre `insetGrouped` y una tarjeta dibujada
    /// a mano.
    ///
    /// - Parameters:
    ///   - seleccionada: pinta el fondo de selección y la barra lateral.
    ///   - tarjeta: en compacto la fila **es** una tarjeta sobre el fondo
    ///     agrupado; en la columna de iPad va transparente sobre el material de
    ///     la columna, con separador, como hasta ahora.
    func filaDeLista(seleccionada: Bool, tarjeta: Bool) -> some View {
        modifier(FilaDeLista(seleccionada: seleccionada, tarjeta: tarjeta))
    }
}

private struct FilaDeLista: ViewModifier {
    let seleccionada: Bool
    let tarjeta: Bool

    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous)
        return content
            .padding(.horizontal, tarjeta ? Esp.fila : Esp.pantalla)
            .background(fondo, in: forma)
            .overlay(alignment: .leading) {
                if seleccionada { Rectangle().fill(Paleta.brand).frame(width: 3) }
            }
            // Recorta fondo y barra al mismo radio: sueltos, la barra se salía
            // por la esquina de la tarjeta.
            .clipShape(forma)
            .padding(.horizontal, tarjeta ? Esp.pantalla : 0)
            // **La separación entre tarjetas vive aquí, no en cada `List`.**
            // Sin esto el espacio entre filas salía del comportamiento por
            // omisión del `List`: entre grupos de día había aire —lo pone la
            // cabecera de sección— pero DENTRO del grupo las tarjetas se
            // tocaban, cantos redondeados contra cantos redondeados. Ni lista
            // agrupada ni tarjetas sueltas.
            //
            // Va en el modificador porque es lo que comparten las nueve listas
            // de la app: puesto en cada `List`, se separan solas en cuanto
            // alguien añade la décima.
            .listRowInsets(EdgeInsets(top: 0, leading: 0,
                                      bottom: tarjeta ? Esp.hueco : 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(tarjeta ? .hidden : .automatic)
    }

    private var fondo: Color {
        if seleccionada { return Paleta.brandFill }
        return tarjeta ? Paleta.superficieFila : .clear
    }
}
