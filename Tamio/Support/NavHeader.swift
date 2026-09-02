import SwiftUI

extension View {
    /// Título + subtítulo en la barra de navegación, de forma nativa. En iOS 26
    /// usa `navigationSubtitle` (el sistema lo centra y espacia solo, sin tocar
    /// los bordes); en versiones anteriores cae a solo el título. Sustituye al
    /// `VStack` manual en el toolbar, que se apretaba contra el borde superior.
    @ViewBuilder
    func encabezadoNav(_ titulo: String, _ subtitulo: String) -> some View {
        if #available(iOS 26.0, *) {
            self.navigationTitle(titulo)
                .navigationSubtitle(subtitulo)
                .toolbarBackground(Paleta.brand.opacity(0.12), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            self.navigationTitle(titulo)
        }
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
