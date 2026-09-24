import Foundation
import GRDB

/// La configuración de la iglesia tal y como vive en SQLite.
struct IglesiaFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "iglesia"

    var id: String
    var nombre: String
    var direccion: String
    var ciudad: String
    var estado: String
    var pais: String
    var codigoPostal: String
    var idFiscal: String
    var telefono: String
    var correo: String
    var moneda: String
    var pieInstitucional: String
    var logoPath: String
    var saldoInicial: Int
    var pastorNombre: String
    var pastorCargo: String
    var tesoreroNombre: String
    var tesoreroCargo: String
    var tesoreroCorreo: String
    var tesoreroTelefono: String
    var pastorCorreo: String
    var pastorTelefono: String
    var secretarioNombre: String
    var secretarioCargo: String
    var imprimirFirmas: Bool
    var tesoreroVePadron: Bool
    var tesoreroPuedeEliminar: Bool
    var plan: String
    var subEstado: String
    var subVence: String
    var actualizadoEn: String?
    /// **La ficha tal como la tiene el servidor**, en JSON: la última que bajó o
    /// que se subió bien. Contra ella se ve qué campos cambió este aparato, y
    /// solo esos suben (ver `CamposIglesia`). Nula en las filas de antes del
    /// 24-sep: esas suben enteras, como siempre.
    var base: String? = nil

    init(id: String, _ c: ConfiguracionIglesia, actualizadoEn: String? = nil, base: String? = nil) {
        self.id = id
        nombre = c.nombre
        direccion = c.direccion
        ciudad = c.ciudad
        estado = c.estado
        pais = c.pais
        codigoPostal = c.codigoPostal
        idFiscal = c.idFiscal
        telefono = c.telefono
        correo = c.correo
        moneda = c.moneda
        pieInstitucional = c.pieInstitucional
        logoPath = c.logoPath
        saldoInicial = c.saldoInicial
        pastorNombre = c.pastorNombre
        pastorCargo = c.pastorCargo
        tesoreroNombre = c.tesoreroNombre
        tesoreroCargo = c.tesoreroCargo
        tesoreroCorreo = c.tesoreroCorreo
        tesoreroTelefono = c.tesoreroTelefono
        pastorCorreo = c.pastorCorreo
        pastorTelefono = c.pastorTelefono
        secretarioNombre = c.secretarioNombre
        secretarioCargo = c.secretarioCargo
        imprimirFirmas = c.imprimirFirmas
        tesoreroVePadron = c.tesoreroVePadron
        tesoreroPuedeEliminar = c.tesoreroPuedeEliminar
        plan = c.plan
        subEstado = c.subEstado
        subVence = c.subVence
        self.actualizadoEn = actualizadoEn
        self.base = base
    }

    var configuracion: ConfiguracionIglesia {
        ConfiguracionIglesia(
            nombre: nombre, direccion: direccion, ciudad: ciudad, estado: estado,
            pais: pais, codigoPostal: codigoPostal, idFiscal: idFiscal,
            telefono: telefono, correo: correo, moneda: moneda,
            pieInstitucional: pieInstitucional,
            logoPath: logoPath,
            saldoInicial: saldoInicial,
            pastorNombre: pastorNombre, pastorCargo: pastorCargo,
            tesoreroNombre: tesoreroNombre, tesoreroCargo: tesoreroCargo,
            tesoreroCorreo: tesoreroCorreo, tesoreroTelefono: tesoreroTelefono,
            pastorCorreo: pastorCorreo, pastorTelefono: pastorTelefono,
            secretarioNombre: secretarioNombre, secretarioCargo: secretarioCargo,
            imprimirFirmas: imprimirFirmas,
            tesoreroVePadron: tesoreroVePadron,
            tesoreroPuedeEliminar: tesoreroPuedeEliminar,
            plan: plan, subEstado: subEstado, subVence: subVence
        )
    }
}

