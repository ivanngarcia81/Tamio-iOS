import Foundation
import GRDB

// MARK: - Fila local

/// La categoría personalizada tal y como vive en SQLite.
struct CategoriaCustomFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "categoriaCustom"

    var id: String
    var tipo: String
    var nombre: String
    var color: String
    var actualizadoEn: String?
    var borrado: Bool

    init(_ c: CategoriaCustom, actualizadoEn: String? = nil, borrado: Bool = false) {
        id = c.id
        tipo = c.tipo == .ingreso ? "ingreso" : "gasto"
        nombre = c.nombre
        color = c.color
        self.actualizadoEn = actualizadoEn
        self.borrado = borrado
    }

    var categoria: CategoriaCustom {
        CategoriaCustom(id: id,
                        tipo: tipo == "ingreso" ? .ingreso : .gasto,
                        nombre: nombre,
                        color: color)
    }
}

// MARK: - Frontera

/// Frontera de datos de las categorías que crea la iglesia.
protocol CategoriasRepository {
    func lista() async throws -> [CategoriaCustom]
    func crear(_ c: CategoriaCustom) async throws
    func actualizar(_ c: CategoriaCustom) async throws
    func eliminar(id: String) async throws
}

/// Guarda en el teléfono y encola para subir, igual que todo lo demás: crear
/// una categoría sin señal y usarla en el acto es el caso normal, no la
/// excepción.
struct OfflineCategoriasRepository: CategoriasRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func lista() async throws -> [CategoriaCustom] {
        try await cola.read { db in
            try CategoriaCustomFila
                .filter(Column("borrado") == false)
                .order(Column("nombre"))
                .fetchAll(db)
                .map(\.categoria)
        }
    }

    func crear(_ c: CategoriaCustom) async throws {
        try await guardar(c, operacion: .crear)
    }

    func actualizar(_ c: CategoriaCustom) async throws {
        try await guardar(c, operacion: .actualizar)
    }

    /// Borrado **lógico**, como en el resto de la app: un DELETE no se puede
    /// propagar, y los movimientos ya capturados con esa categoría siguen
    /// diciendo su nombre. Lo que desaparece es la opción de elegirla otra vez.
    func eliminar(id: String) async throws {
        try await cola.write { db in
            try db.execute(sql: """
                update categoriaCustom set borrado = 1 where id = ?
                """, arguments: [id])
            try Self.encolar(db, id: id, operacion: .eliminar)
        }
    }

    private func guardar(_ c: CategoriaCustom,
                         operacion: OperacionPendiente.Operacion) async throws {
        let fila = CategoriaCustomFila(c)
        try await cola.write { db in
            try fila.save(db)
            try Self.encolar(db, id: c.id, operacion: operacion)
        }
    }

    /// Una sola operación pendiente por categoría: al servidor le importa cómo
    /// quedó, no por cuántos cambios de nombre pasó. Un `eliminar` sí releva a
    /// lo anterior, porque después de borrarla no hay nada que actualizar.
    private static func encolar(_ db: Database, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        try OperacionPendiente
            .filter(Column("entidad") == "categoriaCustom" && Column("registroId") == id)
            .deleteAll(db)
        var op = OperacionPendiente(id: nil, entidad: "categoriaCustom",
                                    registroId: id,
                                    operacion: operacion.rawValue,
                                    creadoEn: Date().timeIntervalSince1970,
                                    intentos: 0, ultimoError: nil)
        try op.insert(db)
    }
}

/// En modo revisión no hay base que sincronizar: se recuerda en memoria para
/// poder recorrer la pantalla, crear una y verla aparecer en los formularios.
struct MockCategoriasRepository: CategoriasRepository {
    /// Estática y compartida, como el resto de mocks: si no, crear una
    /// categoría en Ajustes no se vería al abrir "Nuevo gasto".
    private static var almacen: [CategoriaCustom] = [
        CategoriaCustom(id: "mock-cafeteria", tipo: .gasto,
                        nombre: L.t("Cafetería", "Coffee bar"), color: "A44A00"),
    ]

    func lista() async throws -> [CategoriaCustom] {
        Self.almacen.sorted { $0.nombre < $1.nombre }
    }

    func crear(_ c: CategoriaCustom) async throws { Self.almacen.append(c) }

    func actualizar(_ c: CategoriaCustom) async throws {
        guard let i = Self.almacen.firstIndex(where: { $0.id == c.id }) else { return }
        Self.almacen[i] = c
    }

    func eliminar(id: String) async throws {
        Self.almacen.removeAll { $0.id == id }
    }
}

func repositorioCategorias() -> CategoriasRepository {
    ModoRevision.sinLogin ? MockCategoriasRepository() : OfflineCategoriasRepository()
}
