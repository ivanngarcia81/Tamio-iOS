import SwiftUI

/// Una tarjeta KPI del Dashboard del iPad. Fiel al handoff: **blanca, sin barra
/// de acento de color** (la ley de color manda gris en todo salvo lo
/// seleccionado y las cifras). Rótulo gris arriba, cifra grande, y un pie
/// opcional (variación o enlace).
struct KPICard<Pie: View>: View {
    let titulo: String
    let contenido: AnyView
    let pie: Pie

    init(titulo: String, @ViewBuilder contenido: () -> some View, @ViewBuilder pie: () -> Pie) {
        self.titulo = titulo
        self.contenido = AnyView(contenido())
        self.pie = pie()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            contenido

            pie
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.75)
        )
    }
}
