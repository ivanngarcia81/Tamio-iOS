import SwiftUI

/// Detalle de un corte de caja (depósito): cabecera con estado, tres chips KPI,
/// checklist "Antes de depositar", movimientos en caja, y la tarjeta "Se
/// registrará así" con la ficha del banco. Los botones se cablean por
/// callbacks; la vista padre los enruta al ViewModel/repositorio.
struct CorteDetalle: View {
    let corte: Corte
    var cuentas: [String] = []
    var onNuevoCorte: (() -> Void)? = nil
    var libres: [Movimiento] = []
    var onAgregarAlCorte: (([String]) -> Void)? = nil
    var onQuitarDelCorte: ((String) -> Void)? = nil
    var onAsignarCuenta: ((String) -> Void)? = nil
    var onAgregarCuenta: ((String) -> Void)? = nil
    var onCambiarPeriodo: ((String) -> Void)? = nil
    var onCambiarFecha: ((Date) -> Void)? = nil
    var onRegistrarDeposito: ((DepositoBancario) -> Void)? = nil
    var onIrAPorRevisar: (() -> Void)? = nil
    var candidatosFirma: [(nombre: String, cargo: String)] = []
    var onFirmar: ((_ nombre: String, _ rol: String?,
                    _ modo: ModoSegundaFirma, _ conteo: Centavos?) -> Void)? = nil
    var onDescuadre: ((Centavos) -> Void)? = nil
    var onQuitarFirma: (() -> Void)? = nil

