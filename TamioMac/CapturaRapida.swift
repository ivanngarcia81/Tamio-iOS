import SwiftUI

/// **La ventana de captura rápida (⌥⌘N). Ahora guarda de verdad.**
///
/// Es una ventana aparte y no una hoja encima de la principal: la idea es
/// poder dejarla abierta mientras se mira la lista de atrás, que es como se
/// captura un domingo entero de ofrendas.
///
/// La frase del handoff —"Tab moves through every field. Nothing here needs
/// the mouse"— es un requisito, no un adorno: quien captura ochenta sobres no
/// suelta el teclado. Por eso el importe tiene el foco al abrir y ⌘S guarda.
struct CapturaRapida: View {
    static let idVentana = "captura-rapida"

    let estado: EstadoVentana
    let sesion: SesionSupabase?

    @Environment(\.dismiss) private var cerrar
    @State private var ingresos = MovimientosViewModel(tipo: .ingreso)
    @State private var gastos = MovimientosViewModel(tipo: .gasto)
    @State private var categorias = CategoriasViewModel.compartido
    @State private var aportantes = MiembrosViewModel()

    @State private var tipo: Tipo = .ingreso
    @State private var importe = ""
    @State private var categoria = ""
    @State private var metodo = Catalogos.metodos.first ?? ""
    @State private var quien = ""
    @State private var nota = ""
    @State private var fecha = Date()
    @State private var folio = ""
    @State private var guardando = false
    @State private var fallo: String?
    @State private var guardadas = 0
    @FocusState private var foco: Casilla?

    private enum Casilla { case importe, quien, nota }

