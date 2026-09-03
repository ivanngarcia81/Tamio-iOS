import SwiftUI

/// Detalle de un corte de caja (depósito): cabecera con estado, tres chips KPI,
/// checklist "Antes de depositar", movimientos en caja, y la tarjeta "Se
/// registrará así" con la ficha del banco. Fiel al handoff. Los botones se
/// cablean por callbacks; la vista padre los enruta al ViewModel/repositorio.
struct CorteDetalle: View {
    let corte: Corte
    var cuentas: [String] = []
    var onNuevoCorte: (() -> Void)? = nil
    var onToggleMovimiento: ((Int) -> Void)? = nil
    var onAsignarCuenta: ((String) -> Void)? = nil
    var onAdjuntarFicha: ((String) -> Void)? = nil
    var onMarcarDepositado: (() -> Void)? = nil

    @State private var mostrarImportador = false
    @State private var confirmarDeposito = false
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
                    tarjetaFicha
                    tarjetaRegistro(conBoton: false)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) { columnaIzquierda; columnaDerecha.frame(width: 300) }
                        VStack(spacing: 16) { columnaIzquierda; columnaDerecha }
                    }
                }
            }
            .padding(24)
        }
        .colchonInferior()
        .safeAreaInset(edge: .bottom) { barraDepositar }
        .background(Color(.systemGroupedBackground))
        .fileImporter(isPresented: $mostrarImportador,
                      allowedContentTypes: [.image, .pdf],
                      allowsMultipleSelection: false) { resultado in
            if case .success(let urls) = resultado, let url = urls.first {
                onAdjuntarFicha?(url.lastPathComponent)
            }
        }
        .confirmationDialog(L.t("¿Marcar este corte como depositado?",
                                "Mark this cut as deposited?"),
                            isPresented: $confirmarDeposito, titleVisibility: .visible) {
            Button(L.t("Marcar depositado", "Mark deposited")) { onMarcarDepositado?() }
            Button(L.t("Cancelar", "Cancel"), role: .cancel) {}
        } message: {
            Text(L.t("Se registrará \(Money.fmt(corte.registro.monto)) en \(corte.registro.cuenta).",
                     "\(Money.fmt(corte.registro.monto)) will be recorded to \(corte.registro.cuenta)."))
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
                    Text(L.t("\(corte.seleccionados) de \(corte.totalSeleccionables) seleccionados",
                             "\(corte.seleccionados) of \(corte.totalSeleccionables) selected"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Paleta.brand)
                }
                .padding(.bottom, 10)

                filaChip(L.t("Efectivo seleccionado", "Cash selected"),
                         monto: corte.efectivoSeleccionado,
                         sub: L.t("De \(Money.fmt(corte.efectivoEstimado)) estimados en caja",
                                  "Of \(Money.fmt(corte.efectivoEstimado)) estimated on hand"))
                Divider()
                filaChip(L.t("Cheques (\(corte.chequesCount))", "Checks (\(corte.chequesCount))"),
                         monto: corte.chequesMonto,
                         sub: L.t("Se depositan con la misma ficha", "Deposited on the same slip"))
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
                        TituloSeccion(texto: L.t("MONTO", "AMOUNT"))
                    }
                    ForEach(Array(corte.movimientos.enumerated()), id: \.element.id) { i, m in
                        filaMovimiento(m)
                        if i < corte.movimientos.count - 1 { Divider() }
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
                    if let enlace = c.enlace { enlaceChequeo(enlace) }
                }
                Text(c.detalle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func filaMovimiento(_ m: MovimientoCaja) -> some View {
        Button { onToggleMovimiento?(m.id) } label: {
            HStack(spacing: 10) {
                Image(systemName: m.seleccionado ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(m.seleccionado ? Paleta.brand : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(m.categoria) · \(m.folio)").font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(m.cuando).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(Money.fmt(m.monto)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(m.seleccionado ? .primary : .secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// El enlace del checklist. "Asignar cuenta" abre un menú de cuentas; los
    /// demás son texto informativo (su destino llega en un slice posterior).
    @ViewBuilder
    private func enlaceChequeo(_ enlace: String) -> some View {
        if enlace == L.t("Asignar cuenta", "Assign account"), !cuentas.isEmpty {
            Menu {
                ForEach(cuentas, id: \.self) { cta in
                    Button(cta) { onAsignarCuenta?(cta) }
                }
            } label: {
                Text(enlace).font(.caption.weight(.semibold)).foregroundStyle(Paleta.enlace)
            }
        } else {
            Text(enlace).font(.caption).foregroundStyle(Paleta.enlace)
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
                filaRegistro(L.t("Fecha", "Date"), corte.registro.fecha)
                Divider()
                filaRegistro(L.t("Periodo", "Period"), corte.registro.periodo)
                Divider()
                filaRegistro(L.t("Monto", "Amount"), Money.fmt(corte.registro.monto), fuerte: true)

                if conBoton, corte.sinDepositar {
                    botonDepositar.padding(.top, 14)
                }
            }
        }
    }

    private var tarjetaFicha: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                TituloSeccion(texto: L.t("FICHA DEL BANCO", "BANK SLIP"))
                if let ficha = corte.fichaAdjunta {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill").foregroundStyle(Paleta.brand)
                        Text(ficha).font(.subheadline).lineLimit(1)
                        Spacer()
                        Button(L.t("Cambiar", "Change")) { mostrarImportador = true }
                            .font(.caption).buttonStyle(.borderless)
                    }
                } else {
                    Text(L.t("Foto o PDF de la ficha del banco", "Photo or PDF of the bank slip"))
                        .font(.subheadline)
                    Button { mostrarImportador = true } label: {
                        Label(L.t("Adjuntar ficha", "Attach slip"), systemImage: "paperclip")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.secondary)
                }
            }
        }
    }

    private var botonDepositar: some View {
        Button { confirmarDeposito = true } label: {
            Text(L.t("Marcar depositado", "Mark deposited"))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Paleta.brand)
    }

    /// La acción principal, fijada sobre el tab bar en compacto. Dentro del
    /// scroll caía a media página y con la ficha del banco por debajo.
    @ViewBuilder
    private var barraDepositar: some View {
        if sizeClass == .compact, corte.sinDepositar {
            VStack(spacing: 0) {
                Divider()
                botonDepositar
                    .padding(.horizontal, Esp.pantalla)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            .background(.bar)
        }
    }

    /// Fila "Cuenta" con menú para asignar/cambiar la cuenta bancaria.
    private var filaCuenta: some View {
        HStack {
            Text(L.t("Cuenta", "Account")).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            if cuentas.isEmpty {
                Text(corte.registro.cuenta).font(.subheadline)
            } else {
                Menu {
                    ForEach(cuentas, id: \.self) { cta in
                        Button(cta) { onAsignarCuenta?(cta) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(corte.registro.cuenta).font(.subheadline)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .foregroundStyle(Paleta.brand)
                }
            }
        }
        .padding(.vertical, 9)
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
