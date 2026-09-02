import SwiftUI

/// Etiqueta redonda con tinte de color ("Diezmo", "Folio 1042", "Sin
/// depositar"). El color solo aparece aquí porque es dato, no decoración.
struct Pill: View {
    let texto: String
    var color: Color = .gray

    var body: some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}

/// Fila de "campo: valor" del detalle, con un enlace opcional ("Ver ficha").
struct FieldRow: View {
    let label: String
    let value: String
    var link: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value).font(.subheadline)
            Spacer(minLength: 8)
            if let link {
                Text(link).font(.subheadline).foregroundStyle(Paleta.enlace)
            }
        }
        .padding(.vertical, 10)
    }
}

/// Envoltura de tarjeta blanca con borde, para no repetir el fondo redondeado.
struct Tarjeta<Contenido: View>: View {
    @ViewBuilder let contenido: Contenido
    var body: some View {
        contenido
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.75))
    }
}

/// Título de sección en versalitas grises ("RASTRO DE AUDITORÍA").
struct TituloSeccion: View {
    let texto: String
    var body: some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

/// Fila de hub de iPhone: círculo de color con iniciales, título + subtítulo,
/// badge rojo opcional. Diseño fiel al handoff de Tamio iPhone.
struct HubRow: View {
    let iniciales: String
    let color: Color
    let titulo: String
    let subtitulo: String
    var badge: Int? = nil

    var body: some View {
        HStack(spacing: 14) {
            Text(iniciales)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.subheadline.weight(.semibold))
                Text(subtitulo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let badge {
                Text("\(badge)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Paleta.badge, in: Circle())
            }
        }
        .padding(.vertical, 4)
    }
}
