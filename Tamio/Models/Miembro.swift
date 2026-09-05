import SwiftUI

/// Dónde está una persona dentro del registro, mientras no esté de baja. Son
/// los cuatro que se eligen a mano en el app web, con sus mismas claves: es lo
/// que viaja en `members.estado_membresia`, y solo significa algo mientras
/// `activo = 1`. Ver `docs/PADRON-WEB.md`.
enum EstadoRegistro: String, CaseIterable, Hashable {
    case activo, inactivo, visitante, enProceso

    var etiqueta: String {
        switch self {
        case .activo:    return L.t("Activo", "Active")
        case .inactivo:  return L.t("Inactivo", "Inactive")
        case .visitante: return L.t("Visitante", "Visitor")
        case .enProceso: return L.t("En proceso", "In process")
        }
    }
}

/// La salida del padrón: cuándo y por qué. **Sin fecha y motivo no hay
/// baja**: dentro de dos años una etiqueta gris no dice qué pasó con esa
/// persona.
struct Baja: Hashable {
    /// "YYYY-MM-DD", como el resto de fechas de la fila.
    let fecha: String
    /// Clave del catálogo (`traslado`, `fallecimiento`, `retiro`,
    /// `disciplina`) o texto libre: el app web guarda lo que se escribió
    /// cuando el motivo elegido es "otro".
    let motivo: String

    /// El catálogo, en el orden en que se ofrece.
    static let motivos = ["traslado", "fallecimiento", "retiro", "disciplina", "otro"]

    static func etiquetaMotivo(_ m: String) -> String {
        switch m {
        case "traslado":      return L.t("Traslado a otra iglesia", "Transfer to another church")
        case "fallecimiento": return L.t("Fallecimiento", "Passed away")
        case "retiro":        return L.t("Retiro", "Withdrawal")
        case "disciplina":    return L.t("Disciplina", "Discipline")
        case "otro":          return L.t("Otro", "Other")
        default:              return m
        }
    }

    /// La etiqueta que se enseña se DERIVA del motivo y no se guarda. Es
    /// `estadoDeBaja` del app web, tal cual: trasladado, fallecido, retirado,
    /// y cualquier otro motivo es "baja".
    var etiqueta: String {
        switch motivo {
        case "traslado":      return L.t("Trasladado", "Transferred")
        case "fallecimiento": return L.t("Fallecido", "Deceased")
        case "retiro":        return L.t("Retirado", "Withdrawn")
        default:              return L.t("Baja", "Removed")
        }
    }
}

/// Cómo está una persona en el padrón. **Son tres columnas y no una.**
///
/// Antes esto era un enum de cinco casos —activo, nuevo, traslado, baja,
/// recibido— que aplanaba en una sola palabra cosas de tres clases distintas:
///
/// - `activo` y `baja` sí son estados… pero en el servidor la baja es
///   `activo = 0` más fecha y motivo, y `estado_membresia` NI SE TOCA: quien
///   está de baja conserva el estado que tenía. Aquí se guarda igual, con
///   `registro` y `baja` como dos cosas.
/// - `nuevo` y `recibido` no eran estados sino CÁLCULOS. `MembresiaResumen` ya
///   lo decía diez líneas más abajo —"una misma persona puede ser nueva y
///   estar activa"— mientras el enum obligaba a elegir. Nuevo es tener la
///   fecha de ingreso en el periodo; recibido, venir de otra iglesia. Se
///   derivan de la ficha y no se escriben.
/// - `traslado` (en curso) era un expediente, no un estado: vive en
///   `traslados_salida`, con folio, carta y sus propias fechas. La persona
///   sigue activa hasta que el traslado se cierra.
///
/// Con el enum, una baja hecha desde el teléfono escribía "baja" en
/// `estado_membresia` y dejaba `activo = 1`: para el app web esa persona
/// seguía en el padrón.
struct EstadoMiembro: Hashable {
    var registro: EstadoRegistro
    var baja: Baja?

    static let activo = EstadoMiembro(registro: .activo, baja: nil)

    static func baja(_ fecha: String, _ motivo: String,
                     registro: EstadoRegistro = .activo) -> EstadoMiembro {
        EstadoMiembro(registro: registro, baja: Baja(fecha: fecha, motivo: motivo))
    }

    var esBaja: Bool { baja != nil }

    var etiqueta: String { baja?.etiqueta ?? registro.etiqueta }

    /// Una sola palabra para filtrar y para el CSV: los cuatro del registro, o
    /// `baja`. Sin traducir, porque un archivo exportado en español tiene que
    /// significar lo mismo al importarlo en inglés.
    var clave: String { esBaja ? "baja" : registro.rawValue }

    /// Las cinco claves que se pueden filtrar o importar.
    static let claves = EstadoRegistro.allCases.map(\.rawValue) + ["baja"]

    static func etiqueta(clave: String) -> String {
        clave == "baja" ? L.t("Baja", "Removed")
                        : (EstadoRegistro(rawValue: clave)?.etiqueta ?? clave)
    }

    /// Desde una clave suelta (CSV, filtro). Una baja que llega así viene sin
    /// fecha ni motivo, y se deja constancia con el motivo vacío antes que
    /// inventarlos.
    static func desde(clave: String) -> EstadoMiembro? {
        if clave == "baja" { return .baja("", "") }
        guard let r = EstadoRegistro(rawValue: clave) else { return nil }
        return EstadoMiembro(registro: r, baja: nil)
    }

