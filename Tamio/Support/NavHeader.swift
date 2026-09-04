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

    /// Tamaño de hoja para formularios: `.form` — angosta y CENTRADA (no ocupa
    /// todo el ancho como `.page`), con altura estándar que ya acomoda todos los
    /// campos con poco scroll. (`.fitted` colapsaba el `Form` interno.)
    func hojaGrande() -> some View {
        presentationSizing(.form)
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
