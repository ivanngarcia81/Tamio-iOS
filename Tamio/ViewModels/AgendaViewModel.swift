import Foundation

@Observable
final class AgendaViewModel {
    var eventos: [EventoAgenda] = []
    var diaSeleccionado: Int = 20
    var vistaActual = 0
    var cargando = false
    var mesActual: Date

    private let repo: AgendaRepository
    private let cal = Calendar.current

    init(repo: AgendaRepository = MockAgendaRepository()) {
        self.repo = repo
        // Inicia en agosto 2026 para que el mock coincida con el handoff
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 1
        self.mesActual = Calendar.current.date(from: comps) ?? Date()
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

    var etiquetaMes: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        fmt.locale = Locale.current
        return fmt.string(from: mesActual).capitalized
    }

    /// Día del mes "hoy" si el mes actual coincide con el mes real. `nil` si no.
    var diaHoy: Int? {
        guard cal.isDate(mesActual, equalTo: Date(), toGranularity: .month) else { return nil }
        return 20  // mock: "today" coincide con diaSeleccionado del handoff
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
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 1
        mesActual = cal.date(from: comps) ?? mesActual
        diaSeleccionado = 20  // "hoy" en el mock del handoff
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

    var proximoId: Int { (eventos.map(\.id).max() ?? 0) + 1 }

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
