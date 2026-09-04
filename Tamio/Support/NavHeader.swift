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
        navigationTitle(titulo)
            .navigationSubtitle(subtitulo ?? "")
            .toolbarBackground(Paleta.barra, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
