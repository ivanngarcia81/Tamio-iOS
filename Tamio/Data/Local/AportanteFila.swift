import Foundation
import GRDB

/// Un aportante tal y como vive en SQLite: solo sus datos.
///
/// Sus aportes no están aquí a propósito. Un aporte no es una entidad
/// independiente: es un ingreso de `movimiento` que lleva su `memberUid`.
/// Guardarlos por separado sería tener la misma cifra en dos sitios, y tarde o
/// temprano dejarían de coincidir.
struct AportanteFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "aportante"

    var id: String
    var nombre: String
    var estado: String
    var telefono: String
    var correo: String
    var nacimiento: String
    var direccion: String
    var estadoCivil: String
    var idFiscal: String
    var miembroDesde: String
    var congregaDesde: String
    var frecuencia: String
    var actualizadoEn: String?
    var borrado: Bool

    init(_ a: Aportante, actualizadoEn: String? = nil, borrado: Bool = false) {
        id = a.id
        nombre = a.nombre
        estado = Self.texto(a.estado)
        telefono = a.telefono
        correo = a.correo
        nacimiento = a.nacimiento
        direccion = a.direccion
        estadoCivil = a.estadoCivil
        idFiscal = a.idFiscal
        miembroDesde = a.miembroDesde
        congregaDesde = a.congregaDesde
        frecuencia = a.frecuencia.rawValue
        self.actualizadoEn = actualizadoEn
        self.borrado = borrado
    }

    /// Se le pasan los aportes ya calculados desde los movimientos, en vez de
    /// que la fila los invente.
    func aportante(aportes: [Aporte]) -> Aportante {
        Aportante(
            id: id,
            nombre: nombre,
            estado: Self.estado(estado),
            rol: Self.rol(aportes),
            miembroDesde: miembroDesde,
            telefono: telefono,
            correo: correo,
            nacimiento: nacimiento,
            direccion: direccion,
            estadoCivil: estadoCivil,
            idFiscal: idFiscal,
            congregaDesde: congregaDesde,
            frecuencia: FrecuenciaAporte(rawValue: frecuencia) ?? .ocasional,
            aportes: aportes.sorted { $0.fecha > $1.fecha },
            familia: []
        )
    }

    // MARK: - Derivados

    /// El rol sale de lo que la persona da, no de una etiqueta que alguien
    /// puso a mano y nadie volvió a mirar.
    private static func rol(_ aportes: [Aporte]) -> String {
        let diezmo = L.t("Diezmo", "Tithe")
        let cuantos = aportes.filter { $0.concepto.localizedCaseInsensitiveContains(diezmo) }.count
        return cuantos * 2 >= aportes.count && !aportes.isEmpty
            ? L.t("diezmo", "tithe") : L.t("donador", "donor")
    }

    // MARK: - Estado

    static func texto(_ e: EstadoMiembro) -> String {
        switch e {
        case .activo: return "activo"
        case .nuevo: return "nuevo"
        case .traslado: return "traslado"
        case .baja: return "baja"
        case .recibido: return "recibido"
        }
    }

    static func estado(_ texto: String) -> EstadoMiembro {
        switch texto.lowercased() {
        case "nuevo": return .nuevo
        case "traslado": return .traslado
        case "baja": return .baja
        case "recibido": return .recibido
        default: return .activo
        }
    }
}
