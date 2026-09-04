import SwiftUI

/// **La hoja de la segunda firma del corte.**
///
/// Qué es, con las palabras del encargo: la tesorera cuenta el dinero, y hay
/// una segunda persona —la asistente, la que la sustituye cuando falta— que lo
/// vuelve a contar y confirma que todo está bien.
///
/// Dos modos, y **los elige quien firma**, no la app:
///
/// - **Conteo.** Con el dinero delante. La hoja **tapa el total** y le pide el
///   suyo. Si cuadra, firma; si no, las dos cifras quedan escritas y la firma
///   no se da. Es el único control de toda la app que compara el efectivo
///   físico contra lo registrado.
/// - **Revisión.** Cuando la firma llega días después, con el dinero ya en el
///   banco, contar no es posible. Lo que sí puede decir es que el registro es
///   coherente: los movimientos, el total, la cuenta.
///
/// Que los dos no se disfracen el uno del otro es el punto entero de tener dos
/// modos.
///
/// **El límite, dicho en voz alta:** es ciego al TECLEAR, no a mirar. Quien
/// arma el corte vio el total un momento antes en su pantalla. Contra un error
/// honesto —que es de lo que protege contar dos veces— funciona; contra dos
/// personas puestas de acuerdo, no. Ninguna app lo hace, y fingir lo contrario
/// sería peor que no tenerlo.
struct SegundaFirmaView: View {
    @Environment(\.dismiss) private var dismiss

    let corte: Corte
    /// Quiénes pueden firmar: los cargos de la iglesia MENOS quien registró el
    /// corte. Nadie se firma a sí mismo.
    let candidatos: [(nombre: String, cargo: String)]
    let onFirmar: (_ nombre: String, _ rol: String?,
                   _ modo: ModoSegundaFirma, _ conteo: Centavos?) -> Void
    /// Contó, no cuadró, y lo deja registrado sin firmar.
    let onDescuadre: (Centavos) -> Void

    @State private var modo: ModoSegundaFirma
    @State private var quien: String = ""
    @State private var contado: String = ""
    /// Se pone al pulsar "Comprobar": hasta entonces no se enseña nada del
    /// total. Sin esto, el doble conteo sería copiar el número de arriba.
    @State private var veredicto: (cifra: Centavos, cuadra: Bool)?
    @FocusState private var contadoEnfocado: Bool

    init(corte: Corte,
         candidatos: [(nombre: String, cargo: String)],
         onFirmar: @escaping (String, String?, ModoSegundaFirma, Centavos?) -> Void,
         onDescuadre: @escaping (Centavos) -> Void) {
        self.corte = corte
        self.candidatos = candidatos
        self.onFirmar = onFirmar
        self.onDescuadre = onDescuadre
        // Ya depositado: el dinero está en el banco, contar no es posible.
        _modo = State(initialValue: corte.soloRevision ? .revision : .conteo)
    }

