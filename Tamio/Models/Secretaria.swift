import SwiftUI

// MARK: - Actas

enum EstadoActa {
    case borrador, pendienteAprobacion, aprobada, enmendada, archivada, firmada, cerrada

    var etiqueta: String {
        switch self {
        case .borrador:            return L.t("Borrador", "Draft")
        case .pendienteAprobacion: return L.t("Pendiente", "Pending approval")
        case .aprobada:            return L.t("Aprobada", "Approved")
        case .enmendada:           return L.t("Enmendada", "Amended")
        case .archivada:           return L.t("Archivada", "Archived")
        case .firmada:             return L.t("Firmada", "Signed")
        case .cerrada:             return L.t("Cerrada", "Closed")
        }
    }
    var color: Color {
        switch self {
        case .borrador:            return Paleta.aviso
        case .pendienteAprobacion: return Color(hex: 0xF97316)
        case .aprobada:            return Paleta.brand
        case .enmendada:           return Color(hex: 0x7C3AED)
        case .archivada:           return Color(.secondaryLabel)
        case .firmada:             return Paleta.brand
        case .cerrada:             return Color(.secondaryLabel)
        }
    }
}

struct AcuerdoActa: Identifiable {
    let id: Int
    let texto: String
}

struct Acta: Identifiable, Hashable {
    let id: Int
    let folio: String
    let tipo: String
    let fecha: String
    let acuerdos: Int
    var estado: EstadoActa
    let cuerpo: String
    let items: [AcuerdoActa]
    var tituloPersonalizado: String? = nil

    var titulo: String {
        if let t = tituloPersonalizado, !t.isEmpty { return t }
        return "Acta \(folio) · \(tipo)"
    }
    var subtitulo: String {
        let ac = acuerdos > 0 ? " · \(acuerdos) \(L.t("acuerdos", "agreements"))" : ""
        return "\(fecha)\(ac) · \(estado.etiqueta.lowercased())"
    }

    static func == (l: Acta, r: Acta) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Servicios

enum EstadoRoster {
    case completo, parcial, faltaUjier, sinAsignar

    var etiqueta: String {
        switch self {
        case .completo:    return L.t("roster completo", "full roster")
        case .parcial:     return L.t("roster parcial", "partial roster")
        case .faltaUjier:  return L.t("falta ujier", "missing usher")
        case .sinAsignar:  return L.t("sin asignar", "unassigned")
        }
    }
    var color: Color {
        switch self {
        case .completo:   return Paleta.brand
        case .parcial:    return Paleta.aviso
        case .faltaUjier: return Paleta.aviso
        case .sinAsignar: return Color(.secondaryLabel)
        }
    }
}

struct AsignacionRoster: Identifiable {
    let id: Int
    let rol: String
    let persona: String?
    let extras: Int

    var display: String {
        guard let p = persona else { return L.t("Asignar encargado", "Assign person") }
        return extras > 0 ? "\(p) +\(extras)" : p
    }
    var asignado: Bool { persona != nil }
}

struct AsistenciaServicio: Identifiable {
    let id: Int
    let fecha: String
    let presentes: Int
    let total: Int
    var pct: Double { total > 0 ? Double(presentes) / Double(total) : 0 }
}

struct PuntoOrden: Identifiable {
    let id: Int
    let hora: String
    let descripcion: String
}

struct Servicio: Identifiable, Hashable {
    let id: Int
    let diaSemana: String
    let numDia: String
    let titulo: String
    let hora: String
    let lugar: String
    var estadoRoster: EstadoRoster
    var roster: [AsignacionRoster]
    var historial: [AsistenciaServicio]
    let orden: [PuntoOrden]
    // Campos del formulario (opcionales, con valores por defecto para no romper mock existente)
    var lideroServicio: String? = nil
    var predico: String? = nil
    var canciones: [String] = []
    var tituloMensaje: String? = nil
    var textoBiblico: String? = nil
    var resumenMensaje: String? = nil
    var temaEscuelaDominica: String? = nil
    var maestroEscuela: String? = nil
    var eventosEspeciales: String? = nil
    var visitantes: [String] = []
    var ninos: Int = 0
    var jovenes: Int = 0
    var adultos: Int = 0

    var subtitulo: String { "\(hora) · \(estadoRoster.etiqueta)" }