    /// Activo y visitante son informativos; inactivo pide una acción —es la
    /// señal de seguimiento—; la baja es terminal, con o sin buen final.
    var estadoVisual: Paleta.Estado {
        if esBaja { return .terminal }
        switch registro {
        case .activo:               return .correcto
        case .inactivo:             return .pendiente
        case .visitante, .enProceso: return .informativo
        }
    }
    var color: Color { estadoVisual.color }
}

/// Un punto de la gráfica de asistencia del miembro (un mes).
struct MesAsistencia: Identifiable {
    var id: String { mes }
    let mes: String
    let valor: Double   // 0…1
}

/// Un miembro del padrón: lo de la lista y lo de la ficha.
struct Miembro: Identifiable, Hashable {
    let id: String
    let nombre: String
    let subtitulo: String        // "Ingresó 2019 · miembro activo"
    let estado: EstadoMiembro
    let asistenciaPct: Int

    // Ficha.
    let area: String             // "Enseñanza · niños"
    let miembroDesde: String     // "Ingresó 2014"
    let asistencia: [MesAsistencia]
    let enRoster: String         // "26 de 27"
    let rachaSinAsistir: String  // "0 servicios"
    let ultimaVisita: String     // "23 ago"
    /// Razón pastoral mostrada en la pestaña Seguimiento ("Tres servicios sin asistir").
    /// `nil` = no necesita seguimiento.
    let seguimientoRazon: String?
    /// Nota contextual para "SIN ASISTIR ÚLTIMAMENTE" en Asistencia ("· traslado", "· enfermedad").
    let ausenciaNota: String?
    let datos: [Dato]
    let expediente: [ItemExpediente]
    let movimientos: [MovMembresia]
    var seguimientoNotas: [SeguimientoNota] = []
    /// Parentescos del padrón. Viven aquí, en Secretaría, porque es quien los
    /// conoce y los mantiene; Tesorería solo los consulta en la ficha del
    /// aportante (para la constancia anual conjunta de un matrimonio).
    var familia: [Pariente] = []

    var iniciales: String {
        let partes = nombre.split(separator: " ")
        let ini = partes.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return ini.uppercased()
    }

    static func == (l: Miembro, r: Miembro) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Dato: Identifiable { let id = UUID(); let etiqueta: String; let valor: String }
struct ItemExpediente: Identifiable { let id = UUID(); let campo: String; let completo: Bool }
struct MovMembresia: Identifiable { let id = UUID(); let titulo: String; let fecha: String }

enum TipoSeguimiento: String, CaseIterable {
    case llamada, visita, oracion, mensaje, citaPastoral, otro

    var etiqueta: String {
        switch self {
        case .llamada:      return L.t("Llamada", "Call")
        case .visita:       return L.t("Visita", "Visit")
        case .oracion:      return L.t("Oración", "Prayer")
        case .mensaje:      return L.t("Mensaje", "Message")
        case .citaPastoral: return L.t("Cita pastoral", "Pastoral meeting")
        case .otro:         return L.t("Otro", "Other")
        }
    }
    var icono: String {
        switch self {
        case .llamada:      return "phone"
        case .visita:       return "house"
        case .oracion:      return "hands.sparkles"
        case .mensaje:      return "message"
        case .citaPastoral: return "person.2"
        case .otro:         return "ellipsis.circle"
        }
    }
}

struct SeguimientoNota: Identifiable {
    let id = UUID()
    let tipo: TipoSeguimiento
    let fecha: Date
    let descripcion: String
    var completado: Bool = false
}

/// Los 8 indicadores del padrón (arriba de la ficha).
struct MembresiaResumen {
    /// Los tres estados en que puede estar una persona del padrón. Se
    /// excluyen entre sí y no dejan a nadie fuera.
    let activos, inactivos, bajas: Int
    /// Movimientos del periodo, no estados: una misma persona puede ser nueva
    /// y estar activa. Por eso NO entran en el total.
    let nuevos, recibidos, trasladados: Int
    /// Señales para trabajar, tampoco estados.
    let ausencias, incompletos: Int

    /// **El total no se escribe: se suma.** Iba a mano como 248 mientras la
    /// misma tarjeta enseñaba 236 activos y 6 inactivos: había seis personas
    /// que solo existían en el encabezado, y el encabezado es lo que el
    /// pastor lee. Calculado, no puede volver a descuadrar.
    var total: Int { activos + inactivos + bajas }
}

/// Un mes en la gráfica de asistencia congregacional (Presentes vs. En roster).
struct MesAsistenciaCongregacion: Identifiable {
    var id: String { mes }
    let mes: String
    let presentes: Int
    let enRoster: Int
    var pct: Double { enRoster > 0 ? Double(presentes) / Double(enRoster) : 0 }
}

struct TipoAsistencia: Identifiable {
    var id: String { tipo }
    let tipo: String
    let promedio: Int
}

/// Todo lo que la pestaña Asistencia necesita a nivel congregación.
struct AsistenciaResumen {
    let promedioPct: Int            // 74
    let serviciosPeriodo: Int       // 27
    let presentesPromedio: Int      // 186
    let mejorServicio: String       // "214 · 23 ago"
    let meses: [MesAsistenciaCongregacion]
    let porTipo: [TipoAsistencia]
}
