import Foundation
import Observation

@Observable
final class ReportesViewModel {
    private let repo: ReportesRepository

    let tipos: [ReporteTipo]
    var seleccionId: String

    /// **Los periodos salen de los datos**, así que ya no se pueden saber al
    /// construir el ViewModel: se cargan con el resto. Antes eran los seis
    /// meses de la semilla, escritos en el repositorio.
    private(set) var periodos: [PeriodoContable] = []
    private(set) var categorias: [String] = []
    /// Clave del periodo elegido (`"2026-08"`), no su etiqueta.
    private(set) var periodoSel = ""
    /// `nil` = todas las categorías.
    private(set) var categoriaSel: String?

    private(set) var estado: EstadoFinanciero?
    private(set) var cargando = true

    init(repo: ReportesRepository = repositorioReportes()) {
        self.repo = repo
        self.tipos = repo.tipos()
        self.seleccionId = tipos.first?.id ?? "estado"
    }

    var seleccion: ReporteTipo? { tipos.first { $0.id == seleccionId } }

    /// Etiqueta del chip de periodo. Vacía mientras no hay datos.
    var periodoEtiqueta: String {
        estado?.periodo.etiqueta ?? Fechas.periodoLegible(periodoSel)
    }

    var categoriaEtiqueta: String {
        categoriaSel ?? L.t("Todas las categorías", "All categories")
    }

    /// No hay ni un movimiento aprobado: no es que el reporte esté vacío, es
    /// que todavía no hay nada que reportar.
    var sinDatos: Bool { !cargando && estado == nil }

    @MainActor
    func cargar() async {
        periodos = await repo.periodos()
        if periodoSel.isEmpty || !periodos.contains(where: { $0.clave == periodoSel }) {
            periodoSel = periodos.first?.clave ?? ""
        }
        categorias = await repo.categorias()
        // La categoría elegida puede no existir en el mes nuevo.
        if let c = categoriaSel, !categorias.contains(c) { categoriaSel = nil }
        estado = await repo.estadoFinanciero(periodo: periodoSel, categoria: categoriaSel)
        // El repositorio cae al mes más reciente si el pedido se quedó sin
        // datos; el chip tiene que decir el mes que se está viendo de verdad.
        if let clave = estado?.periodo.clave { periodoSel = clave }
        cargando = false
    }

    @MainActor
    func seleccionarPeriodo(_ clave: String) async {
        periodoSel = clave
        await cargar()
    }

    @MainActor
    func seleccionarCategoria(_ c: String?) async {
        categoriaSel = c
        await cargar()
    }

    /// Resumen en texto plano para "Compartir" (cuando no se quiere el PDF).
    /// Lleva el saldo final porque es la cifra por la que pregunta quien lo
    /// recibe: el balance del mes solo dice cómo fue el mes.
    var resumenTexto: String {
        guard let e = estado else { return "" }
        func linea(_ es: String, _ en: String, _ c: Centavos) -> String {
            "\(L.t(es, en)): \(Money.fmt(c)) \(Money.codigo)"
        }
        return [
            L.t("Estado financiero — \(e.periodo.etiqueta)",
                "Financial statement — \(e.periodo.etiqueta)"),
            linea("Saldo anterior", "Previous balance", e.saldoAnterior),
            linea("Ingresos", "Income", e.ingresosMes),
            linea("Gastos", "Expenses", e.gastosMes),
            linea("Saldo final", "Ending balance", e.saldoFinal),
        ].joined(separator: "\n")
    }
}
