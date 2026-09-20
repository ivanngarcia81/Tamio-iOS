import SwiftUI

/// **Cartas y traslados, rediseñada para el Mac.**
///
/// Esta NO va a tabla, y es la diferencia con el Registro y con Servicios.
/// Una carta no es una fila: es un documento que sale por la puerta con el
/// membrete de la iglesia, y lo que alguien necesita antes de emitirla es
/// VERLA. La maqueta ya tiene ese patrón montado para Reportes —lista a la
/// izquierda, la hoja a la derecha— y es exactamente el que pide esto.
///
/// En el iPad esa hoja no cabe al lado, así que hay que entrar a otra pantalla
/// para verla. Aquí la lista y el papel conviven: se baja por las cartas con
/// las flechas y el documento se redibuja al lado.
struct PantallaCartas: View {
    let vm: CartasViewModel
    @Binding var seleccion: String?

    private var elegida: CartaEmitida? {
        vm.emitidas.first { $0.id == seleccion }
    }

    var body: some View {
        HSplitView {
            lista
                .frame(minWidth: 240, idealWidth: 300, maxWidth: 380)
            hoja
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - La lista

    private var lista: some View {
        List(vm.emitidas, selection: $seleccion) { c in
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(c.tipo.titulo)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    pastilla(c.estado)
                }
                Text(c.destinatarioNombre.isEmpty
                     ? L.t("Sin destinatario", "No recipient")
                     : c.destinatarioNombre)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(c.folio) · \(Fechas.diaLegible(c.fechaEmision))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.vertical, 3)
            .tag(c.id)
        }
    }

    private func pastilla(_ estado: String) -> some View {
        let tinta = tintaDe(estado)
        return Text(rotuloDe(estado))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tinta)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(tinta.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    /// **Los estados se leen de un texto libre, así que hay un caso por
    /// omisión de verdad.** La app web escribe aquí, y en la base de la
    /// iglesia ya hay un `aprobada` que el comentario del modelo no menciona
    /// —dice `borrador | emitida | entregada`—. Un `switch` sin salida
    /// dejaría esa carta sin pastilla; así al menos enseña lo que diga.
    private func rotuloDe(_ e: String) -> String {
        switch e {
        case "borrador":  return L.t("Borrador", "Draft")
        case "emitida":   return L.t("Emitida", "Issued")
        case "aprobada":  return L.t("Aprobada", "Approved")
        case "entregada": return L.t("Entregada", "Delivered")
        default:          return e.capitalized
        }
    }

    private func tintaDe(_ e: String) -> Color {
        switch e {
        case "borrador":             return Paleta.aviso
        case "emitida", "aprobada":  return Paleta.brand
        case "entregada":            return Paleta.placaPizarra
        default:                     return .secondary
        }
    }

    // MARK: - La hoja

    @ViewBuilder
    private var hoja: some View {
        if let c = elegida {
            ScrollView {
                HojaCarta(carta: c)
                    .padding(28)
            }
            .background(Color.suelo)
        } else {
            ContentUnavailableView {
                Label(L.t("Ninguna carta elegida", "No letter selected"),
                      systemImage: "envelope")
            } description: {
                Text(L.t("Elige una de la lista para verla como saldrá impresa.",
                         "Pick one from the list to see it as it will be printed."))
            }
            .background(Color.suelo)
        }
    }
}

// MARK: - El papel

/// La carta como sale impresa.
///
/// **Siempre en blanco con tinta oscura, también en modo oscuro.** No es un
/// descuido: esto no es una vista de la app, es una previsualización del papel,
/// y el papel es blanco. Pintarla de gris en modo oscuro enseñaría algo que no
/// se corresponde con lo que va a salir de la impresora.
struct HojaCarta: View {
    let carta: CartaEmitida
    @State private var iglesia = ConfiguracionIglesiaViewModel.compartido

    /// Carta en puntos: 8,5" × 72. La misma que usa `PDFExport`.
    private let ancho: CGFloat = 612

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            membrete
            Text(carta.asunto.isEmpty
                 ? carta.tipo.titulo.uppercased()
                 : carta.asunto.uppercased())
                .font(.system(size: 13, weight: .bold))
                .padding(.top, 30)

            if !carta.destinatarioNombre.isEmpty {
                Text(carta.destinatarioNombre)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.top, 16)
            }
            if !carta.destinatarioDireccion.isEmpty {
                Text(carta.destinatarioDireccion)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                    .padding(.top, 2)
            }

            if !carta.saludo.isEmpty {
                Text(carta.saludo)
                    .font(.system(size: 12))
                    .padding(.top, 20)
            }

            // **El cuerpo puede venir vacío en un borrador**, y una hoja con un
            // hueco en medio parece rota. Se dice que está por escribir.
            Text(carta.cuerpo.isEmpty
                 ? L.t("[El cuerpo de la carta todavía está en blanco]",
                       "[The body of this letter is still empty]")
                 : carta.cuerpo)
                .font(.system(size: 12))
                .foregroundStyle(carta.cuerpo.isEmpty
                                 ? Color(red: 0.6, green: 0.6, blue: 0.63)
                                 : Color(red: 0.11, green: 0.11, blue: 0.12))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            if !carta.despedida.isEmpty {
                Text(carta.despedida)
                    .font(.system(size: 12))
                    .padding(.top, 20)
            }

            firmas
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 52)
        .padding(.vertical, 48)
        .frame(width: ancho, alignment: .leading)
        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.12))
        .background(.white)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }

    private var membrete: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(iglesia.config.iniciales)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Paleta.brand,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(iglesia.config.nombre.isEmpty
                     ? L.t("Tu iglesia", "Your church") : iglesia.config.nombre)
                    .font(.system(size: 16, weight: .bold))
                if !lineaDeDireccion.isEmpty {
                    Text(lineaDeDireccion)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(L.t("Folio \(carta.folio)", "Folio \(carta.folio)"))
                Text(Fechas.diaLegible(carta.fechaEmision))
            }
            .font(.system(size: 11))
            .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Paleta.brand).frame(height: 2)
        }
    }

    /// **Las piezas vacías no se imprimen**, que es la misma regla que ya
    /// documenta Configuración para el membrete: el encabezado se cierra sin
    /// renglones en blanco.
    private var lineaDeDireccion: String {
        [iglesia.config.direccion, iglesia.config.ciudad,
         iglesia.config.estado, iglesia.config.idFiscal]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private var firmas: some View {
        if !carta.firmas.isEmpty {
            HStack(alignment: .top, spacing: 40) {
                ForEach(Array(carta.firmas.enumerated()), id: \.offset) { _, f in
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .frame(height: 1)
                        Text(f)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 56)
        }
    }
}