    private var nombreLimpio: String { quien.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cargo: String? { candidatos.first { $0.nombre == nombreLimpio }?.cargo }
    private var cifra: Centavos? {
        let t = contado.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        return Money.desdeTexto(t)
    }
    /// Firmar exige nombre y, en modo conteo, que la comprobación haya cuadrado.
    private var listo: Bool {
        !nombreLimpio.isEmpty && (modo == .revision || veredicto?.cuadra == true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(corte.soloRevision
                         ? L.t("Este corte ya está depositado, así que el dinero no se puede volver a contar. Lo que sí se puede es revisar el registro: los movimientos, el total y la cuenta.",
                               "This cut is already deposited, so the money cannot be counted again. What can still be checked is the record: the entries, the total and the account.")
                         : L.t("Otra persona vuelve a contar el dinero y confirma que cuadra. La app le tapa el total y le pide el suyo: si no se lo tapara, contar dos veces sería copiar una cifra.",
                               "Someone else counts the money again and confirms it adds up. The app hides the total and asks for theirs: without hiding it, counting twice would just be copying a figure."))
                        .font(.footnote).foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                seccionQuien
                if !corte.soloRevision { seccionModo }
                if modo == .conteo { seccionConteo }

                Section {
                    Text(L.t("Corte: \(corte.titulo)", "Cut: \(corte.titulo)"))
                        .font(.caption).foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(L.t("Segunda firma", "Second signature"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Firmar", "Sign")) {
                        onFirmar(nombreLimpio, cargo, modo,
                                 modo == .conteo ? veredicto?.cifra : nil)
                        dismiss()
                    }
                    .fontWeight(.semibold).tint(Paleta.brand)
                    .disabled(!listo)
                }
            }
        }
        .hojaFormulario()
    }

    // MARK: - Quién firma

    private var seccionQuien: some View {
        Section {
            // El directorio sin quien registró el corte. Se puede escribir un
            // nombre suelto: en una iglesia pequeña firma el pastor, y puede no
            // estar dado de alta con cargo.
            if !candidatos.isEmpty {
                // `Menu` y no `Picker`: el nombre también se puede teclear, y
                // un `Picker` cuya selección no casa con ninguna etiqueta se
                // queda en blanco y avisa por consola. Mismo patrón que el
                // menú de cuentas del corte.
                HStack {
                    Text(L.t("Firma", "Signed by")).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(candidatos, id: \.nombre) { c in
                            Button {
                                quien = c.nombre
                            } label: {
                                if c.nombre == nombreLimpio {
                                    Label("\(c.nombre) · \(c.cargo)", systemImage: "checkmark")
                                } else {
                                    Text("\(c.nombre) · \(c.cargo)")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(nombreLimpio.isEmpty ? L.t("Elegir", "Choose") : nombreLimpio)
                            Image(systemName: "chevron.up.chevron.down").font(.caption2)
                        }
                        .foregroundStyle(Paleta.enlace)
                    }
                }
            }
            TextField(L.t("O escribe el nombre", "Or type the name"), text: $quien)
        } header: {
            Text(L.t("QUIÉN FIRMA", "WHO SIGNS"))
        } footer: {
            Text(L.t("No sale quien registró el corte: nadie puede firmarse a sí mismo. Si en tesorería solo hay una persona, firma el pastor.",
                     "Whoever recorded the cut is not listed: nobody signs for themselves. If treasury is one person, the pastor signs."))
        }
    }

    // MARK: - Qué hizo

    private var seccionModo: some View {
        Section {
            ForEach([ModoSegundaFirma.conteo, .revision], id: \.self) { m in
                Button {
                    modo = m
                    veredicto = nil
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: modo == m ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(modo == m ? Paleta.brand : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m == .conteo
                                 ? L.t("Conté el dinero", "I counted the money")
                                 : L.t("Revisé el registro", "I checked the record"))
                                .font(.subheadline.weight(.medium))
                            Text(m == .conteo
                                 ? L.t("Con los billetes y los cheques delante",
                                       "With the cash and checks in hand")
                                 : L.t("Los movimientos, el total y la cuenta",
                                       "The entries, the total and the account"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(L.t("QUÉ HIZO", "WHAT THEY DID"))
        } footer: {
            Text(L.t("Contar el dinero y revisar el registro no son lo mismo, y el comprobante lo dice con estas palabras.",
                     "Counting the money and checking the record are not the same thing, and the slip says which one in those words."))
        }
    }

    // MARK: - Cuánto contaste

    private var seccionConteo: some View {
        Section {
            // Aquí NO se enseña el total. El campo se teclea a ciegas y
            // "Comprobar" es lo único que revela si cuadra.
            HStack {
                Text(L.t("Tu total", "Your total"))
                Spacer()
                TextField(L.t("Lo que contaste", "What you counted"), text: $contado)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($contadoEnfocado)
                    .onChange(of: contado) { _, _ in veredicto = nil }
            }

            if veredicto == nil {
                Button(L.t("Comprobar", "Check")) {
                    guard let cifra else { return }
                    contadoEnfocado = false
                    veredicto = (cifra, cifra == corte.montoTotal)
                }
                .disabled(cifra == nil)
            }

            if let v = veredicto {
                avisoVeredicto(v)
                if !v.cuadra {
                    // Volver a contar es lo primero que se ofrece: un descuadre
                    // casi siempre es un billete mal contado.
                    Button(L.t("Contar otra vez", "Count again")) {
                        veredicto = nil
                        contado = ""
                        contadoEnfocado = true
                    }
                    // Y si de verdad no cuadra, la cifra queda registrada SIN
                    // firma. Perder ese número sería tirar justo el dato por el
                    // que se cuenta dos veces.
                    Button(role: .destructive) {
                        onDescuadre(v.cifra)
                        dismiss()
                    } label: {
                        Text(L.t("Dejar constancia del descuadre", "Record the discrepancy"))
                    }
                }
            }
        } header: {
            Text(L.t("CUÁNTO CONTASTE", "HOW MUCH DID YOU COUNT"))
        } footer: {
            Text(L.t("El total del corte no se enseña aquí a propósito. Escribe el tuyo y toca Comprobar.",
                     "The cut's total is not shown here on purpose. Enter yours and tap Check."))
        }
    }

    private func avisoVeredicto(_ v: (cifra: Centavos, cuadra: Bool)) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: v.cuadra ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(v.cuadra ? Paleta.brand : Paleta.aviso)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(v.cuadra ? L.t("Cuadra", "It adds up")
                              : L.t("No cuadra", "It does not add up"))
                    .font(.subheadline.weight(.semibold))
                Text(v.cuadra
                     ? L.t("Contaste \(Money.fmt(v.cifra)), lo mismo que el corte. Ya puedes firmar.",
                           "You counted \(Money.fmt(v.cifra)), the same as the cut. You can sign now.")
                     : L.t("Contaste \(Money.fmt(v.cifra)) y el corte dice \(Money.fmt(corte.montoTotal)) — una diferencia de \(Money.fmt(abs(v.cifra - corte.montoTotal))).",
                           "You counted \(Money.fmt(v.cifra)) and the cut says \(Money.fmt(corte.montoTotal)) — a difference of \(Money.fmt(abs(v.cifra - corte.montoTotal)))."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
