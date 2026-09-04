import Foundation
import Observation

/// Aviso emergente tras resolver un asunto, con opción de deshacer.
struct ToastRevisar: Equatable {
    let id: Int
    let mensaje: String
}

@Observable
final class RevisarViewModel {
    private let repo: RevisarRepository

    private(set) var todos: [Revision] = []
    /// nil = "Todos".
    var filtro: RevisionTipo?
    var seleccionId: String?
    var toast: ToastRevisar?

    private var ultimoResuelto: Revision?
    private var toastSeq = 0

    init(repo: RevisarRepository = MockRevisarRepository()) {
        self.repo = repo
    }

    @MainActor
    func cargar() async {
        todos = await repo.asuntos()
        if seleccionId == nil || !todos.contains(where: { $0.id == seleccionId }) {
            seleccionId = visibles.first?.id
        }
    }

    var seleccion: Revision? { todos.first { $0.id == seleccionId } }

    var visibles: [Revision] {
        guard let filtro else { return todos }
        return todos.filter { $0.tipo == filtro }
    }

    // Conteos
    var totalCount: Int { todos.count }
    var archivadosCount: Int { todos.filter { $0.archivado }.count }
    var porRevisarCount: Int { todos.filter { !$0.archivado }.count }
    func count(_ t: RevisionTipo) -> Int { todos.filter { $0.tipo == t }.count }
    var tiposPresentes: [RevisionTipo] { RevisionTipo.allCases.filter { count($0) > 0 } }

    // Tarjetas del estado vacío
    var esperanVistoBueno: Int { count(.vistoBueno) }
    var soloEnterarse: Int { archivadosCount }
    var pidenArreglo: Int { totalCount - esperanVistoBueno - soloEnterarse }

    // MARK: - Acciones

    @MainActor
    func resolver(_ r: Revision, kind: AccionKind) async {
        ultimoResuelto = r
        let sig = siguienteA(r.id)
        await repo.resolver(id: r.id)
        await cargar()
        if seleccionId == r.id || seleccion == nil { seleccionId = sig ?? visibles.first?.id }
        mostrarToast(mensaje(r, kind))
    }

    /// Lo que "Aprobar todo" puede aprobar. Solo el visto bueno: un duplicado
    /// probable, un gasto sin comprobante o una categoría vacía piden una
    /// decisión sobre ESE movimiento, y aprobarlos en bloque es exactamente lo
    /// que su bandera existe para evitar. Se resuelven uno a uno.
    static let aprobablesEnBloque: Set<RevisionTipo> = [.vistoBueno]

    var aprobablesCount: Int {
        todos.filter { !$0.archivado && Self.aprobablesEnBloque.contains($0.tipo) }.count
    }

    @MainActor
    func aprobarTodo() async {
        let cuantos = aprobablesCount
        await repo.resolverTodos(tipos: Self.aprobablesEnBloque)
        await cargar()
        seleccionId = visibles.first?.id
        mostrarToast(L.t("Se aprobaron \(cuantos) asuntos que esperaban visto bueno.",
                         "\(cuantos) items awaiting approval were approved."))
    }

    @MainActor
    func pedirDato(_ r: Revision) async {
        mostrarToast(L.t("Se pidió más información sobre «\(r.concepto)».",
                         "More info requested about «\(r.concepto)»."))
    }

    @MainActor
    func deshacer() async {
        guard let r = ultimoResuelto else { return }
        await repo.restaurar(r)
        ultimoResuelto = nil
        toast = nil
        await cargar()
        seleccionId = r.id
    }

    /// Guarda los cambios del formulario "Editar"; el asunto sigue en la bandeja.
    @MainActor
    func editar(id: String, concepto: String, importe: String, categoria: String,
                metodo: String, aportante: String?, fecha: Date) async {
        guard var r = todos.first(where: { $0.id == id }) else { return }
        let signo = r.esGasto ? "−" : "+"
        var campos = r.campos.map { c -> CampoRevision in
            switch c.label {
            case L.t("Concepto", "Concept"): return .init(label: c.label, valor: concepto)
            case L.t("Importe", "Amount"): return .init(label: c.label, valor: "\(signo)\(Money.moneda.simbolo)\(importe) \(Money.codigo)", resalte: r.esGasto ? .rojo : .verde)
            case L.t("Categoría", "Category"): return .init(label: c.label, valor: categoria)
            case L.t("Método de pago", "Payment method"): return .init(label: c.label, valor: metodo)
            case L.t("Fecha", "Date"): return .init(label: c.label, valor: Fechas.corta(fecha))
            case L.t("Aportante", "Giver"): return .init(label: c.label, valor: aportante ?? c.valor, resalte: aportante == nil ? .rojo : .ninguno)
            default: return c
            }
        }
        // Si tenía "Sin categoría" en rojo y ahora hay categoría, ya no va en rojo.
        campos = campos.map { $0.label == L.t("Categoría", "Category") ? .init(label: $0.label, valor: $0.valor) : $0 }
        r = Revision(id: r.id, tipo: r.tipo, concepto: concepto, detalleLista: r.detalleLista,
                     archivado: r.archivado, descripcion: r.descripcion, seccionTitulo: r.seccionTitulo,
                     campos: campos, seccionSecundaria: r.seccionSecundaria, camposSecundarios: r.camposSecundarios,
                     notaPie: r.notaPie, acciones: r.acciones, esGasto: r.esGasto,
                     editImporte: importe, editCategoria: categoria, editMetodo: metodo,
                     editAportante: aportante, toastResuelto: r.toastResuelto)
        await repo.actualizar(r)
        await cargar()
    }

    // MARK: - Helpers

    private func mensaje(_ r: Revision, _ kind: AccionKind) -> String {
        switch kind {
        case .aprobar:
            return L.t("«\(r.concepto)» quedó aprobado: ya cuenta en los totales del mes.",
                       "«\(r.concepto)» was approved: it now counts in monthly totals.")
        case .devolver:
            return L.t("«\(r.concepto)» se devolvió al tesorero.", "«\(r.concepto)» was returned to the treasurer.")
        case .resolver where r.tipo == .archivado:
            return L.t("«\(r.concepto)» se restauró.", "«\(r.concepto)» was restored.")
        default:
            return L.t("«\(r.concepto)» quedó revisado.", "«\(r.concepto)» was reviewed.")
        }
    }

    @MainActor
    private func mostrarToast(_ mensaje: String) {
        toastSeq += 1
        toast = ToastRevisar(id: toastSeq, mensaje: mensaje)
    }

    private func siguienteA(_ id: String) -> String? {
        let v = visibles
        guard let i = v.firstIndex(where: { $0.id == id }) else { return nil }
        if i + 1 < v.count { return v[i + 1].id }
        if i - 1 >= 0 { return v[i - 1].id }
        return nil
    }
}
