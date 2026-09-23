import Foundation
import Observation

@Observable
final class MiembrosViewModel {
    private let repo: MiembrosRepository

    var filtro: FiltroMiembro = .activos {
        didSet { if filtro != oldValue { Task { await cargar() } } }
    }
    private(set) var items: [Aportante] = []
    var seleccionId: String?
    var busqueda = ""
    /// Deja en la lista solo a quien lleva tres periodos o más sin aportar.
    var soloAtrasados = false

    init(repo: MiembrosRepository = repositorioMiembros()) {
        self.repo = repo
    }

    @MainActor
    func cargar() async {
        items = (try? await repo.lista(filtro: filtro)) ?? []
        if seleccionId == nil || !items.contains(where: { $0.id == seleccionId }) {
            seleccionId = itemsFiltrados.first?.id
        }
    }

    // MARK: - CRUD (vía repositorio → el motor solo cambia la impl)

    @MainActor func crear(_ a: Aportante) async {
        try? await repo.crear(a)
        await cargar()
    }
    /// Aplica una importación ya confirmada. Los que traen id van a
    /// actualizar; los que no, a crear.
    /// `progreso` recibe cuántas van, para la barra de «Importando…» del Mac.
    @MainActor func importar(_ lista: [Aportante], progreso: ((Int) -> Void)? = nil) async {
        for (i, a) in lista.enumerated() {
            if a.id.isEmpty { try? await repo.crear(a) } else { try? await repo.actualizar(a) }
            progreso?(i + 1)
        }
        await cargar()
    }

    /// **Los aportes importados son ingresos, y entran ya cerrados.**
    ///
    /// Antes esto metía los aportes dentro de la ficha y la guardaba. Pero la
    /// base no guarda aportes en la ficha: los calcula de los ingresos con su
    /// `memberUid` (`AportanteFila`). Así que **en la app real no se guardaba
    /// nada** y no lo decía: solo funcionaba en la maqueta. Visto el 23-sep.
    ///
    /// Ahora cada aporte es un ingreso aprobado, vinculado a su persona y con
    /// constancia anual, y todos van a **un corte ya depositado** que los
    /// reclama. Decidido por Iván el 23-sep: un aporte de 2023 no puede sumar
    /// hoy al efectivo en caja ni pedir depósito, y «depositado» no es una
    /// casilla del ingreso sino que un corte depositado lo reclame. El corte
    /// usa las tablas de siempre, así que el web lo entiende sin cambios.
    ///
    /// Cada ingreso toma su folio del contador del servidor, como cualquier
    /// otro: la serie de recibos avanza tantos como aportes se importan.
    @MainActor func importarAportes(_ porAportante: [String: [Aporte]], archivo: String = "",
                                    autor: String = "", progreso: ((Int) -> Void)? = nil) async {
        let movimientos = repositorioMovimientos()
        let depositos = repositorioDepositos()
        var creados: [String] = []
        for (uid, aportes) in porAportante {
            let nombre = items.first { $0.id == uid }?.nombre
            for ap in aportes {
                // La clave del catálogo si el concepto es uno suyo («Diezmo»,
                // «Tithe»), y el texto tal cual si es de la iglesia.
                let categoria = Catalogos.clave(deEtiqueta: ap.concepto)?.rawValue ?? ap.concepto
                let m = Movimiento(
                    id: UUID().uuidString, tipo: .ingreso, categoria: categoria,
                    persona: nombre, folio: "", metodo: "", monto: ap.monto, hora: "",
                    fecha: ap.fecha, registradoPor: autor, miembro: nombre,
                    categoriaCompleta: categoria,
                    nota: archivo.isEmpty ? nil : L.t("Importado de \(archivo)", "Imported from \(archivo)"),
                    sinDepositar: false, comprobante: nil, auditoria: [],
                    estadoRevision: .aprobado, incluidoEnCorte: true,
                    darConstanciaAnual: true, memberUid: uid)
                do {
                    try await movimientos.crear(m)
                    creados.append(m.id)
                } catch {}
                progreso?(creados.count)
            }
        }
        if !creados.isEmpty {
            let hoy = Date()
            let corte = Corte(
                id: UUID().uuidString,
                titulo: archivo.isEmpty ? L.t("Aportes importados", "Imported gifts")
                                        : L.t("Aportes importados · \(archivo)", "Imported gifts · \(archivo)"),
                descripcion: L.t("Aportes de años anteriores, importados el \(Fechas.diaLegible(Fechas.claveDia(hoy))). No pasaron por la caja de hoy: este corte los da por depositados.",
                                 "Gifts from past years, imported on \(Fechas.diaLegible(Fechas.claveDia(hoy))). They never went through today’s cash box: this cut counts them as deposited."),
                estado: .depositado,
                movimientos: [],
                registro: RegistroDeposito(cuenta: Corte.sinAsignar,
                                           fecha: Fechas.claveDia(hoy),
                                           periodo: Fechas.clavePeriodo(hoy)))
            try? await depositos.crear(corte)
            try? await depositos.agregarAlCorte(corteId: corte.id, movimientoIds: creados)
        }
        await cargar()
    }

    @MainActor func actualizar(_ a: Aportante) async {
        try? await repo.actualizar(a)
        await cargar()
        seleccionId = a.id
    }
    // Sin `eliminar`: sacar a alguien del padrón es de Secretaría, que lo hace
    // dándole de baja (conservando su historial) en vez de borrando la ficha.
    // El repositorio mantiene la operación para quien sí deba usarla.

    var seleccion: Aportante? { items.first { $0.id == seleccionId } }

    var itemsFiltrados: [Aportante] {
        let base = busqueda.isEmpty ? items
            : items.filter { $0.nombre.localizedCaseInsensitiveContains(busqueda)
                || $0.correo.localizedCaseInsensitiveContains(busqueda)
                || $0.idFiscal.localizedCaseInsensitiveContains(busqueda) }
        let porConstancia = soloAtrasados ? base.filter(\.atrasadoEnAportes) : base
        return porConstancia.sorted { $0.nombre < $1.nombre }
    }

    /// Cuántos aportantes llevan tres periodos o más sin aportar. Es el número
    /// que justifica el chip de la lista: si es cero, no se enseña.
    var atrasadosCount: Int { items.filter(\.atrasadoEnAportes).count }

    /// El año que enseñan la lista y su pie. El mismo que encabeza la ficha:
    /// si la lista sumara de siempre y la ficha el año, serían dos cifras
    /// distintas para la misma persona a un toque de distancia.
    var anio: Int { Calendar.current.component(.year, from: Date()) }

    /// Suma de aportes del año de la lista visible (pie de la columna).
    var total: Centavos { itemsFiltrados.reduce(0) { $0 + $1.total(anio: anio) } }

    var activosCount: Int { items.filter { !$0.estado.esBaja }.count }
    var bajasCount: Int { items.filter { $0.estado.esBaja }.count }
}
