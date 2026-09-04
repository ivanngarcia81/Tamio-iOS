import Foundation

@Observable
final class AgendaViewModel {
    var eventos: [EventoAgenda] = []
    var diaSeleccionado: Int
    var vistaActual = 0
    var cargando = false
    var mesActual: Date

    private let repo: AgendaRepository
    private let cal = Calendar.current

    /// Abre en el mes real y en el día real. Arrancaba clavada en agosto de
    /// 2026 "para coincidir con el handoff", así que en septiembre el botón
    /// "Hoy" llevaba al pasado y el anillo de hoy no se dibujaba nunca: el
    /// círculo verde del 20 que se veía era el estado *seleccionado*.
    ///
    /// La semilla no hace falta tocarla: sus eventos van por día del mes, no
    /// por fecha, así que valen para el mes que sea.
    init(repo: AgendaRepository = MockAgendaRepository()) {
        self.repo = repo
        self.mesActual = Date()
        self.diaSeleccionado = Calendar.current.component(.day, from: Date())
    }

    // MARK: - Calendar geometry

    var diasEnMes: Int {
        cal.range(of: .day, in: .month, for: mesActual)?.count ?? 30
    }

    /// Offset del primer día del mes (0 = Dom … 6 = Sáb).
    var primerDiaOffset: Int {
        let comps = cal.dateComponents([.year, .month], from: mesActual)
        guard let primero = cal.date(from: comps) else { return 0 }
        return cal.component(.weekday, from: primero) - 1
    }

    /// Una celda de la cuadrícula del mes: un día, o un hueco antes del día 1.
    /// Los huecos llevan id negativo para que **no se crucen con los días**.
    struct CeldaMes: Identifiable {
        let id: Int
        let dia: Int?
    }

    /// La cuadrícula entera, en un solo recorrido. Antes eran dos `ForEach`
    /// hermanos dentro del mismo `LazyVGrid`, los dos con `id: \.self` sobre
    /// enteros: los huecos usaban 0…5 y los días 1…31, así que los ids 1 a 5
    /// estaban repetidos y la cuadrícula se quedaba con una sola celda por id.
    /// Los cinco primeros días del mes no se dibujaban: en agosto de 2026, que
    /// empieza en sábado, el mes arrancaba visualmente en el 6.
    var celdasDelMes: [CeldaMes] {
        (0..<primerDiaOffset).map { CeldaMes(id: -($0 + 1), dia: nil) }
        + (1...max(1, diasEnMes)).map { CeldaMes(id: $0, dia: $0) }
    }

    var etiquetaMes: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        fmt.locale = L.locale
        return fmt.string(from: mesActual).capitalized
    }

    /// Día del mes "hoy" si el mes que se está viendo es el mes real. `nil` si
    /// no, que es cuando no hay ningún día que anillar.
    var diaHoy: Int? {
        guard cal.isDate(mesActual, equalTo: Date(), toGranularity: .month) else { return nil }
        return cal.component(.day, from: Date())
    }

    // MARK: - Navigation

    func irAlMesSiguiente() {
        mesActual = cal.date(byAdding: .month, value: 1, to: mesActual) ?? mesActual
        diaSeleccionado = 1
    }

    func irAlMesAnterior() {
        mesActual = cal.date(byAdding: .month, value: -1, to: mesActual) ?? mesActual
        diaSeleccionado = 1
    }

    func irAHoy() {
        mesActual = Date()
        diaSeleccionado = cal.component(.day, from: Date())
    }

    // MARK: - Events

    var eventosDia: [EventoAgenda] {
        eventos.filter { $0.dia == diaSeleccionado }
    }

    func eventos(dia: Int) -> [EventoAgenda] {
        eventos.filter { $0.dia == dia }
    }

    /// Todos los eventos agrupados por día, en orden.
    var eventosOrdenados: [(dia: Int, lista: [EventoAgenda])] {
        let grupos = Dictionary(grouping: eventos, by: { $0.dia })
        return grupos.keys.sorted().map { d in (dia: d, lista: grupos[d]!) }
    }

    var pendientesMes: Int { eventos.filter { !$0.completado }.count }

    var proximoId: String { UUID().uuidString }

    func añadir(_ ev: EventoAgenda) {
        eventos.append(ev)
        diaSeleccionado = ev.dia
    }

    func cargar() async {
        cargando = true
        eventos = (try? await repo.eventos()) ?? []
        cargando = false
    }
}
