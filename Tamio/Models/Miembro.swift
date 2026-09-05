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

/// Un cambio de estado del padrón, como lo guarda `members.historial_estados`:
/// `{de, a, fecha}`. El web lo escribe solo cuando el estado cambia de verdad.
struct CambioEstado: Codable, Hashable {
    let de: String
    let a: String
    let fecha: String   // "YYYY-MM-DD"
}

/// Un miembro del padrón: **la fila, con forma de fila.**
///
/// Antes esto tenía forma de pantalla: `subtitulo` era "Ingresó 2019 ·
/// miembro activo", `miembroDesde` era "Ingresó 2014", y todo lo que no tenía
/// campo propio iba en `datos`, una lista de pares etiqueta-valor que la hoja
/// de alta escribía con "✓" y volvía a parsear al editar buscando la etiqueta
/// traducida. De ahí salían los campos que se perdían al guardar. Nada de eso
/// se podía leer de una tabla sin inventarse texto.
///
/// Ahora los campos son los de `members` —las mismas claves, las mismas
/// listas JSON, las mismas fechas "YYYY-MM-DD"— y lo que la pantalla enseña
/// (`subtitulo`, `datos`, `expediente`, `movimientos`) se CALCULA. Los datos
/// compartidos con Tesorería (nombre, contacto, estado, fechas) son la misma
/// fila de `aportante`; el resto son las columnas que abrió la v15.
///
/// La asistencia sigue viniendo de fuera hasta la v16: son cadenas porque
/// todavía no hay `servicios` de donde contarlas.
struct Miembro: Identifiable, Hashable {
    let id: String
    var nombre: String
    var estado: EstadoMiembro = .activo

    // Compartido con Tesorería: la misma fila.
    var telefono = ""
    var correo = ""
    var direccion = ""
    /// Clave de `Padron.estadosCiviles` o texto libre. Vacío = no se preguntó.
    var estadoCivil = ""
    var nacimiento = ""          // "YYYY-MM-DD"
    var idFiscal = ""
    /// `fecha_ingreso`: recibido como miembro. Es la que cuenta como alta.
    var fechaIngreso = ""
    /// `fecha_congregacion`: cuándo empezó a venir.
    var fechaCongregacion = ""

    // El padrón (v15).
    var iglesiaAnterior = ""
    var bautizadoAgua = false
    var fechaBautismoAgua = ""
    var bautizadoEspiritu = false
    var fechaBautismoEspiritu = ""
    var cursoMembresia = false
    /// Claves de `Padron`, o texto libre.
    var ministerios: [String] = []
    var ministeriosInteres: [String] = []
    var cargos: [String] = []
    var instrumentos: [String] = []
    var habilidades: [String] = []
    var etiquetas: [String] = []
    var disponibilidad = ""
    var interesServir = false
    var notas = ""
    var historialEstados: [CambioEstado] = []
    var seguimientoNotas: [SeguimientoNota] = []
    var seguimientoRevisadoEn = ""
    /// Parentescos. Viven en Secretaría, porque es quien los conoce y los
    /// mantiene; Tesorería solo los consulta en la ficha del aportante.
    var familia: [Pariente] = []

    // Asistencia. Hasta la v16 no hay de dónde contarla.
    var asistenciaPct = 0
    var asistencia: [MesAsistencia] = []
    var enRoster = ""
    var rachaSinAsistir = ""
    var ultimaVisita = ""
    /// Razón pastoral de la pestaña Seguimiento. `nil` = no necesita.
    var seguimientoRazon: String? = nil
    /// Nota contextual de "Sin asistir últimamente" ("· enfermedad").
    var ausenciaNota: String? = nil

    // MARK: - Derivados

