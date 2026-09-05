import Foundation
import GRDB

/// Aportantes desde la base del teléfono, con sus aportes **calculados a partir
/// de los movimientos reales**.
///
/// Esto es lo que cierra el círculo: hasta ahora la ficha de una persona
/// enseñaba un historial de ejemplo, así que un diezmo registrado en Ingresos
/// no aparecía en su ficha, y el total, la gráfica, la constancia de aporte y
/// la constancia anual salían de datos inventados.
struct OfflineMiembrosRepository: MiembrosRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func lista(filtro: FiltroMiembro) async throws -> [Aportante] {
        try await cola.read { db in
            let filas = try AportanteFila
                .filter(Column("borrado") == false)
                .order(Column("nombre"))
                .fetchAll(db)

            // Los ingresos vinculados a una ficha son los aportes. Se leen de
            // una vez y se agrupan, en vez de consultar por cada persona.
            let movimientos = try MovimientoFila
                .filter(Column("tipo") == "ingreso"
                        && Column("borrado") == false
                        && Column("memberUid") != nil)
                .fetchAll(db)

            var porMiembro: [String: [Aporte]] = [:]
            for m in movimientos {
                guard let uid = m.memberUid else { continue }
                porMiembro[uid, default: []].append(
                    Aporte(id: m.id,
                           // La categoría completa lleva la subcategoría si la
                           // hay: "Ofrenda · Misiones" dice más que "Ofrenda".
                           concepto: m.categoriaCompleta.isEmpty ? m.categoria : m.categoriaCompleta,
                           fecha: Date(timeIntervalSince1970: m.fecha),
                           monto: m.monto))
            }

            let todos = filas.map { $0.aportante(aportes: porMiembro[$0.id] ?? []) }
            switch filtro {
            case .activos: return todos.filter { !$0.estado.esBaja }
            case .bajas:   return todos.filter { $0.estado.esBaja }
            case .todos:   return todos
            }
        }
    }

    func crear(_ a: Aportante) async throws {
        var borrador = a
        if borrador.id.isEmpty { borrador.id = UUID().uuidString }
        // Copia inmutable antes del closure: capturar la `var` es un error en
        // Swift 6, no solo un aviso.
        let nuevo = borrador
        try await cola.write { db in
            try AportanteFila(nuevo).insert(db)
            try Self.encolar(db, id: nuevo.id, operacion: .crear)
        }
    }

    func actualizar(_ a: Aportante) async throws {
        try await cola.write { db in
            let previa = try AportanteFila.fetchOne(db, key: a.id)
            try AportanteFila(a, actualizadoEn: previa?.actualizadoEn).update(db)
            try Self.encolar(db, id: a.id, operacion: .actualizar)
        }
    }

    func eliminar(id: String) async throws {
        try await cola.write { db in
            guard var fila = try AportanteFila.fetchOne(db, key: id) else { return }
            fila.borrado = true
            try fila.update(db)
            try Self.encolar(db, id: id, operacion: .eliminar)
        }
    }

    private static func encolar(_ db: Database, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        let previa = try OperacionPendiente
            .filter(Column("entidad") == "aportante" && Column("registroId") == id)
            .fetchOne(db)
        let efectiva: OperacionPendiente.Operacion =
            (previa?.operacion == OperacionPendiente.Operacion.crear.rawValue
             && operacion == .actualizar) ? .crear : operacion

        try OperacionPendiente
            .filter(Column("entidad") == "aportante" && Column("registroId") == id)
            .deleteAll(db)
        var nueva = OperacionPendiente(id: nil, entidad: "aportante", registroId: id,
                                       operacion: efectiva.rawValue,
                                       creadoEn: Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}

func repositorioMiembros() -> MiembrosRepository {
    ModoRevision.sinLogin ? MockMiembrosRepository() : OfflineMiembrosRepository()
}
