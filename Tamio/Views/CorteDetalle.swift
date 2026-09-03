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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cabecera
                chips
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { columnaIzquierda; columnaDerecha.frame(width: 300) }
                    VStack(spacing: 16) { columnaIzquierda; columnaDerecha }
                }
            }
            .padding(24)
        }
        .colchonInferior()
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
            HStack(alignment: .top) {
                Text(corte.titulo).font(.title.weight(.bold))
                if corte.sinDepositar {
                    Pill(texto: L.t("Sin depositar", "Not deposited"), color: Paleta.aviso)
                        .padding(.top, 6)
                }
                Spacer()
                Button { onNuevoCorte?() } label: {
                    Label(L.t("Nuevo corte", "New cut"), systemImage: "plus").font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(Color.secondary)
            }
            Text(corte.descripcion).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    // MARK: - Chips KPI

    private var chips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { chipEfectivo; chipCheques; chipListo }
            VStack(spacing: 12) { chipEfectivo; chipCheques; chipListo }
        }
    }

    private var chipEfectivo: some View {
        chip(titulo: L.t("Efectivo seleccionado", "Cash selected"),
             monto: corte.efectivoSeleccionado, verde: false,
             sub: L.t("De \(Money.fmt(corte.efectivoEstimado)) estimados en caja",
                      "Of \(Money.fmt(corte.efectivoEstimado)) estimated on hand"))
    }
    private var chipCheques: some View {
        chip(titulo: L.t("Cheques (\(corte.chequesCount))", "Checks (\(corte.chequesCount))"),
             monto: corte.chequesMonto, verde: false,
             sub: L.t("Se depositan con la misma ficha", "Deposited on the same slip"))
    }
    private var chipListo: some View {
        chip(titulo: L.t("Listo para depositar", "Ready to deposit"),
             monto: corte.listoParaDepositar, verde: true,
             sub: L.t("\(corte.seleccionados) de \(corte.totalSeleccionables) seleccionados",
                      "\(corte.seleccionados) of \(corte.totalSeleccionables) selected"))
    }

    private func chip(titulo: String, monto: Centavos, verde: Bool, sub: String) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                AmountText(cents: monto, size: 24, color: verde ? Paleta.brand : .primary)
                Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
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
                        TituloSeccion(texto: L.t("MOVIMIENTOS EN CAJA", "CASH ENTRIES"))
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

    private var columnaDerecha: some View {
        VStack(alignment: .leading, spacing: 16) {
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

                    if corte.sinDepositar {
                        Button { confirmarDeposito = true } label: {
                            Text(L.t("Marcar depositado", "Mark deposited"))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Paleta.brand)
                        .padding(.top, 14)
                    }
                }
            }
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
                    .foregroundStyle(Paleta.enlace)
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
