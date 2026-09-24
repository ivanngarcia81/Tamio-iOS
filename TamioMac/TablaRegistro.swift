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
    @Environment(EstadoVentana.self) private var estado
    @Binding var seleccion: Set<Apunte.ID>

    /// Lo más reciente arriba: un registro se lee por el final.
    @State private var orden = [KeyPathComparator(\Apunte.creadoEn, order: .reverse)]

    /// **El alta del Registro es una nota**, y la presenta esta pantalla como
    /// las demás presentan la suya. Lo único que una persona puede añadir aquí:
    /// el resto lo escribe la app sola y no se toca.
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    private var filas: [Apunte] { vm.visibles.sorted(using: orden) }

    var body: some View {
        // **El `Table` va dentro de un contenedor, y no suelto.**
        //
        // Con la hoja de nota colgada directamente del `Table`, abrirla creaba
        // una ventana de más: un `AXDialog` de 280×168, transparente y vacío,
        // que se quedaba fuera de la pantalla. Medido con `count of windows`
        // antes y después; solo pasaba aquí, donde la raíz de la pantalla es un
        // `Table`. Con el contenedor de por medio, la hoja se presenta sobre
        // una vista normal y no hay ventana fantasma.
        VStack(spacing: 0) {
            tabla
            Divider()
            pie
        }
        .sheet(isPresented: Binding(
            get: { estado.pidiendoAlta },
            set: { estado.pidiendoAlta = $0 }
        )) {
            NuevaNotaMac(vm: vm, autor: sesion?.perfil.firma ?? "")
        }
    }

    /// **A media pantalla la tabla suelta una columna y estrecha el resto**
    /// (handoff 9: «a 900 pt cada tabla suelta la columna que ya está en el
    /// inspector»). `Table` nace en el ancho ideal de sus columnas y no las
    /// encoge, así que por debajo de esa suma las últimas quedaban fuera de la
    /// vista. `ViewThatFits` y no medir el ancho, como en `TablaMovimientos`.
    private static let anchoCompleto: CGFloat = 132 + 104 + 520 + 170 + 4 * 17 + 20

    private var tabla: some View {
        ViewThatFits(in: .horizontal) {
            tabla(estrecha: false)
                .frame(minWidth: 0, idealWidth: Self.anchoCompleto, maxWidth: .infinity, maxHeight: .infinity)
            tabla(estrecha: true)
        }
    }

    private func tabla(estrecha: Bool) -> some View {
        Table(filas, selection: $seleccion, sortOrder: $orden) {

            TableColumn(L.t("Cuándo", "When"), value: \.creadoEn) { a in
                Text(a.creadoEn.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .foregroundStyle(.secondary)
                    .frame(height: estado.altoDeFila)
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
            .width(min: 84, ideal: estrecha ? 96 : 104, max: 140)

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
            .width(min: 200, ideal: estrecha ? 300 : 520)

            // Quién lo hizo ya sale en el inspector: es la que se suelta.
            if !estrecha {
                TableColumn(L.t("Quién", "Who"), value: \.autor) { a in
                    Text(a.autor.isEmpty ? "—" : a.autor)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .width(min: 120, ideal: 170, max: 260)
            }
        }
        // **Sin rayas alternas, y no es capricho.**
        //
        // `alternatesRowBackgrounds` las pinta en TODO el alto de la tabla,
        // también donde no hay datos: con dos movimientos en pantalla, la
        // ventana se llenaba de cuarenta renglones rayados vacíos. El handoff
        // alterna solo las filas que existen y deja el resto limpio, y entre
        // las dos cosas la que más se parece es no alternar.
        .tableStyle(.inset)
        // **El vacío dice qué hacer, y el pie por qué esto no se edita.**
        //
        // Los dos son del handoff. El vacío del Registro no es "no hay nada":
        // casi siempre es que el filtro de arriba lo esconde, y decirlo evita
        // buscar un fallo donde hay un filtro. El pie explica la regla que hace
        // que esto sirva para auditar.
        .overlay {
            if filas.isEmpty { vacio }
        }
    }

    private var vacio: some View {
        VStack(spacing: 5) {
            Text(L.t("Nada con este filtro", "Nothing with this filter"))
                .font(.system(size: 13, weight: .semibold))
            Text(L.t("Cambia el filtro de arriba para ver el resto del registro.",
                     "Change the filter above to see the rest of the log."))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.suelo)
    }

    private var pie: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L.t("El registro guarda copias, no referencias",
                     "The log keeps copies, not references"))
                .font(.system(size: 11.5, weight: .semibold))
            // **Sin `fixedSize`**: con el pie colgado de un `safeAreaInset`
            // sobre la `Table`, ese modificador hacía que el texto se midiera a
            // ancho cero y pidiera alto para apilar letra a letra — la ventana
            // se estiraba a 2574 puntos y dejaba de poder achicarse. Medido con
            // `set size` antes y después.
            Text(L.t("Cada apunte conserva el nombre y el folio tal como estaban en ese momento, así que sigue diciendo la verdad aunque la fila a la que se refiere ya no exista. Aquí no se edita ni se borra nada: eso es lo que lo hace un registro.",
                     "Each entry keeps the name and folio exactly as they were at that moment, so it still tells the truth even if the row it refers to no longer exists. Nothing here is edited or deleted: that is what makes it a log."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text(L.t("Lo que queda por hacer no vive aquí, sino en Por revisar.",
                     "What is left to do doesn’t live here, but in To review."))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
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

            // **`TextField` de varias líneas y no `TextEditor`.**
            //
            // Con `TextEditor`, abrir esta hoja creaba una ventana de más —un
            // `AXDialog` de 280×168, transparente y fuera de la pantalla— que
            // ninguna otra hoja creaba. Es el único sitio de la app que lo
            // usaba; las demás escriben párrafos con `TextField(axis:)`, que es
            // lo que hace `FilaArea`. Medido: con el cambio, `count of windows`
            // deja de subir.
            TextField("", text: $texto, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .lineLimit(5...9)

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
