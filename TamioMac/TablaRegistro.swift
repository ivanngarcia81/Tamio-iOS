import SwiftUI

/// **El Registro, rediseñado para el Mac.**
///
/// En el iPad es una lista agrupada por día, con las tarjetas apiladas. Aquí
/// es una TABLA, que es el patrón que la maqueta usa para todo lo que es una
/// sucesión de hechos con las mismas casillas — y un registro de auditoría es
/// exactamente eso.
///
/// Lo que se gana al cambiar de forma, y que en el iPad no existe: ordenar por
/// quién lo hizo para ver todo lo de una persona junto, o por área para separar
/// Tesorería de Secretaría. Auditar es cruzar, y cruzar necesita columnas.
struct TablaRegistro: View {
    let vm: RegistroViewModel
    @Binding var seleccion: Set<Apunte.ID>

    /// Lo más reciente arriba: un registro se lee por el final.
    @State private var orden = [KeyPathComparator(\Apunte.creadoEn, order: .reverse)]

    private var filas: [Apunte] { vm.visibles.sorted(using: orden) }

    var body: some View {
        Table(filas, selection: $seleccion, sortOrder: $orden) {

            TableColumn(L.t("Cuándo", "When"), value: \.creadoEn) { a in
                Text(a.creadoEn.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .foregroundStyle(.secondary)
            }
            .width(min: 110, ideal: 132, max: 180)

            TableColumn(L.t("Área", "Area"), value: \.ordenDeArea) { a in
                Text(a.esNota ? L.t("Nota", "Note") : a.area.etiqueta)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(a.esNota ? Paleta.placaPizarra : Paleta.brand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((a.esNota ? Paleta.placaPizarra : Paleta.brand).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .width(min: 84, ideal: 104, max: 140)

            TableColumn(L.t("Qué pasó", "What happened"), value: \.texto) { a in
                HStack(spacing: 8) {
                    // **La alerta va delante del texto, no al final.** Un
                    // descuadre o un movimiento dado de baja son las dos cosas
                    // que alguien busca al abrir esto; enterrarlas al final de
                    // una frase larga las esconde justo cuando importan.
                    if let aviso = a.tipo.etiquetaAlerta {
                        Text(aviso)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Paleta.negativo)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Paleta.negativo.opacity(0.14),
                                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    Text(a.texto).lineLimit(1)
                }
            }
            .width(min: 240, ideal: 520)

            TableColumn(L.t("Quién", "Who"), value: \.autor) { a in
                Text(a.autor.isEmpty ? "—" : a.autor)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 170, max: 260)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

extension Apunte {
    /// Para ordenar por la columna de área. Las notas al final: son lo que
    /// alguien escribió a mano, no lo que la app registró sola.
    var ordenDeArea: Int {
        if esNota { return 2 }
        return area == .tesoreria ? 0 : 1
    }
}

// MARK: - Escribir una nota

/// La única cosa que se puede AÑADIR a un registro de auditoría: una nota
/// humana. Lo demás lo escribe la app sola y no se toca.
struct NuevaNotaMac: View {
    let vm: RegistroViewModel
    let autor: String

    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @State private var area: ApunteArea = .tesoreria
    @State private var guardando = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("Nueva nota", "New note"))
                .font(.system(size: 17, weight: .bold))

            Text(L.t("Queda en el registro con tu nombre y la hora. No se puede borrar.",
                     "It stays in the log with your name and the time. It can't be deleted."))
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(L.t("Quién la ve", "Who sees it"), selection: $area) {
                Text(L.t("Tesorería", "Treasury")).tag(ApunteArea.tesoreria)
                Text(L.t("Secretaría", "Secretary")).tag(ApunteArea.secretaria)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextEditor(text: $texto)
                .font(.system(size: 13))
                .frame(height: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            HStack {
                Spacer()
                Button(L.t("Cancelar", "Cancel")) { cerrar() }
                    .keyboardShortcut(.cancelAction)
                Button(L.t("Anotar", "Add")) {
                    guardando = true
                    Task {
                        await vm.escribirNota(
                            texto: texto.trimmingCharacters(in: .whitespacesAndNewlines),
                            area: area, autor: autor)
                        cerrar()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Paleta.brand)
                .disabled(guardando || texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
