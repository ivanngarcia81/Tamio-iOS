import SwiftUI

extension View {
    /// Título + subtítulo en la barra de navegación, de forma nativa. En iOS 26
    /// usa `navigationSubtitle` (el sistema lo centra y espacia solo, sin tocar
    /// los bordes); en versiones anteriores cae a solo el título. Sustituye al
    /// `VStack` manual en el toolbar, que se apretaba contra el borde superior.
    /// El subtítulo es opcional: una pantalla que ya enseña ese dato en un
    /// control tocable no tiene que repetirlo aquí (Ingresos decía el mes en
    /// la barra y otra vez en el chip, justo debajo).
    @ViewBuilder
    func encabezadoNav(_ titulo: String, _ subtitulo: String?) -> some View {
        if #available(iOS 26.0, *) {
            self.navigationTitle(titulo)
                .navigationSubtitle(subtitulo ?? "")
                .toolbarBackground(Paleta.brandFill, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            self.navigationTitle(titulo)
        }
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
    @ViewBuilder
    func hojaGrande() -> some View {
        if #available(iOS 26.0, *) {
            self.presentationSizing(.form)
        } else {
            self
        }
    }
}