    var iniciales: String {
        let partes = nombre.split(separator: " ")
        return partes.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var añoIngreso: Int? { Int(fechaIngreso.prefix(4)) }

    /// Los ministerios en los que sirve, para leer: "Enseñanza, Niños".
    var area: String {
        ministerios.isEmpty ? L.t("Sin área", "No area") : Padron.etiquetas(ministerios)
    }

    var miembroDesde: String {
        guard let año = añoIngreso else { return L.t("Sin fecha de ingreso", "No join date") }
        return L.t("Ingresó \(String(año))", "Joined \(String(año))")
    }

    /// **Recibido y nuevo no son estados: se deducen.** Recibido es venir de
    /// otra iglesia; nuevo, haber ingresado este año — que es como el web
    /// cuenta sus altas.
    var esRecibido: Bool { !iglesiaAnterior.trimmingCharacters(in: .whitespaces).isEmpty }
    func esNuevo(en año: Int = Calendar.current.component(.year, from: Date())) -> Bool {
        añoIngreso == año
    }

    var subtitulo: String {
        if estado.esBaja { return estado.etiqueta }
        if esRecibido { return L.t("Recibido por traslado", "Received by transfer") }
        if esNuevo() { return L.t("Nuevo este año", "New this year") }
        return "\(miembroDesde) · \(area.lowercased())"
    }

    /// Lo que la ficha enseña en su tarjeta de datos. Se calcula de los campos
    /// —antes SE GUARDABA aquí, y era donde se perdían—.
    var datos: [Dato] {
        var d: [Dato] = []
        func f(_ es: String, _ en: String, _ v: String) { if !v.isEmpty { d.append(Dato(etiqueta: L.t(es, en), valor: v)) } }
        func fecha(_ es: String, _ en: String, _ v: String) { if !v.isEmpty { f(es, en, Fechas.diaLegible(v)) } }
        fecha("Fecha de ingreso", "Join date", fechaIngreso)
        fecha("Se congrega desde", "Attends since", fechaCongregacion)
        if let b = estado.baja {
            fecha("Fecha de baja", "Removal date", b.fecha)
            f("Motivo", "Reason", Baja.motivos.contains(b.motivo) ? Baja.etiquetaMotivo(b.motivo) : b.motivo)
        }
        f("Teléfono", "Phone", telefono)
        f("Correo", "Email", correo)
        f("Dirección", "Address", direccion)
        fecha("Nacimiento", "Birth date", nacimiento)
        f("Estado civil", "Marital status", estadoCivil.isEmpty ? "" : Padron.etiqueta(estadoCivil))
        f("ID fiscal", "Tax ID", idFiscal)
        if bautizadoAgua { f("Bautismo en agua", "Water baptism", fechaBautismoAgua.isEmpty ? "✓" : Fechas.diaLegible(fechaBautismoAgua)) }
        if bautizadoEspiritu { f("Bautismo en el Espíritu", "Spirit baptism", fechaBautismoEspiritu.isEmpty ? "✓" : Fechas.diaLegible(fechaBautismoEspiritu)) }
        if cursoMembresia { f("Curso de membresía", "Membership course", "✓") }
        f("Ministerios", "Ministries", Padron.etiquetas(ministerios))
        f("Cargos", "Roles", Padron.etiquetas(cargos))
        f("Instrumentos", "Instruments", Padron.etiquetas(instrumentos))
        f("Habilidades", "Skills", Padron.etiquetas(habilidades))
        f("Ministerios de interés", "Ministries of interest", Padron.etiquetas(ministeriosInteres))
        f("Disponibilidad", "Availability", disponibilidad)
        if interesServir { f("Interés en servir", "Interested in serving", "✓") }
        f("Iglesia anterior", "Previous church", iglesiaAnterior)
        f("Notas", "Notes", notas)
        return d
    }

    /// Lo que falta por preguntar. Es el mismo criterio con el que el padrón
    /// cuenta sus "Incompletos", así que la ficha y la lista no discrepan.
    var expediente: [ItemExpediente] {
        [
            ItemExpediente(campo: L.t("Nombre y apellidos", "Full name"),   completo: !nombre.isEmpty),
            ItemExpediente(campo: L.t("Teléfono", "Phone"),                 completo: !telefono.isEmpty),
            ItemExpediente(campo: L.t("Correo", "Email"),                   completo: !correo.isEmpty),
            ItemExpediente(campo: L.t("Dirección", "Address"),              completo: !direccion.isEmpty),
            ItemExpediente(campo: L.t("Bautismo", "Baptism"),               completo: bautizadoAgua),
            ItemExpediente(campo: L.t("Fecha de nacimiento", "Birth date"), completo: !nacimiento.isEmpty),
            ItemExpediente(campo: L.t("Estado civil", "Marital status"),    completo: !estadoCivil.isEmpty),
        ]
    }

    var expedienteCompleto: Bool { !expediente.contains { !$0.completo } }

    /// El historial de la ficha, de más reciente a más antiguo: la alta, los
    /// bautismos y cada cambio de estado que el web dejó apuntado.
    var movimientos: [MovMembresia] {
        var m: [(String, String)] = []
        if !fechaIngreso.isEmpty {
            m.append((esRecibido ? L.t("Recibido por traslado", "Received by transfer")
                                 : L.t("Alta como miembro", "Added as member"), fechaIngreso))
        }
        if bautizadoAgua, !fechaBautismoAgua.isEmpty { m.append((L.t("Bautismo en agua", "Water baptism"), fechaBautismoAgua)) }
        if bautizadoEspiritu, !fechaBautismoEspiritu.isEmpty { m.append((L.t("Bautismo en el Espíritu", "Spirit baptism"), fechaBautismoEspiritu)) }
        for c in historialEstados {
            m.append((L.t("De \(EstadoMiembro.etiqueta(clave: c.de)) a \(EstadoMiembro.etiqueta(clave: c.a))",
                          "From \(EstadoMiembro.etiqueta(clave: c.de)) to \(EstadoMiembro.etiqueta(clave: c.a))"), c.fecha))
        }
        if let b = estado.baja, !b.fecha.isEmpty { m.append((b.etiqueta, b.fecha)) }
        return m.sorted { $0.1 > $1.1 }.map { MovMembresia(titulo: $0.0, fecha: Fechas.diaLegible($0.1)) }
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

/// Una nota de seguimiento pastoral. Viaja en `members.seguimiento_notas`
/// como `{fecha, texto}`, que es lo que el web escribe y lee; `tipo` y
/// `completado` son de esta app y van en el mismo JSON, donde el web los
/// ignora sin romperse. Decidido a propósito, no por accidente.
struct SeguimientoNota: Identifiable, Hashable, Codable {
    var id = UUID()
    var tipo: TipoSeguimiento
    var fecha: Date
    var descripcion: String
    var completado: Bool = false

    init(tipo: TipoSeguimiento, fecha: Date, descripcion: String, completado: Bool = false) {
        self.tipo = tipo; self.fecha = fecha; self.descripcion = descripcion; self.completado = completado
    }

    private enum Claves: String, CodingKey { case fecha, texto, tipo, completado }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Claves.self)
        let f = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        fecha = Fechas.desdeTextoFlexible(f) ?? Date()
        descripcion = try c.decodeIfPresent(String.self, forKey: .texto) ?? ""
        tipo = TipoSeguimiento(rawValue: try c.decodeIfPresent(String.self, forKey: .tipo) ?? "") ?? .otro
        completado = try c.decodeIfPresent(Bool.self, forKey: .completado) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Claves.self)
        try c.encode(Fechas.claveDia(fecha), forKey: .fecha)
        try c.encode(descripcion, forKey: .texto)
        try c.encode(tipo.rawValue, forKey: .tipo)
        try c.encode(completado, forKey: .completado)
    }
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
