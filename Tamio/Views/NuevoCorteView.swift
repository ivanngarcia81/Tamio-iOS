import SwiftUI

/// Formulario de nuevo corte de caja. Devuelve título, cuenta y el efectivo
/// estimado en caja; la vista padre crea el corte vía el repositorio.
///
/// **Solo pide título y cuenta.** El importe no se teclea —es la suma de los
/// ingresos que el corte agrupe— y el efectivo en caja tampoco: se calcula
/// desde los ingresos en efectivo que ningún corte depositado reclama. Los dos
/// eran campos que había que rellenar a mano y que ninguna cuenta comprobaba.
struct NuevoCorteView: View {
    @Environment(\.dismiss) private var dismiss

    let cuentas: [String]
    let onGuardar: (_ titulo: String, _ cuenta: String) -> Void

    @State private var titulo = ""
    @State private var cuenta: String
    @FocusState private var tituloEnfocado: Bool

    init(cuentas: [String],
         onGuardar: @escaping (_ titulo: String, _ cuenta: String) -> Void) {
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
            }
            .navigationTitle(L.t("Nuevo corte", "New cut"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Crear", "Create")) {
                        onGuardar(tituloLimpio, cuenta)
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



/// **Elegir qué ingresos entran en el corte.**
///
/// Sustituye a una hoja que CAPTURABA un movimiento dentro del corte. Eso creaba
/// dinero que no existía en Ingresos: dos puertas de entrada al mismo dato, y
/// un corte podía sumar $5,850 que ninguna otra pantalla de la app conocía.
///
/// Aquí no se crea nada. Se marca cuál del dinero YA REGISTRADO en Ingresos va
/// en este sobre al banco. Capturar sigue siendo trabajo de Ingresos.
struct ElegirMovimientosView: View {
    @Environment(\.dismiss) private var dismiss

    let libres: [Movimiento]
    let onAgregar: ([String]) -> Void

    @State private var elegidos: Set<String> = []

    private var total: Centavos {
        libres.filter { elegidos.contains($0.id) }.reduce(0) { $0 + $1.monto }
    }

    var body: some View {
        NavigationStack {
            Group {
                if libres.isEmpty {
                    ContentUnavailableView(
                        L.t("No queda dinero sin depositar", "Nothing left undeposited"),
                        systemImage: "checkmark.circle",
                        description: Text(L.t("Todos los ingresos registrados ya están en algún corte. Captura primero en Ingresos lo que falte.",
                                              "Every recorded income is already in a cut. Record what's missing in Income first."))
                    )
                } else {
                    List(libres) { m in
                        fila(m)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(L.t("Dinero sin depositar", "Undeposited money"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(etiquetaAgregar) {
                        onAgregar(Array(elegidos))
                        dismiss()
                    }
                    .fontWeight(.semibold).tint(Paleta.brand)
                    .disabled(elegidos.isEmpty)
                }
            }
        }
        .hojaGrande()
    }

    /// Dice cuánto se va a sumar, no solo cuántos: el tesorero está cuadrando
    /// contra un fajo de billetes.
    private var etiquetaAgregar: String {
        elegidos.isEmpty
            ? L.t("Agregar", "Add")
            : L.t("Agregar \(Money.fmt(total))", "Add \(Money.fmt(total))")
    }

    private func fila(_ m: Movimiento) -> some View {
        let elegido = elegidos.contains(m.id)
        return Button {
            if elegido { elegidos.remove(m.id) } else { elegidos.insert(m.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: elegido ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(elegido ? Paleta.brand : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.titular).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(L.t("Folio \(m.folio) · \(m.metodo)", "Folio \(m.folio) · \(m.metodo)"))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(Money.fmt(m.monto)).font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