    static func == (l: Servicio, r: Servicio) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Cartas

enum TipoPlantilla: String, CaseIterable, Identifiable {
    // Ordered to match web app screenshot
    case recomendacion, certificadoMiembro, buenaConducta, presentacion
    case invitacion, agradecimiento, autorizacion, solicitud
    case nombramiento, reconocimiento, certificadoServicio
    case traslado, personalizada
    // Legacy — kept for existing mock data
    case bautismo, bienvenida
    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .recomendacion:        return L.t("Carta de recomendación", "Recommendation letter")
        case .certificadoMiembro:   return L.t("Constancia de membresía activa", "Active member certificate")
        case .buenaConducta:        return L.t("Carta de buena conducta", "Good conduct letter")
        case .presentacion:         return L.t("Carta de presentación", "Introduction letter")
        case .invitacion:           return L.t("Carta de invitación", "Invitation")
        case .agradecimiento:       return L.t("Carta de agradecimiento", "Thank you letter")
        case .autorizacion:         return L.t("Carta de autorización", "Authorization")
        case .solicitud:            return L.t("Solicitud", "Request")
        case .nombramiento:         return L.t("Nombramiento ministerial", "Ministerial appointment")
        case .reconocimiento:       return L.t("Reconocimiento", "Recognition")
        case .certificadoServicio:  return L.t("Constancia de servicio", "Certificate of service")
        case .traslado:             return L.t("Carta de traslado", "Transfer letter")
        case .personalizada:        return L.t("Personalizada", "Custom")
        case .bautismo:             return L.t("Constancia de bautismo", "Baptism certificate")
        case .bienvenida:           return L.t("Carta de bienvenida", "Welcome letter")
        }
    }
    var subtitulo: String {
        switch self {
        case .recomendacion:       return L.t("Buena conducta y membresía", "Good conduct & membership")
        case .certificadoMiembro:  return L.t("Con folio y datos de membresía", "With membership number and data")
        case .buenaConducta:       return L.t("Para gestiones externas", "For external procedures")
        case .presentacion:        return L.t("Ante otra congregación o institución", "To another congregation")
        case .invitacion:          return L.t("Para evento o actividad", "For an event or activity")
        case .agradecimiento:      return L.t("Donativo o servicio recibido", "For a donation or service rendered")
        case .autorizacion:        return L.t("Permiso o delegación de funciones", "Permission or delegation")
        case .solicitud:           return L.t("Petición formal a institución", "Formal request to an institution")
        case .nombramiento:        return L.t("Cargo pastoral o ministerial", "Pastoral or ministerial role")
        case .reconocimiento:      return L.t("Años de servicio o logro", "Years of service or achievement")
        case .certificadoServicio: return L.t("Historial de participación", "Participation record")
        case .traslado:            return L.t("Aportante que cambia de iglesia", "Member changing church")
        case .personalizada:       return L.t("Sin plantilla predefinida", "No predefined template")
        case .bautismo:            return L.t("Con fecha y oficiante", "With date and officiant")
        case .bienvenida:          return L.t("Nuevo miembro recibido", "New member received")
        }
    }
    var icono: String {
        switch self {
        case .recomendacion:       return "doc.badge.checkmark"
        case .certificadoMiembro:  return "checkmark.circle"
        case .buenaConducta:       return "checkmark.seal"
        case .presentacion:        return "hand.raised"
        case .invitacion:          return "envelope.badge"
        case .agradecimiento:      return "heart.text.clipboard"
        case .autorizacion:        return "pencil.circle"
        case .solicitud:           return "doc.text"
        case .nombramiento:        return "star.circle"
        case .reconocimiento:      return "star.fill"
        case .certificadoServicio: return "list.bullet.rectangle"
        case .traslado:            return "arrow.right.doc.on.clipboard"
        case .personalizada:       return "doc.badge.plus"
        case .bautismo:            return "drop.circle"
        case .bienvenida:          return "hand.wave"
        }
    }
}

struct CartaEmitida: Identifiable {
    let id: Int
    let iniciales: String
    let persona: String
    let tipo: TipoPlantilla
}

struct CartaEnEdicion {
    // Campos existentes (usados por el editor de detalle)
    var tipo: TipoPlantilla = .traslado
    var aportante: String = "Javier Medina Cruz"
    var iglesiaDestino: String = "Iglesia El Buen Pastor"
    var miembroDesde: String = "2018"
    var firma: String = "Pastor Abel Ramos"

    var camposCompletos: Int {
        [aportante, iglesiaDestino, miembroDesde].filter { !$0.isEmpty }.count
    }
    var camposTotales: Int { 3 }

    // Campos del formulario de creación
    var fechaEmision: Date = Date()
    var lugarEmision: String = ""
    var tipoDestinatario: String = ""
    var miembroSeleccionado: String = ""
    var direccionDestinatario: String = ""
    var asunto: String = ""
    var saludo: String = ""
    var cuerpoTexto: String = ""
    var cierre: String = ""
    var firmantes: [String] = []
    var estadoCarta: String = ""
    var notasInternas: String = ""
}

