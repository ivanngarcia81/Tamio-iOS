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

/// **La barra ya no se pinta de verde en el teléfono.**
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
/// El verde no se va de la app: pasa a ser el tinte del `.glassProminent` del
/// botón principal, donde tiñe el material en vez de taparlo, y sigue donde ya
/// estaba (montos, fila seleccionada, sidebar activa, chips activos).
///
/// **En iPad se conserva de momento**, a la espera de decisión: ahí la barra no
/// es solo de la lista y quitarle el fondo la deja flotando sobre el material
/// de la cabecera de la columna. Es lo único que queda por decidir de este
/// punto.
private struct EncabezadoNav: ViewModifier {
    let titulo: String
    let subtitulo: String?
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .compact {
            content
                .navigationTitle(titulo)
                .navigationSubtitle(subtitulo ?? "")
        } else {
            content
                .navigationTitle(titulo)
                .navigationSubtitle(subtitulo ?? "")
                .toolbarBackground(Paleta.barra, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
