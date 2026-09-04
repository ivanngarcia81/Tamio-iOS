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
        let total = aportes.reduce(0) { $0 + $1.monto }
        return Aportante(
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
            aportesTotal: total,
            aportesPromedio: Self.promedio(aportes),
            aportesSerie: Self.serie(aportes),
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

    /// "Promedio $3,275.00 en 8 meses con aporte". Antes era el mismo texto
    /// escrito a mano para todo el mundo.
    private static func promedio(_ aportes: [Aporte]) -> String {
        guard !aportes.isEmpty else { return L.t("Sin aportes aún", "No giving yet") }
        let cal = Calendar.current
        let meses = Set(aportes.map { cal.dateComponents([.year, .month], from: $0.fecha) })
        let total = aportes.reduce(0) { $0 + $1.monto }
        let media = total / max(1, meses.count)
        return L.t("Promedio \(Money.fmt(media)) en \(meses.count) meses con aporte",
                   "Avg \(Money.fmt(media)) over \(meses.count) months with giving")
    }

    /// Los últimos ocho meses, para la gráfica de la ficha.
    private static func serie(_ aportes: [Aporte]) -> [MesAporte] {
        let cal = Calendar.current
        let hoy = Date()
        return (0..<8).reversed().compactMap { atras in
            guard let mes = cal.date(byAdding: .month, value: -atras, to: hoy) else { return nil }
            let comps = cal.dateComponents([.year, .month], from: mes)
            let suma = aportes
                .filter { cal.dateComponents([.year, .month], from: $0.fecha) == comps }
                .reduce(0) { $0 + $1.monto }
            return MesAporte(mes: L.mesCorto(mes), monto: suma)
        }
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