    enum Tipo: String, CaseIterable, Identifiable {
        case ingreso, gasto
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .ingreso: return L.t("Ingreso", "Income")
            case .gasto:   return L.t("Gasto", "Expense")
            }
        }
        var movimiento: TipoMovimiento { self == .ingreso ? .ingreso : .gasto }
        /// El verde de la marca para lo que entra, el rojo para lo que sale.
        var tinta: Color { self == .ingreso ? Paleta.brand : Paleta.negativo }
        var rotuloParte: String {
            switch self {
            case .ingreso: return L.t("Aportante", "Contributor")
            case .gasto:   return L.t("Beneficiario", "Payee")
            }
        }
    }

    private var vm: MovimientosViewModel { tipo == .ingreso ? ingresos : gastos }

    /// Los centavos tecleados, o `nil` si lo escrito no es dinero.
    private var centavos: Centavos? {
        guard let c = Money.desdeTexto(importe), c > 0 else { return nil }
        return c
    }

    /// **Lo que hace falta para poder guardar.**
    ///
    /// Un importe que sea dinero y mayor que cero, una categoría, y —solo en
    /// los gastos— a quién se le pagó: el modelo lo marca como obligatorio
    /// («beneficiario del gasto, required para gastos») y un gasto sin
    /// beneficiario no se puede justificar después.
    private var puedeGuardar: Bool {
        centavos != nil
            && !categoria.isEmpty
            && (tipo == .ingreso || !quien.trimmingCharacters(in: .whitespaces).isEmpty)
            && !guardando
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("", selection: $tipo) {
                ForEach(Tipo.allCases) { Text($0.titulo).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 210)
            .onChange(of: tipo) { alCambiarDeTipo() }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    campo(L.t("Importe", "Amount")) {
                        TextField("", text: $importe, prompt: Text("0.00"))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 20, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(centavos == nil ? .primary : tipo.tinta)
                            .focused($foco, equals: .importe)
                    }
                    campo(L.t("Folio (automático)", "Folio (auto)")) {
                        Text(folio.isEmpty ? L.t("Se asigna al guardar", "Assigned on save")
                                           : folio)
                            .font(.system(size: folio.isEmpty ? 13 : 20,
                                          weight: folio.isEmpty ? .regular : .bold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                GridRow {
                    campo(L.t("Categoría", "Category")) {
                        Picker("", selection: $categoria) {
                            ForEach(nombresDeCategoria, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                    campo(tipo.rotuloParte) {
                        // En ingresos se ofrece el padrón, pero se puede
                        // escribir: una ofrenda suelta no viene de un aportante
                        // fichado, y obligar a elegir uno metería un nombre
                        // falso en el libro.
                        TextField("", text: $quien,
                                  prompt: Text(tipo == .ingreso
                                               ? L.t("Nombre, o vacío si es anónimo",
                                                     "Name, or leave empty if anonymous")
                                               : L.t("A quién se le pagó", "Who was paid")))
                            .textFieldStyle(.roundedBorder)
                            .focused($foco, equals: .quien)
                    }
                }
                GridRow {
                    campo(L.t("Método", "Method")) {
                        Picker("", selection: $metodo) {
                            ForEach(Catalogos.metodos, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                    campo(L.t("Fecha", "Date")) {
                        DatePicker("", selection: $fecha, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }

            campo(L.t("Nota", "Note")) {
                TextField("", text: $nota,
                          prompt: Text(L.t("Opcional — sale en el recibo",
                                           "Optional — shows on the receipt")),
                          axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .focused($foco, equals: .nota)
            }

            if !importe.isEmpty && centavos == nil {
                aviso(L.t("Ese importe no se entiende. Escribe solo la cifra, como 1250.50.",
                          "That amount isn't valid. Type just the figure, like 1250.50."),
                      tinta: Paleta.negativo)
            }
            if let fallo {
                aviso(fallo, tinta: Paleta.negativo)
            }
            if guardadas > 0 {
                aviso(guardadas == 1
                      ? L.t("1 movimiento guardado en esta ventana.",
                            "1 movement saved in this window.")
                      : L.t("\(guardadas) movimientos guardados en esta ventana.",
                            "\(guardadas) movements saved in this window."),
                      tinta: Paleta.brand)
            }

            HStack(spacing: 9) {
                // **Dice lo que de verdad hace, y no lo que pedía el
                // handoff.** Su frase era "Tab moves through every field.
                // Nothing here needs the mouse", y es falsa en un Mac recién
                // estrenado: con la navegación por teclado del sistema apagada
                // —que es como viene—, el tabulador SE SALTA los `Picker`.
                // Medido tecla a tecla: importe → quien → fecha → nota →
                // importe, con Categoría y Método fuera del ciclo.
                //
                // Se intentaron dos salidas y ninguna sirve, así que no se
                // vuelven a intentar:
                //
                //  1. Escribir `AppleKeyboardUIMode` en el dominio de la app.
                //     El valor QUEDA escrito —`defaults read` lo devuelve— y
                //     AppKit lo ignora: lee el global, y ese no se le toca a
                //     nadie desde aquí.
                //  2. `.focusable()` en los dos `Picker`. Peor: el foco se
                //     quedaba clavado en el importe y el tabulador dejaba de
                //     mover NADA.
                //
                // Queda prometer lo cierto y decir dónde se enciende el resto.
                Text(L.t("El tabulador recorre las casillas de texto. Para que llegue también a los selectores, enciende la navegación por teclado en Ajustes del Sistema › Teclado.",
                         "Tab moves through the text fields. To reach the pickers too, turn on keyboard navigation in System Settings › Keyboard."))
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Button(L.t("Cancelar", "Cancel")) { cerrar() }
                    .keyboardShortcut(.cancelAction)
                Button(L.t("Guardar y otro", "Save and new")) { guardar(cerrando: false) }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(!puedeGuardar)
                Button(L.t("Guardar", "Save")) { guardar(cerrando: true) }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(tipo.tinta)
                    .disabled(!puedeGuardar)
            }
        }
        .padding(18)
        .frame(width: 596)
        // **Cada vez que la ventana aparece, no solo la primera.**
        //
        // `Window` no destruye la escena al cerrarla, así que el `@State`
        // sobrevive: sin este vaciado, la ventana se reabría con el importe,
        // la persona, la nota y la FECHA del apunte anterior. Cubre también
        // las salidas por "Cancelar" y por el botón rojo, que no pasan por
        // `guardar`.
        .task {
            importe = ""
            quien = ""
            nota = ""
            // La fecha de hoy, no la del día en que se abrió por última vez.
            fecha = Date()
            guardadas = 0
            fallo = nil
            await categorias.cargar()
            await aportantes.cargar()
            alCambiarDeTipo()
            foco = .importe
        }
    }

    // MARK: - Piezas

    private func campo<C: View>(_ rotulo: String,
                                @ViewBuilder contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rotulo).font(.system(size: 11.5)).foregroundStyle(.secondary)
            contenido()
        }
    }

    private func aviso(_ t: String, tinta: Color) -> some View {
        Label(t, systemImage: tinta == Paleta.brand
              ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.system(size: 11.5))
            .foregroundStyle(tinta)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var nombresDeCategoria: [String] {
        let filas = categorias.filas(tipo.movimiento).map(\.nombre)
        return filas.isEmpty ? Catalogos.categorias(tipo.movimiento) : filas
    }

    // MARK: - Guardar

    /// **El folio se pide al cambiar de tipo, no al guardar.**
    ///
    /// Así quien captura ve de antemano con qué número va a quedar el apunte,
    /// que es lo que se apunta en el sobre. Es el mismo que asigna el
    /// repositorio al crear.
    private func alCambiarDeTipo() {
        fallo = nil
        if !nombresDeCategoria.contains(categoria) {
            categoria = nombresDeCategoria.first ?? ""
        }
        if tipo == .ingreso { quien = "" }
        Task { folio = await vm.nuevoFolio() }
    }

    private func guardar(cerrando: Bool) {
        guard let monto = centavos, puedeGuardar else { return }
        guardando = true
        fallo = nil

        let autor = sesion?.perfil.firma ?? ""
        let limpio = quien.trimmingCharacters(in: .whitespaces)
        // **POSIX para la hora.** Se guarda y se ordena; no se elige por
        // preferencia del aparato. Es la misma regla que `NuevoMovimientoView`.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"

        let m = Movimiento(
            // Vacío: Supabase asigna el UID real en el INSERT.
            id: "",
            tipo: tipo.movimiento,
            categoria: categoria,
            // **Misma casilla para los dos**, y por eso no hay ternario: en un
            // ingreso `quien` es el aportante y en un gasto el beneficiario,
            // pero `persona` guarda al otro lado de la operación en ambos
            // casos. Lo que sí cambia es `miembro` y `pagadoA`, más abajo.
            persona: limpio.isEmpty ? nil : limpio,
            folio: folio,
            metodo: metodo,
            monto: monto,
            hora: f.string(from: fecha),
            fecha: fecha,
            // De la sesión, nunca escrito a mano: un rastro de auditoría que
            // firma siempre a la misma persona no sirve para lo que existe.
            registradoPor: autor,
            miembro: tipo == .ingreso ? (limpio.isEmpty ? nil : limpio) : nil,
            categoriaCompleta: categoria,
            nota: nota.isEmpty ? nil : nota,
            // Un ingreso nace sin depositar; un gasto no pasa por caja.
            sinDepositar: tipo == .ingreso,
            comprobante: nil,
            auditoria: [
                AuditEntry(id: "1",
                           titulo: L.t("Creado · \(autor)", "Created · \(autor)"),
                           detalle: L.t("Ahora · \(Dispositivo.nombre)",
                                        "Just now · \(Dispositivo.nombre)"))
            ],
            pagadoA: tipo == .gasto ? (limpio.isEmpty ? nil : limpio) : nil
        )

        Task {
            await vm.crear(m)
            guardando = false
            if let e = vm.error {
                fallo = e
                vm.descartarError()
                return
            }
            guardadas += 1
            // Que la ventana de atrás relea: la creación escribe en la base y
            // las tablas ya cargadas no se enteran solas.
            estado.recargar()
            // **Y que salga hacia el servidor ya.**
            //
            // Capturando un domingo entero la app no se va al fondo ni una
            // vez, así que la vuelta de "volver al frente" no llega nunca y el
            // apunte se quedaría esperando al próximo arranque. El motor se
            // protege solo de las llamadas encimadas (`estado !=
            // .sincronizando`), así que no hay que contarlas aquí.
            Task { await MotorSincronizacion.compartido.sincronizar() }
            if cerrando {
                // **Se cierra limpia.** `Window` mantiene viva la escena, así
                // que sin esto al reabrirla seguían ahí el importe, la persona
                // y la nota del apunte anterior —y, lo que de verdad pica, su
                // FECHA—: reabrir y pulsar ⌘S repetía el movimiento con la
                // fecha de otro día. Lo que se conserva es lo mismo que
                // conserva "Guardar y otro", que es lo que se repite.
                importe = ""
                quien = ""
                nota = ""
                fecha = Date()
                guardadas = 0
                cerrar()
            } else {
                // **Se conserva el tipo, la categoría, el método y la fecha**,
                // que es lo que se repite al capturar un domingo entero; se
                // limpia lo que cambia en cada sobre.
                importe = ""
                quien = ""
                nota = ""
                folio = await vm.nuevoFolio()
                foco = .importe
            }
        }
    }
}