    @State private var mostrarRegistro = false
    @State private var mostrarNuevoMovimiento = false
    @State private var mostrarNuevaCuenta = false
    @State private var mostrarFecha = false
    @State private var mostrarFirma = false
    @State private var nombreCuenta = ""
    @State private var fechaEditada = Date()
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cabecera
                chips
                if sizeClass == .compact {
                    // En iPhone el botón vive fijo abajo (`barraDepositar`), y la
                    // ficha del banco sube ANTES de "Se registrará así": antes
                    // quedaba debajo del botón, así que se podía confirmar el
                    // depósito sin haber visto que existía la opción de adjuntar.
                    columnaIzquierda
                    tarjetaSegundaFirma
                    tarjetaFicha
                    tarjetaRegistro(conBoton: false)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) { columnaIzquierda; columnaDerecha.frame(width: 300) }
                        VStack(spacing: 16) { columnaIzquierda; columnaDerecha }
                    }
                }
            }
            .padding(Esp.panel)
        }
        .colchonInferior()
        .safeAreaInset(edge: .bottom) { barraDepositar }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
        .sheet(isPresented: $mostrarNuevoMovimiento) {
            ElegirMovimientosView(libres: libres) { ids in
                onAgregarAlCorte?(ids)
            }
        }
        .alert(L.t("Cuenta nueva", "New account"), isPresented: $mostrarNuevaCuenta) {
            TextField(L.t("Banco y últimos dígitos", "Bank and last digits"), text: $nombreCuenta)
            Button(L.t("Agregar", "Add")) {
                onAgregarCuenta?(nombreCuenta)
                nombreCuenta = ""
            }
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { nombreCuenta = "" }
        } message: {
            Text(L.t("Por ejemplo «Chase ··7730». Se asigna a este corte.",
                     "For example “Chase ··7730”. It will be assigned to this cut."))
        }
        .sheet(isPresented: $mostrarRegistro) {
            RegistrarDepositoView(corte: corte) { deposito in
                onRegistrarDeposito?(deposito)
            }
        }
        .sheet(isPresented: $mostrarFecha) { hojaFecha }
        .sheet(isPresented: $mostrarFirma) {
            SegundaFirmaView(corte: corte, candidatos: candidatosFirma) { nombre, rol, modo, conteo in
                onFirmar?(nombre, rol, modo, conteo)
            } onDescuadre: { conteo in
                onDescuadre?(conteo)
            }
        }
    }

    // MARK: - Cabecera

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(corte.titulo).font(.title.weight(.bold))
                Spacer()
                Button { onNuevoCorte?() } label: {
                    Label(L.t("Nuevo corte", "New cut"), systemImage: "plus").font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(Color.secondary)
            }
            // El chip en línea con el H1 partía el título en dos renglones.
            if corte.sinDepositar {
                Pill(texto: L.t("Sin depositar", "Not deposited"), color: Paleta.aviso)
            }
            Text(corte.descripcion).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    // MARK: - Chips KPI

    private var chips: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    TituloSeccion(texto: L.t("EL CORTE", "THIS DEPOSIT"))
                    Spacer()
                    Text(L.t("\(corte.cuantos) movimiento\(corte.cuantos == 1 ? "" : "s")",
                             "\(corte.cuantos) entr\(corte.cuantos == 1 ? "y" : "ies")"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Paleta.brand)
                }
                .padding(.bottom, 10)

                filaChip(L.t("Efectivo seleccionado", "Cash selected"),
                         monto: corte.efectivoSeleccionado,
                         // El efectivo en caja ya no se teclea: son los ingresos
                         // en efectivo que ningún corte depositado reclama.
                         sub: L.t("De \(Money.fmt(corte.efectivoEnCaja)) sin depositar en caja",
                                  "Of \(Money.fmt(corte.efectivoEnCaja)) undeposited on hand"))
                Divider()
                filaChip(L.t("Cheques (\(corte.chequesCount))", "Checks (\(corte.chequesCount))"),
                         monto: corte.chequesMonto,
                         sub: corte.chequesCount == 0
                            ? nil
                            : L.t("Se depositan con la misma ficha", "Deposited on the same slip"))
                Divider()
                filaChip(L.t("Listo para depositar", "Ready to deposit"),
                         monto: corte.listoParaDepositar,
                         sub: nil, destacada: true)
            }
        }
    }

    private func filaChip(_ titulo: String, monto: Centavos,
                          sub: String?, destacada: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(destacada ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundStyle(destacada ? .primary : .secondary)
                if let sub {
                    Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 10)
            AmountText(cents: monto, size: destacada ? 22 : 18,
                       color: destacada ? Paleta.brand : .primary)
        }
        .padding(.vertical, 9)
    }

    // MARK: - Columna izquierda (checklist + movimientos)

    private var columnaIzquierda: some View {
        VStack(alignment: .leading, spacing: 16) {
            Tarjeta {
                VStack(alignment: .leading, spacing: 16) {
                    TituloSeccion(texto: L.t("ANTES DE DEPOSITAR", "BEFORE DEPOSITING"))
                    ForEach(corte.chequeos) { filaChequeo($0) }
                }
            }
            Tarjeta {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TituloSeccion(texto: L.t("MOVIMIENTOS DEL CORTE", "ENTRIES IN THIS DEPOSIT"))
                        Spacer()
                    }
                    if corte.movimientos.isEmpty {
                        Text(L.t("Este corte todavía no agrupa nada.",
                                 "This cut doesn't group anything yet."))
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(corte.movimientos.enumerated()), id: \.element.id) { i, m in
                            filaMovimiento(m)
                            if i < corte.movimientos.count - 1 { Divider() }
                        }
                    }
                    if corte.sinDepositar {
                        Divider()
                        Button { mostrarNuevoMovimiento = true } label: {
                            Label(L.t("Agregar dinero sin depositar", "Add undeposited money"),
                                  systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Paleta.brand)
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private func filaChequeo(_ c: Chequeo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconoChequeo(c.tipo))
                .foregroundStyle(colorChequeo(c.tipo))
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(c.titulo).font(.subheadline.weight(.semibold))
                    Spacer()
                    enlaceChequeo(c)
                }
                Text(c.detalle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Sin casilla de marcar: **estar en la lista ES estar en el corte**. La
    /// casilla venía de cuando el corte guardaba un `seleccionado` propio que
    /// podía contradecir a la lista; ahora sacarlo del corte es borrar la fila
    /// puente, y el movimiento vuelve a quedar libre para otro corte.
    private func filaMovimiento(_ m: Movimiento) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.titular).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(referencia(m))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Money.fmt(m.monto)).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            if corte.sinDepositar {
                Button(role: .destructive) { onQuitarDelCorte?(m.id) } label: {
                    Label(L.t("Sacar del corte", "Remove from cut"), systemImage: "minus.circle")
                }
            }
        }
    }

    /// El número del cheque manda sobre todo lo demás: es lo que el banco pide
    /// en la ficha. Antes iba escondido dentro del texto de la hora.
    private func referencia(_ m: Movimiento) -> String {
        let forma = m.numeroCheque.map { L.t("Cheque \($0)", "Check \($0)") } ?? m.metodo
        return L.t("Folio \(m.folio) · \(forma)", "Folio \(m.folio) · \(forma)")
    }

    /// El enlace del checklist. Antes era `Text` con `Paleta.enlace` para todos
    /// menos "Asignar cuenta": "Ir a Por revisar" tenía color de enlace y no
    /// llevaba a ningún sitio, el mismo falso enlace que ya se quitó de
    /// `FieldRow` y del pie de la tarjeta "Por revisar" del Inicio.
    @ViewBuilder
    private func enlaceChequeo(_ c: Chequeo) -> some View {
        switch c.accion {
        case .asignarCuenta:
            menuCuentas { Text(c.enlace ?? "").font(.caption.weight(.semibold)) }
        case .irAPorRevisar:
            Button { onIrAPorRevisar?() } label: {
                Text(c.enlace ?? "").font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain).foregroundStyle(Paleta.enlace)
        case .cambiarPeriodo:
            menuPeriodos { Text(c.enlace ?? "").font(.caption.weight(.semibold)) }
        case nil:
            EmptyView()
        }
    }

    /// El menú de cuentas, con alta incluida. Se usa en el checklist y en "Se
    /// registrará así": eran dos copias del mismo `ForEach`.
    @ViewBuilder
    private func menuCuentas<E: View>(@ViewBuilder etiqueta: () -> E) -> some View {
        Menu {
            ForEach(cuentas, id: \.self) { cta in
                Button {
                    onAsignarCuenta?(cta)
                } label: {
                    if cta == corte.registro.cuenta {
                        Label(cta, systemImage: "checkmark")
                    } else {
                        Text(cta)
                    }
                }
            }
            Divider()
            Button {
                mostrarNuevaCuenta = true
            } label: {
                Label(L.t("Otra cuenta…", "Another account…"), systemImage: "plus")
            }
        } label: {
            etiqueta().foregroundStyle(Paleta.enlace)
        }
    }

    @ViewBuilder
    private func menuPeriodos<E: View>(@ViewBuilder etiqueta: () -> E) -> some View {
        Menu {
            ForEach(DepositosViewModel.periodosCercanos, id: \.self) { p in
                Button {
                    onCambiarPeriodo?(p)
                } label: {
                    if p == corte.registro.periodo {
                        Label(Fechas.periodoLegible(p), systemImage: "checkmark")
                    } else {
                        Text(Fechas.periodoLegible(p))
                    }
                }
            }
        } label: {
            etiqueta().foregroundStyle(Paleta.enlace)
        }
    }

    private func iconoChequeo(_ t: TipoChequeo) -> String {
        switch t {
        case .aviso: return "exclamationmark.circle.fill"
        case .ok: return "checkmark.circle.fill"
        case .duda: return "questionmark.circle.fill"
        }
    }
    private func colorChequeo(_ t: TipoChequeo) -> Color {
        switch t {
        case .aviso: return Paleta.aviso
        case .ok: return Paleta.brand
        case .duda: return .secondary
        }
    }

    // MARK: - Columna derecha (se registrará así + ficha)

    /// En regular (iPad) las dos tarjetas siguen juntas en su columna, con el
    /// botón dentro. En compacto el cuerpo las coloca por separado.
    private var columnaDerecha: some View {
        VStack(alignment: .leading, spacing: 16) {
            tarjetaRegistro(conBoton: true)
            tarjetaSegundaFirma
            tarjetaFicha
        }
    }

    private func tarjetaRegistro(conBoton: Bool) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 0) {
                TituloSeccion(texto: L.t("SE REGISTRARÁ ASÍ", "WILL BE RECORDED AS"))
                    .padding(.bottom, 8)
                filaCuenta
                Divider()
                filaFecha
                Divider()
                filaPeriodo
                Divider()
                filaRegistro(L.t("Monto", "Amount"), Money.fmt(corte.montoTotal), fuerte: true)

                if conBoton, corte.sinDepositar {
                    botonDepositar().padding(.top, 14)
                }
            }
        }
    }

    /// **La segunda firma.** Solo aparece si este corte la pidió: un corte que
    /// nació sin la marca no está incompleto —esa iglesia no usa doble firma, o
    /// ese domingo no hacía falta— y anunciarlo como pendiente sería convertir
    /// una opción en un reproche.
    @ViewBuilder
    private var tarjetaSegundaFirma: some View {
        if corte.dobleFirmaPedida {
            Tarjeta {
                VStack(alignment: .leading, spacing: 10) {
                    TituloSeccion(texto: L.t("SEGUNDA FIRMA", "SECOND SIGNATURE"))
                    if corte.tieneSegundaFirma {
                        firmaDada
                    } else if let contado = corte.segundaConteo {
                        // Contó y NO cuadró: la cifra queda escrita aunque no
                        // haya firma. Tirar ese número sería tirar justo el
                        // dato por el que se cuenta dos veces.
                        avisoFirma(.aviso,
                                   L.t("No cuadra", "It does not add up"),
                                   L.t("Se contó \(Money.fmt(contado)) y el corte dice \(Money.fmt(corte.montoTotal)). Quedó sin firmar.",
                                       "\(Money.fmt(contado)) was counted and the cut says \(Money.fmt(corte.montoTotal)). It was left unsigned."))
                        botonFirmar
                    } else {
                        avisoFirma(.aviso,
                                   L.t("Falta la segunda firma", "Second signature missing"),
                                   L.t("Este corte pidió que otra persona contara el dinero, y todavía nadie lo ha hecho.",
                                       "This cut asked for someone else to count the money, and nobody has yet."))
                        botonFirmar
                    }
                }
            }
        }
    }

    private var firmaDada: some View {
        VStack(alignment: .leading, spacing: 8) {
            avisoFirma(.ok, corte.segundaFirma ?? "", textoFirma)
            if corte.sinDepositar {
                Button(L.t("Quitar la firma", "Remove the signature")) { onQuitarFirma?() }
                    .font(.caption).buttonStyle(.borderless)
            }
        }
    }

    /// El modo se dice con sus palabras: contar el dinero y revisar el registro
    /// no son lo mismo, y confundirlos vacía el control.
    private var textoFirma: String {
        let cuando = corte.segundaFirmaEn.map { String($0.prefix(10)) } ?? ""
        if corte.modoSegundaFirma == .conteo, let c = corte.segundaConteo {
            return L.t("Contó \(Money.fmt(c)) · \(cuando)", "Counted \(Money.fmt(c)) · \(cuando)")
        }
        return L.t("Revisó el registro · \(cuando)", "Checked the record · \(cuando)")
    }

    private var botonFirmar: some View {
        Button { mostrarFirma = true } label: {
            Label(L.t("Segunda firma", "Second signature"),
                  systemImage: "signature").font(.subheadline)
        }
        .buttonStyle(.bordered)
        .tint(Color.secondary)
    }

    private func avisoFirma(_ tipo: TipoChequeo, _ titulo: String,
                            _ detalle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconoChequeo(tipo))
                .foregroundStyle(colorChequeo(tipo)).font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo).font(.subheadline.weight(.semibold))
                Text(detalle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// **El recibo del banco**, que ahora vive en el depósito y no en un texto.
    /// Antes esta tarjeta ofrecía "Adjuntar ficha" en un corte todavía sin
    /// depositar, guardaba el NOMBRE del archivo y tiraba el archivo. El recibo
    /// se pide donde se consigue: al registrar el depósito.
    @ViewBuilder
    private var tarjetaFicha: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                TituloSeccion(texto: L.t("RECIBO DEL BANCO", "BANK RECEIPT"))
                if let dep = corte.deposito {
                    if dep.tieneRecibo {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill").foregroundStyle(Paleta.brand)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.t("Guardado", "Saved")).font(.subheadline)
                                if dep.reciboSinSubir {
                                    Text(L.t("En el teléfono · sube cuando haya señal",
                                             "On the phone · uploads when there's signal"))
                                        .font(.caption).foregroundStyle(Paleta.aviso)
                                }
                            }
                            Spacer()
                        }
                    } else {
                        Text(L.t("Este depósito se registró sin recibo.",
                                 "This deposit was recorded without a receipt."))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !dep.referencia.isEmpty {
                        Divider()
                        filaRegistro(L.t("Referencia", "Reference"), dep.referencia)
                    }
                } else {
                    Text(L.t("Se pide al registrar el depósito: la foto del recibo se hace en el banco.",
                             "Asked for when recording the deposit: the receipt photo is taken at the bank."))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Sin cuenta o sin un peso seleccionado el botón va apagado: antes se
    /// podía confirmar un corte de $0.00 "Sin asignar", y salía de Pendientes
    /// sin que nadie hubiera ido al banco.
    ///
    /// **Un solo estilo, sin parámetro.** Tenía uno —`glass:`— para elegir
    /// entre glass en la barra del teléfono y relleno sólido en la tarjeta del
    /// iPad, pero las dos ramas rellenaban de verde con el texto en blanco:
    /// `.glassProminent` y `.borderedProminent` acaban en lo mismo. Ahora las
    /// dos usan `.glass`, así que el parámetro no distinguía nada.
    private func botonDepositar() -> some View {
        let apagado = corte.sinCuenta || corte.montoTotal == 0
        // `.glass` y no `.glassProminent`: el prominente rellena de verde con
        // el texto en blanco, que es lo que se quitó de la app. Sigue siendo la
        // acción principal por el peso de la tipografía y por ocupar el ancho.
        return Button { mostrarRegistro = true } label: {
            Text(L.t("Marcar depositado", "Mark deposited"))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
            .buttonStyle(.glass)
            .tint(Paleta.brand)
            .disabled(apagado)
    }

    /// La acción principal, fijada sobre el tab bar en compacto. Dentro del
    /// scroll caía a media página y con la ficha del banco por debajo.
    @ViewBuilder
    private var barraDepositar: some View {
        if sizeClass == .compact, corte.sinDepositar {
            // Flota sobre el contenido, como el pie de Ingresos/Gastos y de
            // Aportantes: el `Divider` + `.bar` era el patrón anterior a
            // Liquid Glass y dibujaba un filete duro de lado a lado. El
            // contenido se difumina por debajo con `scrollEdgeEffectStyle`.
            botonDepositar()
                .padding(.horizontal, Esp.pantalla)
                .padding(.bottom, Esp.hueco)
        }
    }

    /// Fila "Cuenta" con menú para asignar/cambiar la cuenta bancaria.
    private var filaCuenta: some View {
        HStack {
            Text(L.t("Cuenta", "Account")).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            if cuentas.isEmpty || !corte.sinDepositar {
                Text(corte.registro.cuenta).font(.subheadline)
            } else {
                menuCuentas {
                    HStack(spacing: 4) {
                        Text(corte.registro.cuenta).font(.subheadline)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                }
            }
        }
        .padding(.vertical, 9)
    }

    /// Fila "Fecha", editable. Un corte podía quedarse en "Por definir" y no
    /// había dónde definirla.
    private var filaFecha: some View {
        HStack {
            Text(L.t("Fecha", "Date")).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            if corte.sinDepositar {
                Button { mostrarFecha = true } label: {
                    HStack(spacing: 4) {
                        Text(Fechas.diaLegible(corte.registro.fecha)).font(.subheadline)
                        Image(systemName: "calendar").font(.caption2)
                    }
                    .foregroundStyle(Paleta.enlace)
                }
                .buttonStyle(.plain)
            } else {
                Text(Fechas.diaLegible(corte.registro.fecha)).font(.subheadline)
            }
        }
        .padding(.vertical, 9)
    }

    /// Fila "Periodo", editable. El checklist pedía cambiar el periodo desde el
    /// primer día y no existía el control para hacerlo.
    private var filaPeriodo: some View {
        HStack {
            Text(L.t("Periodo", "Period")).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            if corte.sinDepositar {
                menuPeriodos {
                    HStack(spacing: 4) {
                        Text(Fechas.periodoLegible(corte.registro.periodo)).font(.subheadline)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                }
            } else {
                Text(Fechas.periodoLegible(corte.registro.periodo)).font(.subheadline)
            }
        }
        .padding(.vertical, 9)
    }

    private var hojaFecha: some View {
        NavigationStack {
            DatePicker(L.t("Fecha del depósito", "Deposit date"),
                       selection: $fechaEditada, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(Esp.pantalla)
                .navigationTitle(L.t("Fecha del depósito", "Deposit date"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.t("Cancelar", "Cancel")) { mostrarFecha = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.t("Listo", "Done")) {
                            onCambiarFecha?(fechaEditada)
                            mostrarFecha = false
                        }
                        .fontWeight(.semibold).tint(Paleta.brand)
                    }
                }
        }
        .hojaEleccion()
    }

    private func filaRegistro(_ label: String, _ valor: String, fuerte: Bool = false) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(valor).font(.subheadline.weight(fuerte ? .bold : .regular)).monospacedDigit()
        }
        .padding(.vertical, 9)
    }
}
