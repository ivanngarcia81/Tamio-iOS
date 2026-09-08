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

            // **El pie se encoge hasta la mitad, no hasta tres cuartos.** Con
            // Dynamic Type en AX1 el pie de Ingresos —"19 records ▲172.8%"—
            // se truncaba por los DOS lados a la vez: "19 reco… ▲172.…", o sea
            // ni el conteo ni la variación se podían leer. A 0.75 no daba de
            // sí; a 0.5, el mismo margen que ya se da `AmountText`, entra
            // entero. Encoger un pie de metadatos es preferible a recortarlo:
            // la cifra grande, que es lo que el tamaño accesible viene a
            // agrandar, no se toca.
            pie
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(Esp.tarjeta)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.75)
        )
    }
}
