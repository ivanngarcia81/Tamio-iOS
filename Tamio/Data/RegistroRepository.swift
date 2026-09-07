import Foundation
import GRDB

protocol RegistroRepository {
    func apuntes() async -> [Apunte]
    func escribirNota(_ apunte: Apunte) async
}

/// **La maqueta, con instantes en vez de "HOY" escrito.** La semilla llevaba
/// `hora`, `grupo` y `fecha` como texto —"12:40", "HOY", "Hoy · 30 de agosto"—,
/// así que al día siguiente los apuntes seguían diciendo HOY y la fecha se
/// quedó clavada en agosto. Ahora se colocan a partir de ahora mismo y la
/// pantalla los agrupa sola.
struct MockRegistroRepository: RegistroRepository {
    nonisolated(unsafe) private static var almacen: [Apunte] = semilla

    func apuntes() async -> [Apunte] {
        try? await Task.sleep(nanoseconds: 120_000_000)
        return Self.almacen.sorted { $0.creadoEn > $1.creadoEn }
    }

    func escribirNota(_ apunte: Apunte) async {
        Self.almacen.insert(apunte, at: 0)
    }

    /// Cuántas horas atrás va cada apunte. Se leen como los del handoff —cinco
    /// hoy, cuatro ayer, el resto atrás— sin depender de qué día se mire.
    private static var semilla: [Apunte] {
        func hace(_ horas: Double, _ tipo: TipoSuceso, _ datos: [String: String],
                  autor: String = "Tamio", cuerpo: String = "") -> Apunte {
            Apunte(id: UUID().uuidString, tipo: tipo, datos: datos, cuerpo: cuerpo,
                   autor: autor,
                   creadoEn: Date().addingTimeInterval(-horas * 3600))
        }
        return [
            // Hoy
            hace(1,  .nota, [:], autor: "Rocío Ibarra",
                 cuerpo: L.t("El pastor pidió que el corte del domingo se deposite el lunes temprano: en la tarde cierran la sucursal.",
                             "The pastor asked to deposit Sunday's cut early Monday: the branch closes in the afternoon.")),
            hace(3,  .corteDepositado, ["corte": L.t("Domingo 23 de agosto", "Sunday Aug 23")]),
            hace(4,  .segundaFirma,    ["corte": L.t("Domingo 23 de agosto", "Sunday Aug 23"),
                                        "quien": "Marta Solís"]),
            hace(5,  .cartaEmitida,    ["folio": "CAR-2026-0031", "nombre": "Javier Medina Rojas"]),
            hace(6,  .corteEntregado,  ["corte": L.t("Domingo 23 de agosto", "Sunday Aug 23"),
                                        "movimientos": "18"]),
            // Ayer
            hace(26, .descuadre,       ["corte": L.t("Miércoles 19 de agosto", "Wednesday Aug 19"),
                                        "contado": "$4,180.00"]),
            hace(28, .estadoMiembro,   ["nombre": "Ana Lucía Torres",
                                        "de": L.t("visitante", "visitor"),
                                        "a": L.t("activo", "active")]),
            hace(30, .actaCerrada,     ["folio": "2026-07"]),
            hace(32, .nota, [:], autor: "Rocío Ibarra",
                 cuerpo: L.t("Falta la firma del pastor en el acta de julio; se la llevo el domingo.",
                             "The pastor's signature is missing on July's minutes; I'll take it to him Sunday.")),
            // Antes
            hace(54, .movEliminado,    ["folio": "ING-2026-0184", "monto": "$1,200.00"]),
            hace(56, .bajaMiembro,     ["nombre": "Rosa Elena Vega",
                                        "motivo": L.t("traslado", "transfer")]),
            hace(78, .corteDepositado, ["corte": L.t("Domingo 16 de agosto", "Sunday Aug 16")]),
            hace(80, .corteEntregado,  ["corte": L.t("Domingo 16 de agosto", "Sunday Aug 16"),
                                        "movimientos": "21"]),
        ]
    }
}

/// El registro de verdad: tabla `registro` de la base local, y de ahí a
/// `public.registro` por el motor de sincronización.
struct OfflineRegistroRepository: RegistroRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func apuntes() async -> [Apunte] {
        (try? await cola.read { db in
            try ApunteFila
                .filter(Column("borrado") == false)
                .order(Column("creadoEn").desc)
                // Una bitácora crece sin parar y la pantalla enseña lo
                // reciente: traerla entera solo para descartarla es trabajo
                // que se nota en un teléfono viejo.
                .limit(500)
                .fetchAll(db)
                .map(Self.aApunte)
        }) ?? []
    }

    func escribirNota(_ apunte: Apunte) async {
        try? await cola.write { db in
            try Self.aFila(apunte).save(db)
            try Self.encolar(db, id: apunte.id, operacion: .crear)
        }
    }

    // MARK: - Traducción

    static func aApunte(_ f: ApunteFila) -> Apunte {
        Apunte(id: f.id,
               tipo: TipoSuceso(clave: f.tipo),
               datos: Self.datos(f.datos),
               cuerpo: f.cuerpo,
               autor: f.quien,
               creadoEn: Fechas.desdeISO(f.creadoEn) ?? Date(),
               area: ApunteArea(clave: f.area))
    }

    static func aFila(_ a: Apunte) -> ApunteFila {
        ApunteFila(id: a.id,
                   tipo: a.tipo.rawValue,
                   // Es la columna por la que el web decide quién ve qué:
                   // una consulta no puede depender de que el lector sepa
                   // derivarla del tipo.
                   area: a.area.rawValue,
                   datos: Self.json(a.datos),
                   cuerpo: a.cuerpo,
                   quien: a.autor,
                   creadoEn: Fechas.iso(a.creadoEn),
                   actualizadoEn: nil,
                   borrado: false)
    }

    /// Las piezas del texto. Lo que llegue ilegible se lee como vacío: un
    /// apunte con los datos rotos enseña guiones, pero la bitácora abre.
    static func datos(_ json: String) -> [String: String] {
        guard let d = json.data(using: .utf8),
              let v = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return v
    }

    static func json(_ v: [String: String]) -> String {
        guard let d = try? JSONEncoder().encode(v),
              let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }

    private static func encolar(_ db: Database, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        try OperacionPendiente
            .filter(Column("entidad") == "apunte" && Column("registroId") == id)
            .deleteAll(db)
        var nueva = OperacionPendiente(id: nil, entidad: "apunte", registroId: id,
                                       operacion: operacion.rawValue,
                                       creadoEn: Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}

/// Maqueta sin sesión, base con ella.
func repositorioRegistro() -> RegistroRepository {
    ModoRevision.sinLogin ? MockRegistroRepository() : OfflineRegistroRepository()
}
