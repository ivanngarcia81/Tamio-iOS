import SwiftUI

/// Hoja "Editar ingreso/gasto" desde la bandeja Por revisar.
///
/// Antes se construía con un helper `campo(_:)` propio: `TextField` con
/// `.roundedBorder`, chips a mano, y dos estilos de caja distintos dentro de la
/// misma hoja (Concepto con borde blanco, Importe con relleno gris). Al lado de
/// la hoja de alta —que sí usa `Form` con `Section`, `Picker` y `DatePicker`—
/// una parecía app de iOS y la otra un formulario web. Ahora las dos son el
/// mismo `Form`, con las mismas secciones y los mismos controles.
struct EditarAsuntoView: View {
    @Environment(\.dismiss) private var dismiss

    let r: Revision
    let onGuardar: (_ concepto: String, _ importe: String, _ categoria: String,
                    _ metodo: String, _ aportante: String?, _ fecha: Date) -> Void

    @State private var concepto: String
    @State private var importe: String
    @State private var categoria: String
    @State private var metodo: String
    @State private var aportante: String?
    @State private var fecha: Date
    @FocusState private var importeEnfocado: Bool

    /// **El padrón de la iglesia, no una lista inventada.** Aquí había cuatro
    /// nombres escritos a mano —"Pedro Salas Aguirre", "Karla Villalobos
    /// Ruiz"…—, que es exactamente lo que se quitó el 6-sep de los tres
    /// selectores de Secretaría y que a este se le pasó: corregir el aportante
    /// de un ingreso le ponía el nombre de alguien que puede no existir en el
    /// padrón, y eso rompe la constancia anual y el total del aportante.
    @State private var aportantes: [PersonaDelPadron] = []

    /// Centinela de "sin aportante" en el Picker, como en la hoja de alta.
    private static let sinAsignar = L.t("Sin asignar", "Unassigned")

    init(r: Revision,
         onGuardar: @escaping (String, String, String, String, String?, Date) -> Void) {
        self.r = r
        self.onGuardar = onGuardar
        // **La nota, no el titular.** El titular sale compuesto de categoría y
        // persona, así que prellenar con él y guardarlo metía "Misiones ·
        // Iglesia La Esperanza" dentro de la nota. Es el mismo campo que la
        // hoja de alta llama "Concepto".
        _concepto = State(initialValue: r.editNota ?? "")
        _importe = State(initialValue: r.editImporte ?? "")
        // El asunto puede llegar sin categoría ("Sin categoría", en rojo); si
        // trae una que no está en el catálogo, `conValorVigente` la conserva
        // como opción en lugar de perderla.
        let cats = Catalogos.categorias(r.esGasto ? .gasto : .ingreso)
        _categoria = State(initialValue: r.editCategoria ?? (cats.first ?? ""))
        _metodo = State(initialValue: r.editMetodo ?? (Catalogos.metodos.first ?? ""))
        _aportante = State(initialValue: r.editAportante)
        // La fecha viene ya hecha del movimiento. Antes se recomponía leyendo
        // el TEXTO del campo "Fecha" del asunto con `desdeSemilla`, que es un
        // parseador de la maqueta: con un formato que no reconociera caía en
        // `Date()` y la hoja proponía hoy en lugar del día del movimiento.
        _fecha = State(initialValue: r.editFecha ?? Date())
    }

    /// Mismo catálogo y misma regla que la hoja de alta.
    private var categorias: [String] {
        Catalogos.conValorVigente(Catalogos.categorias(r.esGasto ? .gasto : .ingreso), categoria)
    }
    private var metodos: [String] { Catalogos.conValorVigente(Catalogos.metodos, metodo) }
    private var folio: String {
        r.campos.first { $0.label == L.t("Folio", "Folio") }?.valor ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 4) {
                        // La moneda de la iglesia, como en la hoja de alta.
                        Text(Money.moneda.simbolo).foregroundStyle(.secondary)
                        // El marcador con el separador del aparato, como en la
                        // hoja de alta: en región española decía "0.00" y
                        // proponía un punto que el `.decimalPad` de esa región
                        // no ofrece.
                        TextField(NuevoMovimientoView.aTexto(0), text: $importe)
                            .keyboardType(.decimalPad)
                            .focused($importeEnfocado)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                } header: {
                    Text(L.t("IMPORTE", "AMOUNT"))
                } footer: {
                    Text(L.t("Los cambios se guardan en el movimiento; el asunto sigue en la bandeja hasta que lo resuelvas.",
                             "Changes are saved to the entry; the item stays in the tray until you resolve it."))
                }

