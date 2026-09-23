import SwiftUI
import AppKit
import Charts

/// **Reportes, según el handoff.**
///
/// A la izquierda los dos reportes de tesorería —estado financiero y anual—,
/// y a la derecha el resumen en pantalla: cuatro cifras con su barra de color,
/// el aviso de lo que espera aprobación, las tarjetas del periodo y la tabla
/// por meses. Un conmutador cambia el resumen por la vista de la hoja impresa.
///
/// **El conmutador es la pieza que da sentido a la pantalla.** Un reporte
/// existe para salir en PDF, pero decidir sobre él mirando una hoja es
/// incómodo: el resumen sirve para leer, la hoja para comprobar cómo va a
/// imprimirse. Tenerlos separados y a un clic es mejor que un compromiso.
struct PantallaReportes: View {
    let vm: ReportesViewModel
    @Binding var verHoja: Bool
    /// La vista de AppKit bajo el botón "Compartir". `NSSharingServicePicker`
    /// necesita una `NSView` de la que colgar su menú, y SwiftUI no da la del
    /// botón: se la damos nosotros con un ancla invisible en su fondo.
    @State private var anclaCompartir = AnclaCompartir()

    var body: some View {
        // **`HStack` y no `HSplitView`, y es por una medida.**
        //
        // El `HSplitView` de macOS no comprime por debajo del tamaño IDEAL de
        // sus paneles, así que esta pantalla imponía un ancho mínimo de ventana
        // de más de **2000 puntos** —más que la pantalla de Iván— y la ventana
        // se quedaba estancada: no se podía achicar ni ajustar. Medido con
        // `set size` en las quince secciones; las tres que usaban `HSplitView`
        // —Reportes, Cartas y Registro de servicios— eran las únicas que no
        // cedían, contra los 964 de una tabla.
        //
        // Lo que se pierde es arrastrar el divisor. Lo que se gana es que la
        // ventana se pueda usar en media pantalla, que es como se trabaja con
        // dos ventanas al lado.
        HStack(spacing: 0) {
            listaDeTipos
                .frame(width: 248)
            Divider()
            // **560 y no 260** (23-sep). Con 260 la ventana bajaba a 761 y el
            // contenido no cabía en lo que quedaba: se montaba 23 pt sobre la
            // lista, truncaba los selectores («Septem…», «All cate…») y los
            // rótulos de las tarjetas, y la tabla perdía la columna del mes.
            // Caber rompiendo es peor que no caber (`a3bb7b3`): con esto
            // Reportes ya NO cabe en media pantalla de 900, y hacerlo caber es
            // rediseño (plegar la lista de tipos), como ya decía §0.-22.
            contenido
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await vm.cargar() }
    }

    // MARK: - Los reportes