/// **La ficha de la iglesia, campo a campo, como la columna de `iglesias`.**
///
/// Existe para subir SOLO lo que cambió. Hasta el 24-sep la subida mandaba la
/// ficha entera y ganaba la última: un aparato que había guardado un cambio sin
/// conexión lo subía días después encima de todo lo que otros hubieran
/// cambiado mientras tanto, en cualquier campo. Así volvió a la iglesia de
/// prueba el nombre de 500 caracteres de `TextoBruto`, a las 13:43 UTC, sobre
/// el «Iglesia de prueba» que había desde las 10:23.
///
/// Ahora se compara con la `base` —lo último que se sabe del servidor— y viaja
/// solo lo distinto. Si dos aparatos tocan campos distintos, se conservan los
/// dos cambios; si tocan el mismo, gana el último, como antes.
enum CamposIglesia {

    /// El valor de una columna. Texto, entero o booleano, que es lo que hay en
    /// la ficha; el nulo es el de los cargos vacíos.
    enum Valor: Codable, Equatable {
        case texto(String?), entero(Int), booleano(Bool)

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() { self = .texto(nil) }
            else if let b = try? c.decode(Bool.self) { self = .booleano(b) }
            else if let i = try? c.decode(Int.self) { self = .entero(i) }
            else { self = .texto(try c.decode(String.self)) }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .texto(let s): if let s { try c.encode(s) } else { try c.encodeNil() }
            case .entero(let i): try c.encode(i)
            case .booleano(let b): try c.encode(b)
            }
        }
    }

    /// Vacío es NULO en los cargos. Un `""` no es "sin cargo" para el web: su
    /// respaldo traducido solo salta con nulo.
    private static func oNulo(_ s: String) -> String? {
        let v = s.trimmingCharacters(in: .whitespaces)
        return v.isEmpty ? nil : v
    }

    /// Las columnas que SUBEN, con el nombre que tienen en `iglesias`. Los dos
    /// permisos y el plan bajan pero no suben (ver `ConfiguracionIglesia`).
    static func de(_ c: ConfiguracionIglesia) -> [String: Valor] {
        [
            "nombre": .texto(c.nombre), "direccion": .texto(c.direccion),
            "ciudad": .texto(c.ciudad), "estado": .texto(c.estado), "pais": .texto(c.pais),
            "codigo_postal": .texto(c.codigoPostal), "id_fiscal": .texto(c.idFiscal),
            "telefono": .texto(c.telefono), "correo": .texto(c.correo),
            "moneda": .texto(c.moneda), "pie_institucional": .texto(c.pieInstitucional),
            "logo_path": .texto(c.logoPath), "saldo_inicial": .entero(c.saldoInicial),
            "pastor_nombre": .texto(c.pastorNombre), "pastor_cargo": .texto(oNulo(c.pastorCargo)),
            "tesorero_nombre": .texto(c.tesoreroNombre), "tesorero_cargo": .texto(oNulo(c.tesoreroCargo)),
            "tesorero_email": .texto(c.tesoreroCorreo), "tesorero_telefono": .texto(c.tesoreroTelefono),
            "pastor_email": .texto(c.pastorCorreo), "pastor_telefono": .texto(c.pastorTelefono),
            "secretario_nombre": .texto(c.secretarioNombre),
            "secretario_cargo": .texto(oNulo(c.secretarioCargo)),
            "imprimir_firmas": .booleano(c.imprimirFirmas),
        ]
    }

    /// Lo que hay que subir: todo si no hay base, y si la hay, solo lo distinto.
    static func parche(_ c: ConfiguracionIglesia, base: String?) -> [String: Valor] {
        let ahora = de(c)
        guard let b = leer(base) else { return ahora }
        return ahora.filter { b[$0.key] != $0.value }
    }

    static func leer(_ json: String?) -> [String: Valor]? {
        guard let datos = json?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: Valor].self, from: datos)
    }

    static func escribir(_ campos: [String: Valor]) -> String? {
        guard let datos = try? JSONEncoder().encode(campos) else { return nil }
        return String(data: datos, encoding: .utf8)
    }
}