// MARK: - Agenda

enum TipoEvento: CaseIterable {
    // Originales (mantenidos para mock existente)
    case culto, reunion, deposito, carta, tarea
    // Nuevos — coinciden con la app web
    case cultoEspecial, reunionLideres, reunionAdministrativa
    case asamblea, cenaPascual, bautismo, dedicacionNino
    case boda, vigilia, campana, conferencia, retiro
    case ensayo, actividadJovenes, actividadHombres, actividadDamas
    case actividadNinos, actividadComunitaria, fechaLimite, otro

    var titulo: String {
        switch self {
        case .culto:                 return L.t("Culto regular", "Regular service")
        case .cultoEspecial:         return L.t("Culto especial", "Special service")
        case .reunionLideres:        return L.t("Reunión de líderes", "Leaders' meeting")
        case .reunionAdministrativa: return L.t("Reunión administrativa", "Administrative meeting")
        case .reunion:               return L.t("Reunión", "Meeting")
        case .asamblea:              return L.t("Asamblea", "Assembly")
        case .cenaPascual:           return L.t("Cena del Señor", "Lord's Supper")
        case .bautismo:              return L.t("Bautismo", "Baptism")
        case .dedicacionNino:        return L.t("Dedicación de niño", "Child dedication")
        case .boda:                  return L.t("Boda", "Wedding")
        case .vigilia:               return L.t("Vigilia", "Vigil")
        case .campana:               return L.t("Campaña", "Campaign")
        case .conferencia:           return L.t("Conferencia", "Conference")
        case .retiro:                return L.t("Retiro", "Retreat")
        case .ensayo:                return L.t("Ensayo", "Rehearsal")
        case .actividadJovenes:      return L.t("Actividad de jóvenes", "Youth activity")
        case .actividadHombres:      return L.t("Actividad de hombres", "Men's activity")
        case .actividadDamas:        return L.t("Actividad de damas", "Women's activity")
        case .actividadNinos:        return L.t("Actividad de niños", "Children's activity")
        case .actividadComunitaria:  return L.t("Actividad comunitaria", "Community activity")
        case .deposito:              return L.t("Depósito", "Deposit")
        case .carta:                 return L.t("Carta", "Letter")
        case .fechaLimite:           return L.t("Fecha límite", "Deadline")
        case .tarea:                 return L.t("Tarea", "Task")
        case .otro:                  return L.t("Otra actividad", "Other activity")
        }
    }

    var color: Color {
        switch self {
        case .culto, .cultoEspecial, .cenaPascual, .bautismo,
             .dedicacionNino, .boda, .vigilia, .campana:
            return Paleta.brand
        case .reunion, .reunionLideres, .reunionAdministrativa, .asamblea:
            return Color(hex: 0x7C3AED)
        case .conferencia, .retiro, .ensayo, .actividadJovenes, .actividadHombres,
             .actividadDamas, .actividadNinos, .actividadComunitaria:
            return Color(hex: 0x3B82F6)
        case .deposito:
            return Color(hex: 0xF97316)
        case .carta:
            return Color(hex: 0x06B6D4)
        case .tarea, .fechaLimite, .otro:
            return Color(.secondaryLabel)
        }
    }
}

struct EventoAgenda: Identifiable {
    let id: Int
    let dia: Int
    let hora: String?
    let titulo: String
    let descripcion: String
    let tipo: TipoEvento
    let completado: Bool
    // Campos extendidos (con defaults para no romper mock existente)
    var todoDia: Bool = false
    var horaFin: String? = nil
    var lugar: String = ""
    var responsable: String = ""
    var ministerio: String = ""
    var presupuesto: String = ""
    var notaPie: String = ""
    var repeticion: String = ""
    var estadoEvento: String = ""
    var esFechaImportante: Bool = false
    var recordatorios: [String] = []
}

// MARK: - Informes

struct MesAlta: Identifiable {
    let id: Int
    let mes: String
    let altas: Int
}

struct MovimientoTraslado: Identifiable {
    let id: Int
    let folio: String
    let tipoTraslado: String
    let persona: String
    let iglesia: String
    let fecha: String
    let estado: String
}

struct InformeResumen {
    let totalMiembros: Int
    let periodo: String
    let porEstado: [(String, Int)]
    let porMinisterio: [(String, Int)]
    let expedienteCompleto: Int
    let expedienteIncompleto: Int
    let altasPorMes: [MesAlta]
    let traslados: [MovimientoTraslado]
}
