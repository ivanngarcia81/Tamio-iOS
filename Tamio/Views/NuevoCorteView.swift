import SwiftUI

/// Formulario de nuevo corte de caja. Devuelve título, cuenta y el efectivo
/// estimado en caja; la vista padre crea el corte vía el repositorio.
///
/// **Ya no pide el importe del depósito.** Lo pedía en un campo grande y ese
/// número no tenía nada detrás: el corte nacía sin un solo movimiento diciendo
/// "listo para depositar $5,850.00", y al marcar cualquier casilla caía a
/// $0.00. El monto de un corte es la suma de su dinero en caja, y eso se
/// captura dentro, con "Agregar dinero en caja".
struct NuevoCorteView: View {
    @Environment(\.dismiss) private var dismiss

    let cuentas: [String]
    let onGuardar: (_ titulo: String, _ cuenta: String, _ efectivoEstimado: Centavos?) -> Void

    @State private var titulo = ""
    @State private var cuenta: String
    @State private var estimado = ""
    @FocusState private var tituloEnfocado: Bool

    init(cuentas: [String],
         onGuardar: @escaping (_ titulo: String, _ cuenta: String, _ efectivoEstimado: Centavos?) -> Void) {
        self.cuentas = cuentas
        self.onGuardar = onGuardar
        _cuenta = State(initialValue: cuentas.first ?? "")
    }

    private var tituloLimpio: String {
        titulo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.t("Título del corte", "Cut title"), text: $titulo)
                        .focused($tituloEnfocado)
                    Picker(L.t("Cuenta", "Account"), selection: $cuenta) {
                        ForEach(cuentas, id: \.self) { Text($0).tag($0) }
                    }
                } footer: {
                    Text(L.t("Ejemplo: «Culto domingo 6 de septiembre».",
                             "For example: “Sunday, September 6 service”."))
                }

                Section {
                    HStack {
                        Text(L.t("Efectivo estimado en caja", "Estimated cash on hand"))
                        Spacer()
                        TextField(L.t("Opcional", "Optional"), text: $estimado)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                } footer: {
                    Text(L.t("Lo que la iglesia cree tener en caja a esa fecha. Sirve para avisarte si el depósito pide más efectivo del que hay; no es el monto del depósito.",
                             "What the church believes is on hand at that date. It warns you if the deposit needs more cash than there is; it is not the deposit amount."))
                }
            }
            .navigationTitle(L.t("Nuevo corte", "New cut"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Crear", "Create")) {
                        onGuardar(tituloLimpio, cuenta, Money.desdeTexto(estimado))
                        dismiss()
                    }
                    .fontWeight(.semibold).tint(Paleta.brand)
                    // El título es lo que identifica el corte en la lista.
                    // Antes se exigía el importe y se permitía crear un corte
                    // sin nombre, que salía como "Corte sin título".
                    .disabled(tituloLimpio.isEmpty)
                }
            }
            .onAppear { tituloEnfocado = true }
        }
        .hojaGrande()
    }
}

/// Captura de un movimiento de dinero en caja dentro de un corte.
///
/// **Esta hoja no existía.** El detalle del corte solo dejaba marcar y
/// desmarcar los movimientos que ya venían del repositorio: no había forma de
/// meter el diezmo del domingo ni un cheque, así que un corte creado desde la
/// app se quedaba vacío para siempre.
struct NuevoMovimientoCajaView: View {
    @Environment(\.dismiss) private var dismiss

    /// Folio sugerido: el siguiente al último del corte.
    let folioSugerido: String
    let onGuardar: (MovimientoCaja) -> Void

    @State private var categoria: String = Catalogos.categoriasIngreso.first ?? ""
    @State private var otraCategoria = ""
    @State private var importe = ""
    @State private var esCheque = false
    @State private var numeroCheque = ""
    @State private var folio: String
    @State private var fecha = Date()
    @FocusState private var importeEnfocado: Bool

    /// Etiqueta para capturar una categoría que no está en el catálogo
    /// ("Ofrenda misionera", "Fondo de construcción"): la iglesia las nombra
    /// como quiere y `Catalogos.clave(deEtiqueta:)` sabe reconducirlas.
    private static let otra = L.t("Otra…", "Other…")

    init(folioSugerido: String, onGuardar: @escaping (MovimientoCaja) -> Void) {
        self.folioSugerido = folioSugerido
        self.onGuardar = onGuardar
        _folio = State(initialValue: folioSugerido)
    }

    private var categoriaFinal: String {
        categoria == Self.otra
            ? otraCategoria.trimmingCharacters(in: .whitespacesAndNewlines)
            : categoria
    }
    private var monto: Centavos? {
        guard let c = Money.desdeTexto(importe), c > 0 else { return nil }
        return c
    }
    private var puedeGuardar: Bool {
        monto != nil && !categoriaFinal.isEmpty
            && (!esCheque || !numeroCheque.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                importeView.padding(.vertical, 16)
                Form {
                    Section {
                        Picker(L.t("Categoría", "Category"), selection: $categoria) {
                            ForEach(Catalogos.categoriasIngreso, id: \.self) { Text($0).tag($0) }
                            Text(Self.otra).tag(Self.otra)
                        }
                        if categoria == Self.otra {
                            TextField(L.t("Nombre de la categoría", "Category name"),
                                      text: $otraCategoria)
                        }
                        TextField(L.t("Folio", "Folio"), text: $folio)
                    }

                    Section {
                        // Efectivo o cheque decide en qué chip suma el dinero,
                        // así que es un control propio y no una nota escrita
                        // dentro de la hora, como estaba en la semilla.
                        Picker(L.t("Forma", "Form"), selection: $esCheque) {
                            Text(L.t("Efectivo", "Cash")).tag(false)
                            Text(L.t("Cheque", "Check")).tag(true)
                        }
                        .pickerStyle(.segmented)
                        if esCheque {
                            TextField(L.t("Número de cheque", "Check number"), text: $numeroCheque)
                                .keyboardType(.numberPad)
                        }
                        DatePicker(L.t("Cuándo entró", "Received"), selection: $fecha,
                                   displayedComponents: .date)
                    } footer: {
                        Text(esCheque
                             ? L.t("Los cheques se depositan con la misma ficha, pero suman aparte del efectivo.",
                                   "Checks go on the same slip but total separately from cash.")
                             : L.t("El efectivo se compara con lo que la iglesia estima tener en caja.",
                                   "Cash is checked against what the church estimates is on hand."))
                    }
                }
            }
            .navigationTitle(L.t("Dinero en caja", "Cash entry"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Agregar", "Add")) {
                        guard let monto else { return }
                        onGuardar(MovimientoCaja(
                            id: 0,   // lo asigna el corte
                            categoria: categoriaFinal,
                            folio: folio.trimmingCharacters(in: .whitespaces),
                            cuando: DepositosViewModel.textoFecha(fecha),
                            monto: monto,
                            seleccionado: true,
                            esCheque: esCheque,
                            numeroCheque: esCheque
                                ? numeroCheque.trimmingCharacters(in: .whitespaces) : nil))
                        dismiss()
                    }
                    .fontWeight(.semibold).tint(Paleta.brand)
                    .disabled(!puedeGuardar)
                }
            }
            .onAppear { importeEnfocado = true }
        }
        .hojaGrande()
    }

    private var importeView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(Money.moneda.simbolo)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            TextField("0.00", text: $importe)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .fixedSize()
                .focused($importeEnfocado)
        }
        .frame(maxWidth: .infinity)
    }
}
