import SwiftUI

/// Estado de un miembro en el padrón.
enum EstadoMiembro {
    case activo, nuevo, traslado, baja, recibido

    var etiqueta: String {
        switch self {
        case .activo: return L.t("Activo", "Active")
        case .nuevo: return L.t("Nuevo", "New")
        case .traslado: return L.t("Traslado", "Transfer")
        case .baja: return L.t("Baja", "Removed")
        case .recibido: return L.t("Recibido", "Received")
        }
    }
    var color: Color {
        switch self {
        case .activo: return Paleta.brand
        case .nuevo: return Color(hex: 0x3B82F6)
        case .traslado: return Paleta.aviso
        case .baja: return Color(hex: 0x64748B)
        case .recibido: return Color(hex: 0x06B6D4)
        }
    }
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
    let total, activos, inactivos, nuevos, recibidos, trasladados, ausencias, incompletos: Int
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