                Section(header: Text(L.t("DETALLE", "DETAILS"))) {
                    TextField(L.t("Concepto", "Description"), text: $concepto)
                        .autocorrectionDisabled()
                    pickerCategoria
                    DatePicker(L.t("Fecha", "Date"), selection: $fecha, displayedComponents: .date)
                    Picker(L.t("Método de pago", "Payment method"), selection: $metodo) {
                        ForEach(metodos, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }

                if !r.esGasto {
                    Section(header: Text(L.t("APORTANTE", "CONTRIBUTOR"))) {
                        Picker(L.t("Aportante", "Contributor"), selection: aportanteBinding) {
                            Text(Self.sinAsignar).tag(Self.sinAsignar)
                            ForEach(opcionesAportante, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .task { if aportantes.isEmpty { aportantes = await padronParaSelector() } }
                    }
                }

                if !folio.isEmpty {
                    Section { } footer: {
                        Text(L.t("Folio \(folio)", "Folio \(folio)"))
                    }
                }
            }
            .navigationTitle(r.esGasto ? L.t("Editar gasto", "Edit expense") : L.t("Editar ingreso", "Edit income"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("Cancelar", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar cambios", "Save changes")) {
                        onGuardar(concepto, importe, categoria, metodo,
                                  r.esGasto ? nil : aportante, fecha)
                        dismiss()
                    }
                    .fontWeight(.semibold).tint(Paleta.brand)
                    // **Un importe que no se entiende no se guarda.** Antes
                    // bastaba con que el campo no estuviera vacío, y el texto
                    // viajaba sin que nadie lo leyera nunca. Y el concepto ya
                    // no apaga el botón: es la nota, y una nota vacía es
                    // legítima —la hoja de alta tampoco la exige—.
                    .disabled((Money.desdeTexto(importe) ?? 0) <= 0)
                }
            }
        }
        // Formulario corto: media pantalla basta, y se puede expandir. Antes
        // ocupaba la pantalla completa y dejaba medio lienzo vacío.
        .hojaEleccion()
        .presentationDragIndicator(.visible)
    }

    /// Misma regla que la hoja de alta: si el catálogo pasa de una decena, el
    /// Picker empuja una pantalla con lista; si no, menú. Dos ramas y no un
    /// ternario en `.pickerStyle`, que son tipos distintos y no compila.
    @ViewBuilder
    private var pickerCategoria: some View {
        if categorias.count > 10 {
            pickerCategoriaBase.pickerStyle(.navigationLink)
        } else {
            pickerCategoriaBase.pickerStyle(.menu)
        }
    }

    private var pickerCategoriaBase: some View {
        Picker(r.esGasto ? L.t("Categoría", "Category")
                         : L.t("Tipo de ingreso", "Income type"),
               selection: $categoria) {
            ForEach(categorias, id: \.self) { Text($0).tag($0) }
        }
    }

    /// El Picker trabaja con String; el modelo guarda `nil` cuando no hay
    /// aportante asignado.
    private var aportanteBinding: Binding<String> {
        Binding(get: { aportante ?? Self.sinAsignar },
                set: { aportante = $0 == Self.sinAsignar ? nil : $0 })
    }

    /// El padrón, más el aportante que ya tuviera el movimiento si no está en
    /// él: un `Picker` no puede marcar una opción que no exista entre las
    /// suyas, y el que hay puede ser un nombre suelto de un visitante o de
    /// alguien dado de baja. Es la misma regla que `NuevoMovimientoView`.
    private var opcionesAportante: [String] {
        let nombres = aportantes.map(\.nombre)
        guard let aportante, !aportante.isEmpty, !nombres.contains(aportante) else { return nombres }
        return [aportante] + nombres
    }
}
