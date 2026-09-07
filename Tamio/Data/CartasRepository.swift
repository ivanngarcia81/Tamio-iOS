import Foundation
import GRDB

protocol CartasRepository {
    func emitidas() async throws -> [CartaEmitida]
    /// Alta o edición: lo que llega es la carta entera. No existía, y por eso
    /// emitir una carta solo la metía en un array del view model.
    func guardar(_ c: CartaEmitida) async throws
    func eliminar(id: String) async throws
}

struct MockCartasRepository: CartasRepository {
    func emitidas() async throws -> [CartaEmitida] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        // Lo emitido en esta sesión primero.
        return Self.añadidas.reversed() + Self.semilla
    }

    func guardar(_ c: CartaEmitida) async throws {
        Self.añadidas.removeAll { $0.id == c.id }
        Self.añadidas.append(c)
    }

    func eliminar(id: String) async throws {
        Self.añadidas.removeAll { $0.id == id }
    }

    nonisolated(unsafe) private static var añadidas: [CartaEmitida] = []

    /// El año es el corriente para que la maqueta no envejezca, como pasó con
    /// los compromisos del hub.
    private static var semilla: [CartaEmitida] {
        let año = Calendar.current.component(.year, from: Date())
        return [
            CartaEmitida(id: "1", folio: "\(año)-001", tipo: .traslado,
                         fechaEmision: "\(año)-08-20",
                         lugarEmision: "Monterrey, Nuevo León",
                         destinatarioTipo: "iglesia",
                         destinatarioNombre: "Javier Medina Cruz",
                         asunto: L.t("Carta de traslado", "Transfer letter"),
                         estado: "emitida"),
            CartaEmitida(id: "2", folio: "\(año)-002", tipo: .certificadoMiembro,
                         fechaEmision: "\(año)-08-28",
                         lugarEmision: "Monterrey, Nuevo León",
                         destinatarioTipo: "miembro",
                         destinatarioNombre: "Ana Lucía Torres",
                         asunto: L.t("Constancia de membresía", "Membership certificate"),
                         estado: "emitida"),
        ]
    }
}

/// Las cartas de verdad: tabla `carta` de la base local, y de ahí a
/// `public.cartas` por el motor de sincronización.
struct OfflineCartasRepository: CartasRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func emitidas() async throws -> [CartaEmitida] {
        try await cola.read { db in
            try CartaFila
                .filter(Column("borrado") == false)
                .order(Column("fechaEmision").desc)
                .fetchAll(db)
                .map(Self.aCarta)
        }
    }

    func guardar(_ c: CartaEmitida) async throws {
        try await cola.write { db in
            let previa = try CartaFila.fetchOne(db, key: c.id)
            try Self.aFila(c, previa: previa).save(db)
            try Self.encolar(db, id: c.id, operacion: previa == nil ? .crear : .actualizar)
        }
    }

    func eliminar(id: String) async throws {
        try await cola.write { db in
            guard var fila = try CartaFila.fetchOne(db, key: id) else { return }
            fila.borrado = true
            try fila.update(db)
            try Self.encolar(db, id: id, operacion: .eliminar)
        }
    }

    // MARK: - Traducción

    static func aCarta(_ f: CartaFila) -> CartaEmitida {
        CartaEmitida(id: f.id,
                     folio: f.folio,
                     // Por la CLAVE del web, no por el nombre del `case`:
                     // `constanciaActivo`, `constanciaServicio` y
                     // `certificacion` no coinciden. Ver `TipoPlantilla.clave`.
                     tipo: TipoPlantilla(clave: f.tipo),
                     fechaEmision: f.fechaEmision,
                     lugarEmision: f.lugarEmision,
                     destinatarioTipo: f.destinatarioTipo,
                     destinatarioNombre: f.destinatarioNombre,
                     destinatarioDireccion: f.destinatarioDireccion,
                     asunto: f.asunto,
                     saludo: f.saludo,
                     cuerpo: f.cuerpoHtml,
                     despedida: f.despedida,
                     firmas: Self.firmas(f.firmas),
                     observaciones: f.observaciones,
                     estado: f.estado,
                     entregadaA: f.entregadaA,
                     fechaEntrega: f.fechaEntrega)
    }

    static func aFila(_ c: CartaEmitida, previa: CartaFila?) -> CartaFila {
        CartaFila(id: c.id,
                  folio: c.folio,
                  tipo: c.tipo.clave,
                  fechaEmision: c.fechaEmision,
                  lugarEmision: c.lugarEmision,
                  miembroId: previa?.miembroId,
                  destinatarioTipo: c.destinatarioTipo,
                  destinatarioNombre: c.destinatarioNombre,
                  destinatarioDireccion: c.destinatarioDireccion,
                  asunto: c.asunto,
                  saludo: c.saludo,
                  cuerpoHtml: c.cuerpo,
                  despedida: c.despedida,
                  firmas: Self.jsonFirmas(c.firmas),
                  observaciones: c.observaciones,
                  estado: c.estado,
                  // El historial lo lleva el web; aquí no se toca para no
                  // borrarlo al reeditar una carta que vino de allá.
                  historialEstados: previa?.historialEstados ?? "[]",
                  entregadaA: c.entregadaA,
                  fechaEntrega: c.fechaEntrega,
                  actualizadoEn: previa?.actualizadoEn,
                  borrado: false)
    }

    /// **La firma del web es un objeto**, con nombre y cargo; el iOS solo pide
    /// el nombre. Se leen los dos y se escribe el nombre con el cargo vacío,
    /// igual que con los acuerdos de las actas.
    private struct FirmaJSON: Codable {
        var nombre: String
        var cargo: String = ""
    }

    static func firmas(_ json: String) -> [String] {
        guard let d = json.data(using: .utf8) else { return [] }
        if let v = try? JSONDecoder().decode([FirmaJSON].self, from: d) { return v.map(\.nombre) }
        // Una fila vieja puede traer una lista de cadenas.
        return (try? JSONDecoder().decode([String].self, from: d)) ?? []
    }

    static func jsonFirmas(_ nombres: [String]) -> String {
        let v = nombres.map { FirmaJSON(nombre: $0) }
        guard let d = try? JSONEncoder().encode(v),
              let s = String(data: d, encoding: .utf8) else { return "[]" }
        return s
    }

    private static func encolar(_ db: Database, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        let previa = try OperacionPendiente
            .filter(Column("entidad") == "carta" && Column("registroId") == id)
            .fetchOne(db)
        let efectiva: OperacionPendiente.Operacion =
            (previa?.operacion == OperacionPendiente.Operacion.crear.rawValue
             && operacion == .actualizar) ? .crear : operacion
        try OperacionPendiente
            .filter(Column("entidad") == "carta" && Column("registroId") == id)
            .deleteAll(db)
        var nueva = OperacionPendiente(id: nil, entidad: "carta", registroId: id,
                                       operacion: efectiva.rawValue,
                                       creadoEn: Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}

/// Maqueta sin sesión, base con ella.
func repositorioCartas() -> CartasRepository {
    ModoRevision.sinLogin ? MockCartasRepository() : OfflineCartasRepository()
}
