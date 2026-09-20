import SwiftUI

/// **Actas, según el handoff**: una rejilla de tarjetas a dos columnas, con el
/// estado, la fecha y quién firma.
///
/// Un acta no es una fila de tabla: lo que se quiere ver de un vistazo es
/// cuáles están firmadas y cuáles esperan una firma, y eso es una propiedad de
/// la tarjeta entera, no de una celda.
struct PantallaActas: View {
    let vm: ActasViewModel
    @Binding var seleccion: String?

    private let columnas = [GridItem(.adaptive(minimum: 320, maximum: 560), spacing: 13)]

    var body: some View {
        ScrollView {
            if vm.lista.isEmpty {
                ContentUnavailableView {
                    Label(L.t("Todavía no hay actas", "No minutes yet"), systemImage: "doc.text")
                } description: {
                    Text(L.t("Las reuniones que se cierren aparecerán aquí.",
                             "Meetings you close will show up here."))
                }
                .padding(.top, 50)
            } else {
                LazyVGrid(columns: columnas, spacing: 13) {
                    ForEach(vm.lista) { tarjeta($0) }
                }
                .padding(20)
            }
        }
    }

    private func tarjeta(_ a: Acta) -> some View {
        let elegida = seleccion == a.id
        return Button { seleccion = a.id } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    Text(a.tituloPersonalizado ?? a.tipo.etiqueta)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(a.estado.etiqueta)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(a.estado.color)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(a.estado.color.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                Text(meta(a))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)

                // El primer acuerdo hace de resumen. Un acta sin acuerdos es
                // una reunión sin decisiones, y también se dice.
                Text(a.items.first?.texto ?? L.t("Sin acuerdos anotados.",
                                                 "No resolutions recorded."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(a.items.isEmpty ? .tertiary : .secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                if !a.firmas.isEmpty {
                    HStack(spacing: 7) {
                        ForEach(a.firmas) { chipDeFirma($0, en: a) }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 13)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(elegida ? Paleta.brandFill : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(elegida ? Paleta.brandStroke : Color.secondary.opacity(0.22),
                        lineWidth: elegida ? 1 : 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// **En su propia función y no dentro del `ForEach`.**
    ///
    /// Dentro de la tarjeta, el compilador se rindió: "unable to type-check
    /// this expression in reasonable time". Es el mismo aviso que ya documenta
    /// `InformesMembresiaViewModel` al armar `porMinisterio`, y la cura es la
    /// misma: sacar la pieza y darle tipos.
    private func chipDeFirma(_ f: FirmaActa, en a: Acta) -> some View {
        let tinta: Color = f.firmado ? Paleta.brand : Paleta.aviso
        // **El nombre no está en la firma.** `FirmaActa` solo guarda el rol y
        // si está firmada; quién ocupa ese rol vive en el acta —`preside` y
        // `secretario`—. El testigo no tiene campo, así que se queda con el
        // rótulo de su rol.
        let quien: String = {
            switch f.rol {
            case .preside:    return a.preside
            case .secretario: return a.secretario
            case .testigo:    return ""
            }
        }()
        let nombre: String = quien.isEmpty ? f.rol.etiqueta : quien
        return HStack(spacing: 4) {
            Image(systemName: f.firmado ? "checkmark" : "clock")
                .font(.system(size: 9, weight: .bold))
            Text(nombre)
                .font(.system(size: 11.5))
                .lineLimit(1)
        }
        .foregroundStyle(tinta)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func meta(_ a: Acta) -> String {
        var piezas: [String] = []
        if !a.fecha.isEmpty { piezas.append(Fechas.diaLegible(a.fecha)) }
        if !a.presentes.isEmpty {
            piezas.append(L.t("\(a.presentes.count) presentes",
                              "\(a.presentes.count) attendees"))
        }
        if !a.folio.isEmpty { piezas.append(L.t("folio \(a.folio)", "folio \(a.folio)")) }
        return piezas.joined(separator: " · ")
    }
}
