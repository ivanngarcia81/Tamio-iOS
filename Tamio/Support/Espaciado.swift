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

    /// **El aire de más que gana una fila en la columna maestra del iPad.**
    /// La fila del teléfono se lee sobre una pantalla entera; la de la columna
    /// se lee en 320 pt contra otras ocho, y con el alto del teléfono las
    /// tarjetas salían flacas. No es un valor suelto: es el único sitio donde
    /// la columna y el teléfono difieren de alto, y por eso tiene nombre.
    static let aireColumna: CGFloat = 4
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

    // MARK: - Radios y altos
    //
    // El espaciado se tokenizó y los radios y los altos se quedaron fuera, así
    // que siguieron escritos a mano. Los Ajustes del iPad solos llevaban ocho
    // radios y seis altos de fila para cuatro roles.

    /// Radio de una tarjeta. Había 18 en el grupo de ajustes y 20 en la tarjeta
    /// grande de la misma pantalla, una encima de la otra y con el mismo rol.
    /// Gana 18, que es el que usan los seis grupos contra la única tarjeta
    /// grande.
    static let radioTarjeta: CGFloat = 18
    /// Alto mínimo de una fila de contenido: un rótulo y su valor o su control,
    /// en un renglón.
    ///
    /// **50 no es el valor más repetido: es el que ya declaraban las piezas.**
    /// `FilaConf` y `FilaEditable` —las dos únicas filas reutilizables de
    /// Ajustes— miden las dos 50, y los 52 eran filas escritas a mano que se
    /// las saltaban.
    static let altoFila: CGFloat = 50
    /// Alto mínimo de un botón de ancho completo dentro de una tarjeta.
    ///
    /// Las cuatro acciones de Ajustes estaban repartidas 2-2 sin criterio:
    /// Invitar y Sincronizar a 52, Cerrar sesión y Respaldar ahora a 54. Gana
    /// **54**, el mayor: una acción no puede ser más baja que una fila de
    /// contenido que solo informa.
    static let altoBoton: CGFloat = 54
    /// Alto mínimo de una fila con subtítulo: baldosa o avatar a la izquierda,
    /// título y segundo renglón debajo.
    static let altoFilaDoble: CGFloat = 64

    // **El radio de una baldosa de icono no es un token, es una proporción**, y
    // por eso no está aquí. Los cinco valores de la app —8 sobre 28 y 30 pt, 9
    // sobre 36, 11 sobre 40, 15 sobre 60— caen todos entre lado × 0.25 y
    // × 0.29, así que ya son una regla coherente. Escribirla como
    // `lado * 0.27` movería cuatro de los cinco (60 pasaría de 15 a 16.2):
    // sería introducir deriva para quitarla.
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
    /// **La fila es tarjeta en los dos aparatos.** Hasta el 11-sep lo era solo
    /// en compacto: en la columna del iPad iba transparente con separador, y
    /// sobre el suelo claro de la columna eso se veía como una pantalla en
    /// blanco sin filas. Medido en captura, suelo y fila eran el mismo
    /// `#FEFEFE`.
    ///
    /// - Parameters:
    ///   - seleccionada: pinta el fondo de selección y la barra lateral.
    ///   - columna: la fila vive en la columna maestra del iPad, no a ancho
    ///     completo. Ahí la tarjeta cuesta ancho de texto —320 pt menos 16 de
    ///     margen y 16 de interior a cada lado dejan 256 para el nombre—, así
    ///     que los dos márgenes bajan un escalón de la escala y la fila gana
    ///     el aire vertical que el teléfono ya tenía de sobra.
    func filaDeLista(seleccionada: Bool, columna: Bool) -> some View {
        modifier(FilaDeLista(seleccionada: seleccionada, columna: columna))
    }
}

private struct FilaDeLista: ViewModifier {
    let seleccionada: Bool
    let columna: Bool

    private var margen: CGFloat { columna ? Esp.hueco : Esp.pantalla }
    private var interior: CGFloat { columna ? Esp.chip : Esp.fila }

    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous)
        return content
            .padding(.horizontal, interior)
            .padding(.vertical, columna ? Esp.aireColumna : 0)
            .background(fondo, in: forma)
            .overlay(alignment: .leading) {
                if seleccionada { Rectangle().fill(Paleta.brand).frame(width: 3) }
            }
            // **Y la selección se DICE, no solo se pinta.** El fondo tintado y
            // la barra verde son toda la señal de cuál es la fila abierta, y a
            // VoiceOver no le llegaba ninguna de las dos: leía las nueve filas
            // iguales. Es lo que ya hacen las tarjetas del informe del padrón.
            .accessibilityAddTraits(seleccionada ? .isSelected : [])
            // Recorta fondo y barra al mismo radio: sueltos, la barra se salía
            // por la esquina de la tarjeta.
            .clipShape(forma)
            .padding(.horizontal, margen)
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
                                      bottom: Esp.hueco, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private var fondo: Color {
        seleccionada ? Paleta.brandFill : Paleta.superficieFila
    }
}
