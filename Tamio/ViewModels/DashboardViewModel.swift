import Foundation
import Observation

/// Estado del Dashboard. `@Observable` (iOS 17) sustituye a `ObservableObject`
/// + `@Published`: la vista se redibuja sola cuando cambian las propiedades que
/// lee, sin Combine — que es justo lo que el estilo de la casa pide evitar.
@Observable
final class DashboardViewModel {
    private let repo: DashboardRepository

    var periodo: Periodo = .mes {
        didSet { Task { await cargar() } }
    }
    private(set) var data: DashboardData?
    private(set) var cargando = false

    init(repo: DashboardRepository = MockDashboardRepository()) {
        self.repo = repo
    }

    @MainActor
    func cargar() async {
        cargando = true
        defer { cargando = false }
        do {
            data = try await repo.cargar(periodo: periodo)
        } catch {
            // En el slice basta con no romper; el manejo de errores real
            // (banner, reintento) llega con la capa de datos de verdad.
            data = nil
        }
    }

    /// El periodo escrito para subtítulos: "agosto 2026" · "2.° trimestre 2026" · "2026".
    var periodoLegible: String {
        switch periodo {
        case .mes:
            let f = DateFormatter()
            f.locale = L.locale
            f.dateFormat = "LLLL yyyy"
            return f.string(from: Date()).capitalized
        case .trimestre:
            let mes = Calendar.current.component(.month, from: Date())
            let q = (mes - 1) / 3 + 1
            let sufijos = ["1.er", "2.°", "3.er", "4.°"]
            let sufijo = sufijos[max(0, min(q - 1, 3))]
            return L.t("\(sufijo) trimestre", "Q\(q)")
        case .anio:
            return String(Calendar.current.component(.year, from: Date()))
        }
    }

    /// Etiqueta del periodo anterior para los subtítulos DeltaBadge ("vs agosto", "vs Q2"...).
    var periodoAnteriorLegible: String {
        let cal = Calendar.current
        switch periodo {
        case .mes:
            let anterior = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            let f = DateFormatter()
            f.locale = L.locale
            f.dateFormat = "LLLL"
            return L.t("vs \(f.string(from: anterior))", "vs \(f.string(from: anterior))")
        case .trimestre:
            let mes = cal.component(.month, from: Date())
            let q = (mes - 1) / 3 + 1
            let prev = q == 1 ? 4 : q - 1
            return L.t("vs T\(prev)", "vs Q\(prev)")
        case .anio:
            let year = cal.component(.year, from: Date()) - 1
            return L.t("vs \(year)", "vs \(year)")
        }
    }
}
