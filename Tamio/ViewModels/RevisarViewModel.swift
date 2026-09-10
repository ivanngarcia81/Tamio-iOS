import Foundation
import Observation

/// Aviso emergente tras resolver un asunto, con opción de deshacer.
struct ToastRevisar: Equatable {
    let id: Int
    let mensaje: String
}

@Observable
final class RevisarViewModel {
    /// **Una sola instancia para el conteo.** El badge del tab de iPhone, el de
    /// la sidebar del iPad y el KPI del Inicio responden a la misma pregunta;
    /// con un ViewModel por sitio, cada uno cargaba por su cuenta y llegaron a
    /// enseñar 8, 25 y 2 a la vez.
    static let compartido = RevisarViewModel()

    private let repo: RevisarRepository

    private(set) var todos: [Revision] = []
    /// nil = "Todos".
    var filtro: RevisionTipo?
    var seleccionId: String?
    var toast: ToastRevisar?

    private var ultimoResuelto: Revision?
    private var toastSeq = 0

    init(repo: RevisarRepository = repositorioRevisar()) {
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
        switch kind {
        case .aprobar: await repo.aprobar(id: r.id)
        case .devolver: await repo.devolver(id: r.id)
        case .restaurar: await repo.reactivarMiembro(id: r.id)
        case .editar, .irAlCorte: return   // los resuelve otra pantalla
        }
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
        await repo.aprobarPendientes()
        await cargar()
        seleccionId = visibles.first?.id
        mostrarToast(L.t("Se aprobaron \(cuantos) asuntos que esperaban visto bueno.",
                         "\(cuantos) items awaiting approval were approved."))
    }

    @MainActor
    func deshacer() async {
        guard let r = ultimoResuelto else { return }
        await repo.revertir(r)
        ultimoResuelto = nil
        toast = nil
        await cargar()
        seleccionId = r.id
    }

    /// Guarda los cambios del formulario "Editar"; el asunto sigue en la bandeja.
    ///
    /// **Solo se rellenan los campos `edit*`, que son los que el repositorio
    /// escribe.** Antes esto recomponía además los `campos` del detalle y el
    /// `concepto` de la fila, uno por uno y a mano, para que la pantalla se
    /// viera al día antes de recargar. Era trabajo perdido y además mentía: la
    /// bandeja **se calcula del movimiento** (`CalculadoraRevisiones`), así que
    /// el `cargar()` de la línea siguiente rehace esos mismos campos con lo que
    /// de verdad quedó guardado. Mientras el repositorio no escribía nada, esa
    /// recomposición era justo lo que hacía parecer que la edición había
    /// entrado durante un instante.
    @MainActor
    func editar(id: String, concepto: String, importe: String, categoria: String,
                metodo: String, aportante: String?, fecha: Date) async {
        guard var r = todos.first(where: { $0.id == id }) else { return }
        r.editImporte = importe
        r.editCategoria = categoria
        r.editMetodo = metodo
        r.editAportante = aportante
        r.editNota = concepto
        r.editFecha = fecha
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
            // Dice lo que de verdad pasa: no es "revisado", es que sale de los
            // totales del mes hasta que alguien lo arregle.
            return L.t("«\(r.concepto)» se devolvió al tesorero y deja de contar en el mes.",
                       "«\(r.concepto)» was returned to the treasurer and no longer counts this month.")
        case .restaurar:
            return L.t("«\(r.concepto)» volvió al padrón.", "«\(r.concepto)» is back in the directory.")
        case .editar, .irAlCorte:
            return ""
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
