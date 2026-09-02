import Foundation
import Observation

@Observable
final class ReportesViewModel {
    private let repo: ReportesRepository

    let tipos: [ReporteTipo]
    var seleccionId: String

    // Filtros (gobiernan la recarga del estado financiero).
    let periodos: [String]
    var periodoSel: String
    /// `nil` = todas las categorías.
    var categoriaSel: String?

    private(set) var estado: EstadoFinanciero?

    init(repo: ReportesRepository = MockReportesRepository()) {
        self.repo = repo
        self.tipos = repo.tipos()
        self.seleccionId = tipos.first?.id ?? "estado"
        self.periodos = repo.periodos()
        self.periodoSel = periodos.first ?? ""
    }

    var seleccion: ReporteTipo? { tipos.first { $0.id == seleccionId } }

    /// Categorías para el menú de filtro (con "Todas" al frente).
    var categorias: [String] { repo.categorias() }

    /// Etiqueta del chip de categoría (según haya filtro o no).
    var categoriaEtiqueta: String {
        categoriaSel ?? L.t("Todas las categorías", "All categories")
    }

    @MainActor
    func cargar() async {
        estado = await repo.estadoFinanciero(periodo: periodoSel, categoria: categoriaSel)
    }

    @MainActor
    func seleccionarPeriodo(_ p: String) async {
        periodoSel = p
        await cargar()
    }

    @MainActor
    func seleccionarCategoria(_ c: String?) async {
        categoriaSel = c
        await cargar()
    }

    /// Resumen en texto plano para "Compartir" (cuando no se quiere el PDF).
    var resumenTexto: String {
        guard let e = estado else { return "" }
        return L.t(
            "Estado financiero — \(e.periodo)\nIngresos: \(Money.fmt(e.ingresosMes)) MXN\nGastos: \(Money.fmt(e.gastosMes)) MXN\nBalance neto: \(Money.fmt(e.balanceNeto)) MXN\nIglesia Getsemaní, Monterrey, N.L.",
            "Financial statement — \(e.periodo)\nIncome: \(Money.fmt(e.ingresosMes)) MXN\nExpenses: \(Money.fmt(e.gastosMes)) MXN\nNet balance: \(Money.fmt(e.balanceNeto)) MXN\nIglesia Getsemaní, Monterrey, N.L.")
    }
}