    private var listaDeTipos: some View {
        // Cambiar de reporte NO recarga: `cargar()` trae el estado mensual y
        // el anual a la vez, así que esto solo elige cuál se enseña.
        List(selection: Binding(
            get: { vm.seleccionId },
            set: { vm.seleccionId = $0 ?? vm.seleccionId }
        )) {
            Section(L.t("TESORERÍA", "TREASURY")) {
                ForEach(vm.tipos) { t in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.titulo).font(.system(size: 12.5, weight: .semibold))
                        Text(t.subtitulo)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                    .tag(t.id)
                }
            }
        }
    }

    // MARK: - Resumen u hoja

    @ViewBuilder
    private var contenido: some View {
        VStack(spacing: 0) {
            barra
            if vm.cargando {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.sinDatos {
                ContentUnavailableView {
                    Label(L.t("Sin datos en el periodo", "No data for this period"),
                          systemImage: "chart.bar")
                } description: {
                    Text(L.t("Cuando se capturen movimientos aparecerán aquí.",
                             "Once transactions are captured they'll show up here."))
                }
                .frame(maxHeight: .infinity)
            } else if verHoja {
                // La sombra, aquí y no en la hoja (que es la que se imprime).
                // `compositingGroup` para que sombree el papel entero y no
                // cada texto por separado.
                ScrollView {
                    hoja.compositingGroup()
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                        .padding(28)
                }
                    .background(Color.suelo)
            } else {
                ScrollView { resumen.padding(22) }
                    .background(Color.suelo)
            }
        }
    }

    private var barra: some View {
        HStack(spacing: 10) {
            // **Selectores de verdad, no rótulos.** El handoff los dibuja como
            // texto porque una maqueta no navega; aquí los periodos y los años
            // salen de los datos (`repo.periodos()`, `repo.anios()`), así que
            // elegir uno recarga el reporte.
            if vm.esAnual {
                Picker("", selection: Binding(
                    get: { vm.anioSel },
                    set: { a in Task { await vm.seleccionarAnio(a) } }
                )) {
                    ForEach(vm.anios, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                // **Acotado, no `fixedSize`.**
                //
                // Con `fixedSize` el selector pide el ancho de su opción más
                // larga, y estas opciones son DATOS: los nombres de categoría
                // que escribe la iglesia. Una categoría larga empujaba el ancho
                // mínimo de la ventana hasta **2081 puntos** —más que la
                // pantalla— y entonces la ventana ya no se podía achicar ni
                // cambiar de tamaño. Medido con `set size` en las quince
                // secciones: Reportes era la única que no cabía.
                .frame(maxWidth: 220)
            } else {
                Picker("", selection: Binding(
                    get: { vm.periodoSel },
                    set: { c in Task { await vm.seleccionarPeriodo(c) } }
                )) {
                    ForEach(vm.periodos) { Text($0.etiqueta).tag($0.clave) }
                }
                .labelsHidden()
                // **Acotado, no `fixedSize`.**
                //
                // Con `fixedSize` el selector pide el ancho de su opción más
                // larga, y estas opciones son DATOS: los nombres de categoría
                // que escribe la iglesia. Una categoría larga empujaba el ancho
                // mínimo de la ventana hasta **2081 puntos** —más que la
                // pantalla— y entonces la ventana ya no se podía achicar ni
                // cambiar de tamaño. Medido con `set size` en las quince
                // secciones: Reportes era la única que no cabía.
                .frame(maxWidth: 220)

                Picker("", selection: Binding(
                    get: { vm.categoriaSel ?? "" },
                    set: { c in Task { await vm.seleccionarCategoria(c.isEmpty ? nil : c) } }
                )) {
                    Text(L.t("Todas las categorías", "All categories")).tag("")
                    ForEach(vm.categorias, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                // **Acotado, no `fixedSize`.**
                //
                // Con `fixedSize` el selector pide el ancho de su opción más
                // larga, y estas opciones son DATOS: los nombres de categoría
                // que escribe la iglesia. Una categoría larga empujaba el ancho
                // mínimo de la ventana hasta **2081 puntos** —más que la
                // pantalla— y entonces la ventana ya no se podía achicar ni
                // cambiar de tamaño. Medido con `set size` en las quince
                // secciones: Reportes era la única que no cabía.
                .frame(maxWidth: 220)
            }
            Spacer(minLength: 0)
            Button(verHoja ? L.t("Resumen en pantalla", "On-screen summary")
                           : L.t("Vista previa PDF", "PDF preview")) {
                verHoja.toggle()
            }
            .buttonStyle(.bordered)
            .font(.system(size: 12))
            Button {
                compartirPDF()
            } label: {
                Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
            }
            // **Solo el icono**, como la acción de PDF del iPhone. Con la
            // palabra, la cabecera pasó de 729 a 761 pt de mínimo y por debajo
            // de ~900 el contenido se montaba sobre la lista y truncaba los
            // selectores («Septe…», «PDF prev…»). El nombre sigue en `help` y
            // en VoiceOver.
            .labelStyle(.iconOnly)
            .help(L.t("Compartir PDF", "Share PDF"))
            .buttonStyle(.bordered)
            .font(.system(size: 12))
            // Sin datos no hay hoja que imprimir: un PDF con el membrete y
            // nada debajo parecería un reporte de un mes en ceros.
            .disabled(vm.cargando || vm.sinDatos || (vm.esAnual ? vm.anual == nil : vm.estado == nil))
            .background(VistaAncla(ancla: anclaCompartir))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Compartir

    /// **El PDF que se comparte es la misma hoja de "Vista previa PDF".**
    ///
    /// No hay un segundo generador: `hoja` es la vista que se enseña al
    /// pulsar la vista previa, y `PDFExport.render` —el mismo que usa el
    /// iPhone— la pasa a páginas carta. Así lo que se ve antes de compartir es
    /// exactamente lo que sale, que es la promesa de la vista previa.
    ///
    /// Se genera al pulsar y no antes: el periodo o el año pueden cambiar
    /// entre que se abre la pantalla y se comparte, y un PDF hecho de
    /// antemano se quedaría con las cifras viejas.
    private func compartirPDF() {
        // La clave del periodo y no el mes escrito, como en el iPhone: el
        // nombre del archivo ordena bien y no cambia con el idioma.
        let nombre = vm.esAnual
            ? "Reporte-anual-\(vm.anioSel)"
            : "Estado-financiero-\(vm.estado?.periodo.clave ?? vm.periodoSel)"
        guard let url = PDFExport.render(hoja, nombre: nombre),
              let vista = anclaCompartir.vista else { return }
        NSSharingServicePicker(items: [url])
            .show(relativeTo: vista.bounds, of: vista, preferredEdge: .minY)
    }

    // MARK: - El resumen

    @ViewBuilder
    private var resumen: some View {
        VStack(alignment: .leading, spacing: 12) {
            cifras
            if pendientes > 0 { avisoPendientes }
            if vm.esAnual { cuerpoAnual } else { cuerpoMensual }
        }
    }

    private var pendientes: Int {
        vm.esAnual ? (vm.anual?.pendientes ?? 0) : (vm.estado?.pendientes ?? 0)
    }

    /// **El aviso va ENCIMA de las tarjetas, no al pie.**
    ///
    /// Lo que dice es que las cifras de arriba están incompletas. Puesto
    /// debajo, alguien ya leyó los números y se formó una idea antes de
    /// enterarse de que faltaba algo.
    private var avisoPendientes: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Paleta.aviso)
            Text(pendientes == 1
                 ? L.t("1 movimiento espera visto bueno y no está en estas cifras.",
                       "1 transaction is awaiting approval and isn't in these figures.")
                 : L.t("\(pendientes) movimientos esperan visto bueno y no están en estas cifras.",
                       "\(pendientes) transactions are awaiting approval and aren't in these figures."))
                .font(.system(size: 12.5))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Paleta.aviso.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private var cifras: some View {
        VStack(alignment: .leading, spacing: 9) {
            bandaDePantalla
            filaDeCifras
        }
    }

    @ViewBuilder
    private var filaDeCifras: some View {
        HStack(spacing: 12) {
            if vm.esAnual, let a = vm.anual {
                cifra(L.t("Ingresos del año", "Income for the year"),
                      Money.fmt(a.totalIngresos), Paleta.brand, nil, nil)
                cifra(L.t("Gastos del año", "Expenses for the year"),
                      Money.fmt(a.totalGastos), Paleta.negativo, nil, nil)
                cifra(L.t("Balance del año", "Year balance"),
                      Money.fmt(a.balance), Paleta.brand,
                      L.t("ingresos menos gastos", "income less expenses"), nil)
                // La cuarta cifra del handoff. Va aparte y con su nota porque
                // un depósito no es un ingreso: es efectivo que pasa de la caja
                // al banco, y sumarlo de cabeza al balance lo inflaría.
                cifra(L.t("Depositado", "Deposited"),
                      Money.fmt(a.depositosTotal), Paleta.placaMorado,
                      L.t("no suma al balance", "not part of the balance"), nil)
            } else if let e = vm.estado {
                cifra(L.t("Ingresos del mes", "Income this month"),
                      Money.fmt(e.ingresosMes), Paleta.brand,
                      nota(e.deltaIngresos, e), tintaDelta(e.deltaIngresos, alRevés: false))
                cifra(L.t("Gastos del mes", "Expenses this month"),
                      Money.fmt(e.gastosMes), Paleta.negativo,
                      nota(e.deltaGastos, e), tintaDelta(e.deltaGastos, alRevés: true))
                cifra(L.t("Balance neto", "Net balance"),
                      Money.fmt(e.balanceNeto), Paleta.brand,
                      nota(e.deltaBalance, e), tintaDelta(e.deltaBalance, alRevés: false))
                cifra(L.t("Saldo al cierre", "Ending balance"),
                      Money.fmt(e.saldoFinal), Paleta.placaMorado,
                      L.t("incluye el saldo anterior", "including previous balance"), nil)
            }
        }
    }

    /// "▲ 12,8 % vs agosto". Sin mes anterior no hay nota: el handoff la
    /// escribe siempre porque su maqueta siempre tiene con qué comparar.
    private func nota(_ delta: Double?, _ e: EstadoFinanciero) -> String? {
        guard let delta, let mes = e.mesAnteriorNombre else { return nil }
        let flecha = delta >= 0 ? "▲" : "▼"
        let pct = String(format: "%.1f", abs(delta * 100))
        return "\(flecha) \(pct)% \(L.t("vs", "vs")) \(mes)"
    }

    private func tintaDelta(_ delta: Double?, alRevés: Bool) -> Color? {
        guard let delta else { return nil }
        let bueno = alRevés ? delta < 0 : delta > 0
        return bueno ? Paleta.brand : Paleta.negativo
    }

    /// **Lo de pantalla no es lo del papel, y hay que decirlo.**
    ///
    /// El handoff pone esta banda sobre las cuatro cifras. Sin ella, quien mira
    /// el resumen da por hecho que el PDF que va a firmar dice lo mismo, y el
    /// PDF lleva otra cosa: el estado de cuenta, no las comparativas contra el
    /// mes pasado.
    private var bandaDePantalla: some View {
        HStack(spacing: 8) {
            Text(L.t("RESUMEN EN PANTALLA", "ON-SCREEN SUMMARY"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(L.t("No se incluye en el PDF", "Not included in the PDF"))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private func cifra(_ k: String, _ v: String, _ barra: Color,
                       _ nota: String?, _ notaTinta: Color?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // La barra de color de la maqueta, que es lo que deja distinguir
            // las cuatro tarjetas de un vistazo sin leer el rótulo.
            Capsule().fill(barra).frame(width: 34, height: 3)
            // **Hasta dos líneas, no una** (23-sep): al ancho mínimo, «Income
            // this month» salía «Income this…». Un rótulo partido en dos
            // renglones se lee; uno truncado obliga a adivinar.
            Text(k).font(.system(size: 12)).foregroundStyle(.secondary)
                .padding(.top, 10).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(v)
                .font(.system(size: 21, weight: .bold)).monospacedDigit()
                .padding(.top, 4).lineLimit(1).minimumScaleFactor(0.6)
            if let nota {
                Text(nota)
                    .font(.system(size: 11.5))
                    .foregroundStyle(notaTinta ?? .secondary)
                    // Tres: «including previous balance» no cabe en dos al mínimo.
                    .padding(.top, 4).lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tarjetaMac(14)
    }

    // MARK: - Mensual

    @ViewBuilder
    private var cuerpoMensual: some View {
        if let e = vm.estado {
            if !e.saldoSerie.isEmpty { saldoDelPeriodo(e) }
            HStack(alignment: .top, spacing: 12) {
                panel(L.t("INGRESOS POR CATEGORÍA", "INCOME BY CATEGORY")) {
                    dona(e.composicion)
                }
                panel(L.t("GASTOS POR CATEGORÍA", "EXPENSES BY CATEGORY")) {
                    barras(e.gastosPorCategoria, total: e.gastoTotal, tinta: Paleta.negativo)
                }
            }
            if !e.depositos.isEmpty {
                panel(L.t("DEPÓSITOS DEL PERIODO", "PERIOD DEPOSITS")) {
                    VStack(spacing: 0) {
                        ForEach(e.depositos) { d in
                            HStack(spacing: 10) {
                                Text(d.fecha.isEmpty ? "—" : Fechas.diaLegible(d.fecha))
                                    .font(.system(size: 12)).foregroundStyle(.secondary)
                                Text(d.cuenta).font(.system(size: 12.5, weight: .medium))
                                Spacer(minLength: 8)
                                Text(Money.fmt(d.monto))
                                    .font(.system(size: 12.5, weight: .semibold)).monospacedDigit()
                            }
                            .padding(.vertical, 7)
                            .overlay(alignment: .bottom) { Divider() }
                        }
                        HStack {
                            Text(L.t("Total depositado", "Total deposited"))
                                .font(.system(size: 12, weight: .semibold))
                            Spacer(minLength: 0)
                            Text(Money.fmt(e.depositosTotal))
                                .font(.system(size: 12.5, weight: .bold)).monospacedDigit()
                        }
                        .padding(.top, 9)
                        // Sin esta línea, un total depositado mayor que lo
                        // ingresado en el mes parece un descuadre. No lo es:
                        // el depósito arrastra efectivo de meses anteriores.
                        Text(L.t("No suman al saldo: mueven efectivo de la caja al banco.",
                                 "Not added to the balance: they move cash from the box to the bank."))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    .padding(.top, 10)
                }
            }
            if !e.mensual.isEmpty { tablaDeMeses(e.mensual) }
        }
    }

    /// **El balance de los últimos meses, en barras.**
    ///
    /// Va en su propia fila y no al lado de las dos de categorías: tres
    /// tarjetas en una fila, en media pantalla, dejaban la dona tan estrecha
    /// que no se leía su centro. La barra del mes elegido va en el color de la
    /// marca y las anteriores apagadas, como en el iPhone, para que se vea de
    /// un vistazo cuál es "este" mes.
    private func saldoDelPeriodo(_ e: EstadoFinanciero) -> some View {
        panel(L.t("SALDO DEL PERIODO", "PERIOD BALANCE")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Money.fmt(e.balanceNeto))
                    .font(.system(size: 21, weight: .bold)).monospacedDigit()
                    .foregroundStyle(e.balanceNeto >= 0 ? Color.primary : Paleta.negativo)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Chart(e.saldoSerie) { m in
                    BarMark(x: .value("Mes", m.mes),
                            y: .value("Saldo", Double(m.monto) / 100))
                        .foregroundStyle(m.mes == e.saldoSerie.last?.mes
                                         ? Paleta.brand : Paleta.brandMuted)
                        .cornerRadius(3)
                }
                .chartYAxis(.hidden)
                .frame(height: 70)
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Anual

    @ViewBuilder
    private var cuerpoAnual: some View {
        if let a = vm.anual {
            HStack(alignment: .top, spacing: 12) {
                panel(L.t("INGRESOS POR CATEGORÍA", "INCOME BY CATEGORY")) {
                    dona(a.ingresosPorCategoria)
                }
                panel(L.t("GASTOS POR CATEGORÍA", "EXPENSES BY CATEGORY")) {
                    barras(a.gastosPorCategoria, total: a.totalGastos, tinta: Paleta.negativo)
                }
            }
            if !a.meses.isEmpty { tablaDeMeses(a.meses) }
        }
    }

    /// El resumen por meses: ingresos, gastos y balance. La columna de balance
    /// va en verde o en rojo según el signo — un mes en números rojos tiene que
    /// verse sin leer la cifra.
    private func tablaDeMeses(_ filas: [FilaMensual]) -> some View {
        panel(L.t("RESUMEN POR MESES", "SUMMARY BY MONTH")) {
            VStack(spacing: 0) {
                HStack {
                    Text(L.t("Mes", "Month")).frame(maxWidth: .infinity, alignment: .leading)
                    Text(L.t("Ingresos", "Income")).frame(width: 110, alignment: .trailing)
                    Text(L.t("Gastos", "Expenses")).frame(width: 110, alignment: .trailing)
                    Text(L.t("Balance", "Balance")).frame(width: 110, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Divider() }

                ForEach(filas) { f in
                    HStack {
                        Text(f.mes).frame(maxWidth: .infinity, alignment: .leading)
                        Text(Money.fmt(f.ingresos)).frame(width: 110, alignment: .trailing)
                        Text(Money.fmt(f.gastos)).frame(width: 110, alignment: .trailing)
                        Text(Money.fmt(f.balance))
                            .fontWeight(.semibold)
                            .foregroundStyle(f.balance >= 0 ? Paleta.brand : Paleta.negativo)
                            .frame(width: 110, alignment: .trailing)
                    }
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) { Divider() }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - La hoja

    private var hoja: some View {
        HojaInforme(titulo: vm.esAnual
                    ? L.t("Reporte anual de tesorería", "Annual treasury report")
                    : L.t("Estado financiero mensual", "Monthly treasury statement"),
                    periodo: vm.esAnual ? vm.anioSel : vm.periodoEtiqueta) {
            if vm.esAnual, let a = vm.anual {
                TresCifras(valores: [
                    (L.t("Ingresos", "Income"), Money.fmt(a.totalIngresos)),
                    (L.t("Gastos", "Expenses"), Money.fmt(a.totalGastos)),
                    (L.t("Balance", "Balance"), Money.fmt(a.balance)),
                ])
                BloqueInforme(L.t("Ingresos por categoría", "Income by category")) {
                    ForEach(a.ingresosPorCategoria) { c in
                        RenglonInforme(c.nombre, Money.fmt(c.monto),
                                       total: Int(a.totalIngresos), parte: Int(c.monto))
                    }
                }
            } else if let e = vm.estado {
                TresCifras(valores: [
                    (L.t("Saldo anterior", "Opening balance"), Money.fmt(e.saldoAnterior)),
                    (L.t("Ingresos", "Income"), Money.fmt(e.ingresosMes)),
                    (L.t("Gastos", "Expenses"), Money.fmt(e.gastosMes)),
                ])
                BloqueInforme(L.t("Ingresos por categoría", "Income by category")) {
                    ForEach(e.composicion) { c in
                        RenglonInforme(c.nombre, Money.fmt(c.monto),
                                       total: Int(e.ingresosMes), parte: Int(c.monto))
                    }
                }
                BloqueInforme(L.t("Saldo al cierre", "Ending balance")) {
                    RenglonInforme(L.t("Saldo anterior más lo del mes",
                                       "Opening balance plus this month"),
                                   Money.fmt(e.saldoFinal))
                }
            }
        }
    }

    // MARK: - Piezas

    private func dona(_ cats: [CategoriaMonto]) -> some View {
        Group {
            if cats.isEmpty {
                Text(L.t("Sin ingresos en el periodo", "No income this period"))
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
                    .padding(.vertical, 26)
            } else {
                let total = cats.reduce(0) { $0 + $1.monto }
                Chart(cats) { c in
                    SectorMark(angle: .value("Importe", Double(c.monto) / 100),
                               innerRadius: .ratio(0.62), angularInset: 1.5)
                        .foregroundStyle(Paleta.categoria(Catalogos.clave(deEtiqueta: c.nombre),
                                                          nombre: c.nombre))
                        .cornerRadius(3)
                }
                .chartBackground { _ in
                    Text(Money.compact(total))
                        .font(.system(size: 14, weight: .bold)).monospacedDigit()
                }
                .frame(height: 150)
                .padding(.top, 12)
            }
        }
    }

    private func barras(_ cats: [CategoriaMonto], total: Centavos, tinta: Color) -> some View {
        Group {
            if cats.isEmpty {
                Text(L.t("Sin gastos en el periodo", "No expenses this period"))
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
                    .padding(.vertical, 26)
            } else {
                VStack(spacing: 9) {
                    ForEach(cats) { c in
                        VStack(spacing: 4) {
                            HStack {
                                Text(c.nombre).font(.system(size: 12)).lineLimit(1)
                                Spacer(minLength: 6)
                                Text(Money.fmt(c.monto))
                                    .font(.system(size: 12)).monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.quaternary)
                                    Capsule().fill(tinta)
                                        .frame(width: g.size.width
                                               * CGFloat(c.monto) / CGFloat(max(1, total)))
                                }
                            }
                            .frame(height: 7)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private func panel<C: View>(_ titulo: String, @ViewBuilder c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo)
                .font(.system(size: 11, weight: .bold)).kerning(0.5)
                .foregroundStyle(.secondary)
            c()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tarjetaMac(14)
    }
}

/// Guarda la `NSView` que hay debajo del botón "Compartir" para que
/// `NSSharingServicePicker` sepa de dónde colgar su menú. Es una clase y no un
/// valor porque la vista la crea AppKit después de que SwiftUI arme el cuerpo:
/// el botón lee la referencia cuando se pulsa, no cuando se dibuja.
private final class AnclaCompartir {
    weak var vista: NSView?
}

/// Una `NSView` vacía del tamaño del botón. No pinta nada ni recibe clics
/// (`hitTest` devuelve nil), así que el botón sigue siendo el que se pulsa.
private struct VistaAncla: NSViewRepresentable {
    let ancla: AnclaCompartir

    func makeNSView(context: Context) -> NSView {
        let v = VistaTransparente()
        ancla.vista = v
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        ancla.vista = nsView
    }

    private final class VistaTransparente: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
