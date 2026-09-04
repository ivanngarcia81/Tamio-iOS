import SwiftUI

/// Página imprimible del "Estado financiero". Blanco y negro con verde de marca
/// solo en las cifras, según la ley de color. Es lo que se renderiza al PDF y lo
/// que se ve en la vista previa. Ancho fijo tamaño carta (lo envuelve PDFExport).
struct ReporteHojaPDF: View {
    let e: EstadoFinanciero
    /// El periodo sale del propio reporte. Venía por parámetro y era la clave
    /// cruda del filtro, así que la hoja podía encabezar un mes distinto del
    /// que traían las cifras.
    var periodo: String { e.periodo.etiqueta }
    /// El membrete sale de Ajustes. Antes el nombre de la iglesia estaba
    /// escrito dentro de esta vista, así que el documento no tenía forma de
    /// coincidir con lo que el tesorero había configurado.
    var iglesia: ConfiguracionIglesia = ConfiguracionIglesiaViewModel.compartido.config

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Membrete
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("Estado financiero", "Financial statement"))
                    .font(.system(.title, design: .serif).weight(.bold))
                Text(periodo).font(.headline).foregroundStyle(.secondary)
                if !iglesia.membrete.isEmpty {
                    Text(iglesia.membrete).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            Divider()

            // Resumen del mes
            VStack(spacing: 0) {
                filaResumen(L.t("Ingresos del mes", "Income this month"), e.ingresosMes, Paleta.brand)
                Divider()
                filaResumen(L.t("Gastos del mes", "Expenses this month"), e.gastosMes, Paleta.negativo)
                Divider()
                filaResumen(L.t("Balance neto", "Net balance"), e.balanceNeto, .primary, negrita: true)
            }
            .padding(Esp.tarjeta)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.3)))

            // **Lo que el documento deja fuera, dicho en el documento.** Solo
            // entra lo aprobado; un reporte que se firma no puede callar que
            // hay movimientos del mes esperando visto bueno.
            if e.pendientes > 0 {
                Text(e.pendientes == 1
                     ? L.t("No incluye 1 movimiento del periodo que espera visto bueno.",
                           "Excludes 1 transaction from this period awaiting approval.")
                     : L.t("No incluye \(e.pendientes) movimientos del periodo que esperan visto bueno.",
                           "Excludes \(e.pendientes) transactions from this period awaiting approval."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Ingresos y egresos por categoría. El % se mide contra el INGRESO
            // del periodo en las dos tablas: "los servicios fueron el 13% de lo
            // que entró" informa; "% de lo que gastamos" no dice nada nuevo. Es
            // la regla de la app web, escrita en su propio export.
            tablaCategorias(L.t("Ingresos del periodo", "Period income"),
                            e.composicion, total: e.ingresosMes, color: Paleta.brand,
                            vacia: L.t("Sin ingresos registrados", "No income recorded"))
            tablaCategorias(L.t("Gastos del periodo", "Period expenses"),
                            e.gastosPorCategoria, total: e.gastosMes, color: Paleta.negativo,
                            base: e.ingresosMes,
                            vacia: L.t("Sin gastos registrados", "No expenses recorded"))

            // **La ecuación contable**: saldo anterior + ingresos − egresos =
            // saldo final. Sin ella el documento daba el resultado suelto de un
            // mes y lo llamaba estado financiero, y el saldo de apertura que se
            // teclea en Ajustes no aparecía en ningún papel.
            Text(L.t("Saldo de tesorería", "Treasury balance")).font(.headline)
            VStack(spacing: 0) {
                filaSaldo(L.t("Saldo anterior", "Previous balance"), e.saldoAnterior)
                Divider()
                filaSaldo(L.t("Total de ingresos", "Total income"), e.ingresosMes)
                Divider()
                filaSaldo(L.t("Menos egresos", "Less expenses"), -e.gastosMes)
                Divider()
                filaSaldo(L.t("Saldo final", "Ending balance"), e.saldoFinal, negrita: true,
                          color: e.saldoFinal < 0 ? Paleta.negativo : Paleta.brand)
            }
            .padding(Esp.tarjeta)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.3)))

            // Depósitos bancarios del periodo.
            if !e.depositos.isEmpty {
                Text(L.t("Depósitos bancarios", "Bank deposits")).font(.headline)
                VStack(spacing: 0) {
                    HStack {
                        Text(L.t("FECHA", "DATE")).frame(width: 120, alignment: .leading)
                        Text(L.t("BANCO", "BANK")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(L.t("MONTO", "AMOUNT")).frame(width: 120, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    Divider()
                    ForEach(e.depositos) { d in
                        HStack {
                            Text(Fechas.diaLegible(d.fecha))
                                .frame(width: 120, alignment: .leading)
                            Text(d.referencia.isEmpty ? d.cuenta : "\(d.cuenta) · \(d.referencia)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Money.fmt(d.monto)).frame(width: 120, alignment: .trailing)
                        }
                        .font(.subheadline).monospacedDigit()
                        .padding(.vertical, 7)
                        Divider()
                    }
                    HStack {
                        Text(L.t("Total depositado", "Total deposited")).fontWeight(.semibold)
                        Spacer()
                        Text(Money.fmt(e.depositosTotal)).fontWeight(.semibold).monospacedDigit()
                    }
                    .font(.subheadline).padding(.vertical, 7)
                }
                // Sin esta línea, un total de depósitos mayor que el ingreso del
                // mes se lee como un descuadre. No lo es: un depósito puede
                // llevar al banco efectivo que se recibió en meses anteriores.
                Text(L.t("Los depósitos mueven efectivo de la caja al banco: no son ingresos y no entran en el saldo. Pueden incluir dinero recibido en periodos anteriores.",
                         "Deposits move cash from the box to the bank: they are not income and are not part of the balance. They may include money received in earlier periods."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Tabla mensual
            Text(L.t("Resumen mensual", "Monthly summary")).font(.headline)
            VStack(spacing: 0) {
                HStack {
                    Text(L.t("MES", "MONTH")).frame(maxWidth: .infinity, alignment: .leading)
                    Text(L.t("INGRESOS", "INCOME")).frame(width: 110, alignment: .trailing)
                    Text(L.t("GASTOS", "EXPENSES")).frame(width: 110, alignment: .trailing)
                    Text(L.t("BALANCE", "BALANCE")).frame(width: 110, alignment: .trailing)
                }
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.vertical, 8)
                Divider()
                ForEach(e.mensual) { f in
                    HStack {
                        Text(f.mes).frame(maxWidth: .infinity, alignment: .leading)
                        Text(Money.fmt(f.ingresos)).foregroundStyle(Paleta.brand).frame(width: 110, alignment: .trailing)
                        Text(Money.fmt(f.gastos)).foregroundStyle(Paleta.negativo).frame(width: 110, alignment: .trailing)
                        Text(Money.fmt(f.balance)).fontWeight(.semibold).frame(width: 110, alignment: .trailing)
                    }
                    .font(.subheadline).monospacedDigit()
                    .padding(.vertical, 7)
                    if f.id != e.mensual.last?.id { Divider() }
                }
            }

            FirmasPDF(iglesia: iglesia)
            PieInstitucionalPDF(iglesia: iglesia)

            Text(L.t("Generado por Tamio", "Generated by Tamio"))
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(Esp.hoja)
        .frame(width: PDFExport.anchoCarta, alignment: .leading)
        .background(.white)
        .environment(\.colorScheme, .light)   // el PDF siempre en claro
    }

    /// Una tabla de categorías con su porcentaje. `base` es contra qué se mide
    /// el %: por omisión el propio total, y el ingreso del periodo en la tabla
    /// de gastos.
    @ViewBuilder
    private func tablaCategorias(_ titulo: String, _ filas: [CategoriaMonto],
                                 total: Centavos, color: Color,
                                 base: Centavos? = nil, vacia: String) -> some View {
        Text(titulo).font(.headline)
        VStack(spacing: 0) {
            if filas.isEmpty {
                HStack {
                    Text(vacia).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 7)
            }
            ForEach(filas) { c in
                HStack {
                    Text(c.nombre).frame(maxWidth: .infinity, alignment: .leading)
                    Text(Money.fmt(c.monto)).foregroundStyle(color).frame(width: 120, alignment: .trailing)
                    Text(pct(c.monto, de: base ?? total)).foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                .font(.subheadline).monospacedDigit()
                .padding(.vertical, 7)
                Divider()
            }
            HStack {
                // "Total", no el título de la tabla otra vez: la fila de cierre
                // dice cuánto suma, no de qué tabla es.
                Text(L.t("Total", "Total")).fontWeight(.semibold)
                Spacer()
                Text(Money.fmt(total)).fontWeight(.semibold).monospacedDigit()
                    .frame(width: 120, alignment: .trailing)
                Text("").frame(width: 60)
            }
            .font(.subheadline).padding(.vertical, 7)
        }
    }

    private func pct(_ parte: Centavos, de total: Centavos) -> String {
        guard total > 0 else { return "—" }
        return "\(Int((Double(parte) / Double(total) * 100).rounded()))%"
    }

    private func filaSaldo(_ label: String, _ monto: Centavos,
                           negrita: Bool = false, color: Color = .primary) -> some View {
        HStack {
            Text(label).font(negrita ? .body.weight(.semibold) : .body)
            Spacer()
            Text(Money.fmt(monto))
                .font((negrita ? Font.title3 : Font.body).weight(negrita ? .semibold : .regular))
                .monospacedDigit().foregroundStyle(color)
        }
        .padding(.vertical, 8)
    }

    private func filaResumen(_ label: String, _ monto: Centavos, _ color: Color, negrita: Bool = false) -> some View {
        HStack {
            Text(label).font(negrita ? .body.weight(.semibold) : .body)
            Spacer()
            Text(Money.fmt(monto))
                .font((negrita ? Font.title3 : Font.body).weight(.semibold))
                .monospacedDigit().foregroundStyle(color)
        }
        .padding(.vertical, 8)
    }
}

/// Hoja modal de "Vista previa PDF": muestra la página imprimible y permite
/// compartir/exportar el PDF real generado con ImageRenderer.
struct ReportePDFSheet: View {
    let e: EstadoFinanciero
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            // Vertical y nada más: el scroll horizontal existía para poder
            // llegar a la mitad derecha de una hoja que no cabía. Escalada,
            // cabe entera.
            ScrollView {
                HojaCartaEscalada { ReporteHojaPDF(e: e) }
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    .padding(Esp.panel)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t("Vista previa PDF", "PDF preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cerrar", "Close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .onAppear {
            pdfURL = PDFExport.render(ReporteHojaPDF(e: e),
                                      // La clave del periodo y no el mes escrito:
                                      // el nombre del archivo ordena bien y no
                                      // cambia según el idioma del aparato.
                                      nombre: "Estado-financiero-\(e.periodo.clave)")
        }
    }
}


/// Bloque de firmas al pie de un documento. Las líneas salen de Ajustes y solo
/// se imprimen las de quien tiene nombre: una raya con un cargo debajo y nadie
/// encima no vale para nada.
struct FirmasPDF: View {
    let iglesia: ConfiguracionIglesia
    /// Las firmas guardadas en ESTE aparato. No viajan: un documento generado
    /// desde otro teléfono sale con la raya en blanco, y eso es lo esperado
    /// (ver `FirmasLocales`).
    var firmas: FirmasLocales = .compartidas

    var body: some View {
        let firmantes = iglesia.firmantes
        if !firmantes.isEmpty {
            VStack(alignment: .leading, spacing: 28) {
                Divider()
                HStack(alignment: .top, spacing: 32) {
                    ForEach(Array(firmantes.enumerated()), id: \.offset) { i, f in
                        VStack(spacing: 6) {
                            // La firma va ENCIMA de la raya, no en lugar de
                            // ella: así el documento se lee igual esté firmado
                            // en la app o a mano sobre el papel, y quien no
                            // tenga firma guardada sigue teniendo dónde firmar.
                            if let imagen = firma(para: i) {
                                Image(uiImage: imagen)
                                    .resizable().scaledToFit()
                                    .frame(height: 34)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Color.clear.frame(height: 34)
                            }
                            Rectangle().fill(.secondary.opacity(0.5))
                                .frame(height: 0.75)
                            Text(f.nombre).font(.caption.weight(.semibold))
                            Text(f.cargo).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    /// `firmantes` va en orden pastor, tesorero, secretario, y solo trae a los
    /// que tienen nombre: por eso no vale el índice para saber quién es cada
    /// uno. Se compara con el nombre configurado.
    private func firma(para indice: Int) -> UIImage? {
        let f = iglesia.firmantes[indice]
        if f.nombre == iglesia.tesoreroNombre { return firmas.imagen(.tesorero) }
        if f.nombre == iglesia.pastorNombre { return firmas.imagen(.pastor) }
        return nil
    }
}

/// Pie institucional: la línea libre de Ajustes, con los datos de contacto.
struct PieInstitucionalPDF: View {
    let iglesia: ConfiguracionIglesia

    private var contacto: String {
        [iglesia.direccion, iglesia.telefono, iglesia.correo]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !contacto.isEmpty {
                Text(contacto).font(.caption2).foregroundStyle(.secondary)
            }
            if !iglesia.pieInstitucional.isEmpty {
                Text(iglesia.pieInstitucional).font(.caption2).foregroundStyle(.secondary)
            }
            if !iglesia.idFiscal.isEmpty {
                Text(L.t("ID fiscal: \(iglesia.idFiscal)", "Tax ID: \(iglesia.idFiscal)"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// Página imprimible del "Reporte anual": los doce meses en una hoja. Es el
/// segundo documento del dominio, y hasta ahora la lista de Reportes lo
/// prometía con un "Próximamente".
struct ReporteAnualHojaPDF: View {
    let a: ReporteAnual
    var iglesia: ConfiguracionIglesia = ConfiguracionIglesiaViewModel.compartido.config

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("Reporte anual", "Annual report"))
                    .font(.system(.title, design: .serif).weight(.bold))
                Text(a.anio).font(.headline).foregroundStyle(.secondary)
                if !iglesia.membrete.isEmpty {
                    Text(iglesia.membrete).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            Divider()

            // Resumen por mes, con el total del año cerrando la tabla.
            Text(L.t("Resumen por mes", "Summary by month")).font(.headline)
            VStack(spacing: 0) {
                HStack {
                    Text(L.t("MES", "MONTH")).frame(maxWidth: .infinity, alignment: .leading)
                    Text(L.t("INGRESOS", "INCOME")).frame(width: 110, alignment: .trailing)
                    Text(L.t("GASTOS", "EXPENSES")).frame(width: 110, alignment: .trailing)
                    Text(L.t("BALANCE", "BALANCE")).frame(width: 110, alignment: .trailing)
                }
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.vertical, 8)
                Divider()
                if a.meses.isEmpty {
                    HStack {
                        Text(L.t("Sin movimientos en \(a.anio)", "No activity in \(a.anio)"))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 7)
                }
                ForEach(a.meses) { f in
                    HStack {
                        Text(f.mes).frame(maxWidth: .infinity, alignment: .leading)
                        Text(Money.fmt(f.ingresos)).foregroundStyle(Paleta.brand).frame(width: 110, alignment: .trailing)
                        Text(Money.fmt(f.gastos)).foregroundStyle(Paleta.negativo).frame(width: 110, alignment: .trailing)
                        Text(Money.fmt(f.balance)).frame(width: 110, alignment: .trailing)
                    }
                    .font(.subheadline).monospacedDigit()
                    .padding(.vertical, 7)
                    Divider()
                }
                HStack {
                    Text(L.t("Total \(a.anio)", "Total \(a.anio)")).fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Money.fmt(a.totalIngresos)).foregroundStyle(Paleta.brand).frame(width: 110, alignment: .trailing)
                    Text(Money.fmt(a.totalGastos)).foregroundStyle(Paleta.negativo).frame(width: 110, alignment: .trailing)
                    Text(Money.fmt(a.balance)).frame(width: 110, alignment: .trailing)
                }
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .padding(.vertical, 8)
            }

            if a.pendientes > 0 {
                Text(a.pendientes == 1
                     ? L.t("No incluye 1 movimiento del año que espera visto bueno.",
                           "Excludes 1 transaction from this year awaiting approval.")
                     : L.t("No incluye \(a.pendientes) movimientos del año que esperan visto bueno.",
                           "Excludes \(a.pendientes) transactions from this year awaiting approval."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            // El % de ingreso va contra el ingreso del año y el de gasto contra
            // el gasto del año: en el anual la pregunta es cómo se repartió
            // cada lado, no qué proporción del ingreso se gastó. Es la regla de
            // la app web, y difiere a propósito del reporte mensual.
            tabla(L.t("Ingresos por categoría", "Income by category"),
                  a.ingresosPorCategoria, total: a.totalIngresos, color: Paleta.brand)
            tabla(L.t("Gastos por categoría", "Expenses by category"),
                  a.gastosPorCategoria, total: a.totalGastos, color: Paleta.negativo)

            HStack {
                Text(L.t("Depositado en el banco durante el año", "Deposited to the bank during the year"))
                Spacer()
                Text(Money.fmt(a.depositosTotal)).fontWeight(.semibold).monospacedDigit()
            }
            .font(.subheadline)
            .padding(Esp.tarjeta)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.3)))

            FirmasPDF(iglesia: iglesia)
            PieInstitucionalPDF(iglesia: iglesia)

            Text(L.t("Generado por Tamio", "Generated by Tamio"))
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(Esp.hoja)
        .frame(width: PDFExport.anchoCarta, alignment: .leading)
        .background(.white)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private func tabla(_ titulo: String, _ filas: [CategoriaMonto],
                       total: Centavos, color: Color) -> some View {
        Text(titulo).font(.headline)
        VStack(spacing: 0) {
            if filas.isEmpty {
                HStack {
                    Text(L.t("Sin movimientos en el año", "No activity this year"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 7)
            }
            ForEach(filas) { c in
                HStack {
                    Text(c.nombre).frame(maxWidth: .infinity, alignment: .leading)
                    Text(Money.fmt(c.monto)).foregroundStyle(color).frame(width: 120, alignment: .trailing)
                    Text(total > 0 ? "\(Int((Double(c.monto) / Double(total) * 100).rounded()))%" : "—")
                        .foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                }
                .font(.subheadline).monospacedDigit()
                .padding(.vertical, 7)
                Divider()
            }
            HStack {
                Text(L.t("Total", "Total")).fontWeight(.semibold)
                Spacer()
                Text(Money.fmt(total)).fontWeight(.semibold).monospacedDigit()
                    .frame(width: 120, alignment: .trailing)
                Text(total > 0 ? "100%" : "").foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
            }
            .font(.subheadline).padding(.vertical, 7)
        }
    }
}

/// Hoja modal de vista previa del reporte anual.
struct ReporteAnualPDFSheet: View {
    let a: ReporteAnual
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                HojaCartaEscalada { ReporteAnualHojaPDF(a: a) }
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    .padding(Esp.panel)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t("Vista previa PDF", "PDF preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cerrar", "Close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .onAppear {
            pdfURL = PDFExport.render(ReporteAnualHojaPDF(a: a),
                                      nombre: "Reporte-anual-\(a.anio)")
        }
    }
}
