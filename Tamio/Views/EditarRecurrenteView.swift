import SwiftUI

/// **Editar una serie recurrente.**
///
/// Lo que se cambia aquí solo afecta a los meses que se generen de aquí en
/// adelante. Los ya registrados están contados en cierres pasados: reescribir
/// una renta de julio porque en octubre subió descuadraría julio.
///
/// Por eso el tipo y el mes de inicio no se editan y ni siquiera salen como
/// campos: cambiarlos movería movimientos que ya existen. Si la renta sube, se
/// para esta serie y se crea otra — que es además lo que deja el historial
/// contando la verdad de cada mes.
struct EditarRecurrenteView: View {
    @Environment(\.dismiss) private var dismiss

    let recurrente: MovimientoRecurrente
    let onGuardar: (MovimientoRecurrente) -> Void
    let onParar: () -> Void

    @State private var concepto: String
    @State private var importe: String
    @State private var dia: Int
    @State private var confirmarParada = false

    init(recurrente: MovimientoRecurrente,
         onGuardar: @escaping (MovimientoRecurrente) -> Void,
         onParar: @escaping () -> Void) {
        self.recurrente = recurrente
        self.onGuardar = onGuardar
        self.onParar = onParar
        _concepto = State(initialValue: recurrente.nota ?? "")
        _importe = State(initialValue: NuevoMovimientoView.aTexto(recurrente.monto))
        _dia = State(initialValue: recurrente.dia)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.t("Concepto", "Description"), text: $concepto)
                    LabeledContent(L.t("Importe", "Amount")) {
                        TextField("0.00", text: $importe)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    Picker(L.t("Día del mes", "Day of month"), selection: $dia) {
                        ForEach(1...31, id: \.self) { d in Text("\(d)").tag(d) }
                    }
                } header: {
                    Text(L.t("Movimiento fijo recurrente", "Recurring fixed entry"))
                } footer: {
                    // El día 31 no se salta los meses cortos: cae en el último.
                    // Decirlo aquí evita que alguien elija el 28 "por si acaso".
                    Text(L.t("Solo afecta a los meses que se generen de aquí en adelante. En los meses más cortos se registra el último día.",
                             "Only affects months generated from now on. In shorter months it lands on the last day."))
                }

                Section {
                    LabeledContent(L.t("Categoría", "Category"),
                                   value: recurrente.categoriaCompleta)
                    LabeledContent(L.t("Método", "Method"), value: recurrente.metodo)
                    if let pagadoA = recurrente.pagadoA, !pagadoA.isEmpty {
                        LabeledContent(L.t("Pagado a", "Paid to"), value: pagadoA)
                    }
                    LabeledContent(L.t("Se repite desde", "Repeating since"),
                                   value: Fechas.periodoLegible(recurrente.mesInicio))
                    LabeledContent(L.t("Último mes registrado", "Last month recorded"),
                                   value: recurrente.ultimoMesGenerado.map(Fechas.periodoLegible)
                                       ?? L.t("Ninguno todavía", "None yet"))
                } header: {
                    Text(L.t("De la serie", "About this series"))
                }

                Section {
                    Button(role: .destructive) { confirmarParada = true } label: {
                        Text(L.t("Dejar de repetir", "Stop repeating"))
                    }
                } footer: {
                    Text(L.t("Deja de registrarse automáticamente en los meses siguientes. Los movimientos ya registrados se conservan.",
                             "It stops being recorded automatically in the months ahead. Entries already recorded are kept."))
                }
            }
            .navigationTitle(L.t("Editar recurrente", "Edit recurring"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar", "Save")) { guardar() }
                        .disabled((Money.desdeTexto(importe) ?? 0) <= 0)
                }
            }
            .confirmationDialog(L.t("Dejar de repetir", "Stop repeating"),
                                isPresented: $confirmarParada, titleVisibility: .visible) {
                Button(L.t("Dejar de repetir", "Stop repeating"), role: .destructive) {
                    onParar()
                    dismiss()
                }
                Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
            } message: {
                Text(L.t("\"\(recurrente.titular)\" dejará de registrarse en los meses siguientes. Lo ya registrado se conserva.",
                         "\"\(recurrente.titular)\" will stop being recorded in the months ahead. What is already recorded is kept."))
            }
        }
        // Se rellena y se guarda: familia formulario, como las otras veinte.
        .hojaFormulario()
    }

    private func guardar() {
        guard let monto = Money.desdeTexto(importe), monto > 0 else { return }
        var editado = recurrente
        editado.nota = concepto.isEmpty ? nil : concepto
        editado.monto = monto
        editado.dia = dia
        onGuardar(editado)
        dismiss()
    }
}

/// La tira de series activas que va encima de la lista de movimientos.
///
/// **Es una advertencia, no un historial.** Lo que enseña todavía no cuenta en
/// el total del mes: son los movimientos que se van a registrar solos cuando el
/// mes cierre. Por eso va arriba y por eso lo dice el pie de la sección — un
/// tesorero que no sepa que le vienen 850 al cierre está mirando un saldo que
/// no es el suyo.
struct FilaRecurrente: View {
    let recurrente: MovimientoRecurrente

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Paleta.categoria(Catalogos.clave(deEtiqueta: recurrente.categoria),
                                                  nombre: recurrente.categoria))
                .frame(width: 30, height: 30)
                .background(Paleta.categoria(Catalogos.clave(deEtiqueta: recurrente.categoria),
                                             nombre: recurrente.categoria).opacity(0.14),
                            in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(recurrente.titular).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(L.t("Día \(recurrente.dia) de cada mes · \(recurrente.categoria)",
                         "Day \(recurrente.dia) of each month · \(recurrente.categoria)"))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            // **Sin signo y en secundario, al revés que un movimiento.** Un
            // importe en rojo con su menos delante se lee como dinero que ya
            // salió; esto todavía no ha salido.
            Text(L.t("\(Money.fmt(recurrente.monto)) / mes",
                     "\(Money.fmt(recurrente.monto)) / mo"))
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Esp.chip)
    }
}
