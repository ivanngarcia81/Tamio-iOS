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
    /// Las tres columnas del estado, como en `members`: `estado` es
    /// `estado_membresia` y solo significa algo mientras `activo`; la baja
    /// son `activo = 0` más fecha y motivo. Llegaron con la v15 — antes la
    /// fila solo tenía `estado`, y una baja se escribía ahí como la palabra
    /// "baja", que el servidor no lee.
    var activo: Bool
    var fechaBaja: String
    var motivoBaja: String
    var actualizadoEn: String?
    var borrado: Bool

    init(_ a: Aportante, actualizadoEn: String? = nil, borrado: Bool = false) {
        id = a.id
        nombre = a.nombre
        estado = a.estado.registro.rawValue
        telefono = a.telefono
        correo = a.correo
        nacimiento = a.nacimiento
        direccion = a.direccion
        estadoCivil = a.estadoCivil
        idFiscal = a.idFiscal
        miembroDesde = a.miembroDesde
        congregaDesde = a.congregaDesde
        frecuencia = a.frecuencia.rawValue
        activo = !a.estado.esBaja
        fechaBaja = a.estado.baja?.fecha ?? ""
        motivoBaja = a.estado.baja?.motivo ?? ""
        self.actualizadoEn = actualizadoEn
        self.borrado = borrado
    }

    /// Se le pasan los aportes ya calculados desde los movimientos, en vez de
    /// que la fila los invente.
    func aportante(aportes: [Aporte]) -> Aportante {
        Aportante(
            id: id,
            nombre: nombre,
            estado: Self.estado(registro: estado, activo: activo,
                                fechaBaja: fechaBaja, motivoBaja: motivoBaja),
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

    /// De las tres columnas al estado. El mismo camino sirve para la fila
    /// local y para la que baja de Supabase, que traen las mismas tres.
    ///
    /// Un `registro` que no esté en el catálogo —los "baja", "traslado",
    /// "nuevo" y "recibido" que esta app escribía antes— se lee como activo:
    /// la v15 ya los normaliza en la base local, y del servidor solo llegan
    /// los del web.
    static func estado(registro: String, activo: Bool,
                       fechaBaja: String, motivoBaja: String) -> EstadoMiembro {
        let r = EstadoRegistro(rawValue: registro) ?? .activo
        return EstadoMiembro(registro: r,
                             baja: activo ? nil : Baja(fecha: fechaBaja, motivo: motivoBaja))
    }
}

// MARK: - La otra vista de la misma fila: el padrón

/// **El padrón, sobre la misma fila de `aportante`.**
///
/// `AportanteFila` y `MiembroFila` son dos records de GRDB sobre UNA tabla:
/// cada uno codifica sus columnas y nada más, y como `update` escribe solo
/// las columnas que el record codifica, Tesorería y Secretaría pueden guardar
/// la misma persona sin pisarse. Aquí no está `frecuencia` (es de Tesorería)
/// y en `AportanteFila` no están los bautismos ni los ministerios. Lo que
/// comparten —nombre, contacto, estado, fechas— lo escriben los dos, y es lo
/// que se quiere: un teléfono corregido en Aportantes tiene que verse en
/// Membresía.
///
/// Las listas y el historial van como texto con JSON dentro, igual que en
/// `members`. La traducción a `[String]` y `[CambioEstado]` es de aquí para
/// dentro; la columna es el espejo.
struct MiembroFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "aportante"

    var id: String
    var nombre: String
    var estado: String
    var activo: Bool
    var fechaBaja: String
    var motivoBaja: String
    var telefono: String
    var correo: String
    var nacimiento: String
    var direccion: String
    var estadoCivil: String
    var idFiscal: String
    var miembroDesde: String      // fecha_ingreso
    var congregaDesde: String     // fecha_congregacion
    var iglesiaAnterior: String
    var bautizadoAgua: Bool
    var fechaBautismoAgua: String
    var bautizadoEspiritu: Bool
    var fechaBautismoEspiritu: String
    var cursoMembresia: Bool
    var ministerios: String
    var ministeriosInteres: String
    var cargos: String
    var instrumentos: String
    var habilidades: String
    var etiquetas: String
    var disponibilidad: String
    var interesServir: Bool
    var notas: String
    var historialEstados: String
    var seguimientoNotas: String
    var seguimientoRevisadoEn: String
    var actualizadoEn: String?
    var borrado: Bool

    init(_ m: Miembro, actualizadoEn: String? = nil, borrado: Bool = false) {
        id = m.id
        nombre = m.nombre
        estado = m.estado.registro.rawValue
        activo = !m.estado.esBaja
        fechaBaja = m.estado.baja?.fecha ?? ""
        motivoBaja = m.estado.baja?.motivo ?? ""
        telefono = m.telefono
        correo = m.correo
        nacimiento = m.nacimiento
        direccion = m.direccion
        estadoCivil = m.estadoCivil
        idFiscal = m.idFiscal
        miembroDesde = m.fechaIngreso
        congregaDesde = m.fechaCongregacion
        iglesiaAnterior = m.iglesiaAnterior
        bautizadoAgua = m.bautizadoAgua
        fechaBautismoAgua = m.fechaBautismoAgua
        bautizadoEspiritu = m.bautizadoEspiritu
        fechaBautismoEspiritu = m.fechaBautismoEspiritu
        cursoMembresia = m.cursoMembresia
        ministerios = Padron.json(m.ministerios)
        ministeriosInteres = Padron.json(m.ministeriosInteres)
        cargos = Padron.json(m.cargos)
        instrumentos = Padron.json(m.instrumentos)
        habilidades = Padron.json(m.habilidades)
        etiquetas = Padron.json(m.etiquetas)
        disponibilidad = m.disponibilidad
        interesServir = m.interesServir
        notas = m.notas
        historialEstados = Self.json(m.historialEstados)
        seguimientoNotas = Self.json(m.seguimientoNotas)
        seguimientoRevisadoEn = m.seguimientoRevisadoEn
        self.actualizadoEn = actualizadoEn
        self.borrado = borrado
    }

    /// Se le pasan los parentescos ya resueltos —vienen de otra tabla y con
    /// el nombre del otro— en vez de que la fila los invente.
    func miembro(familia: [Pariente]) -> Miembro {
        var m = Miembro(id: id, nombre: nombre)
        m.estado = AportanteFila.estado(registro: estado, activo: activo,
                                        fechaBaja: fechaBaja, motivoBaja: motivoBaja)
        m.telefono = telefono
        m.correo = correo
        m.nacimiento = nacimiento
        m.direccion = direccion
        m.estadoCivil = estadoCivil
        m.idFiscal = idFiscal
        m.fechaIngreso = miembroDesde
        m.fechaCongregacion = congregaDesde
        m.iglesiaAnterior = iglesiaAnterior
        m.bautizadoAgua = bautizadoAgua
        m.fechaBautismoAgua = fechaBautismoAgua
        m.bautizadoEspiritu = bautizadoEspiritu
        m.fechaBautismoEspiritu = fechaBautismoEspiritu
        m.cursoMembresia = cursoMembresia
        m.ministerios = Padron.lista(ministerios)
        m.ministeriosInteres = Padron.lista(ministeriosInteres)
        m.cargos = Padron.lista(cargos)
        m.instrumentos = Padron.lista(instrumentos)
        m.habilidades = Padron.lista(habilidades)
        m.etiquetas = Padron.lista(etiquetas)
        m.disponibilidad = disponibilidad
        m.interesServir = interesServir
        m.notas = notas
        m.historialEstados = Self.lista(historialEstados)
        m.seguimientoNotas = Self.lista(seguimientoNotas)
        m.seguimientoRevisadoEn = seguimientoRevisadoEn
        m.familia = familia
        return m
    }

    // MARK: JSON

    /// Con la misma tolerancia que `Padron.lista`: un JSON que no se entienda
    /// es una lista vacía, no una ficha que no abre.
    static func lista<T: Decodable>(_ json: String) -> [T] {
        guard let datos = json.data(using: .utf8),
              let v = try? JSONDecoder().decode([T].self, from: datos) else { return [] }
        return v
    }

    static func json<T: Encodable>(_ lista: [T]) -> String {
        guard let datos = try? JSONEncoder().encode(lista),
              let s = String(data: datos, encoding: .utf8) else { return "[]" }
        return s
    }
}

/// Un parentesco tal y como vive en SQLite. Espejo de `parentescos`: dos
/// personas del padrón y qué es la segunda de la primera. Se guarda UNA fila
/// por relación; la ficha del otro la lee con el inverso.
struct ParentescoFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "parentesco"

    var id: String
    var miembroId: String
    var parienteId: String
    var tipo: String
    var actualizadoEn: String?
    var borrado: Bool
}

// MARK: - La asistencia

/// Un culto tal y como vive en SQLite. Espejo de `servicios`.
struct ServicioFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "servicio"

    var id: String
    var fecha: String
    var tipo: String
    var dirige: String
    var predica: String
    var tituloMensaje: String
    var textoBiblico: String
    var resumenMensaje: String
    var participaciones: String
    var temaEscuela: String
    var maestroEscuela: String
    var visitantes: String
    var ninos: Int
    var jovenes: Int
    var adultos: Int
    var eventos: String
    var actualizadoEn: String?
    var borrado: Bool
}

/// Quién vino a un culto. Una fila por persona, aunque la lista se tome por
/// familia. Espejo de `servicio_asistencia`.
struct AsistenciaFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "servicioAsistencia"

    var id: String
    var servicioId: String
    var miembroId: String
    var presente: Bool
    var razon: String
    var razonOtra: String
    var seguimiento: Bool
    var nombreSnapshot: String
    var actualizadoEn: String?
    var borrado: Bool

    /// Las razones del web, en su orden. Solo significan algo con `presente`
    /// en falso: al marcar presente se limpian, como allí.
    static let razones = ["justificada", "enfermedad", "trabajo", "viaje",
                          "emergencia", "desconocida", "otra"]

    static func etiquetaRazon(_ r: String) -> String {
        switch r {
        case "justificada": return L.t("Justificada", "Excused")
        case "enfermedad":  return L.t("Enfermedad", "Illness")
        case "trabajo":     return L.t("Trabajo", "Work")
        case "viaje":       return L.t("Viaje", "Travel")
        case "emergencia":  return L.t("Emergencia", "Emergency")
        case "desconocida": return L.t("No se sabe", "Unknown")
        case "otra":        return L.t("Otra", "Other")
        default:            return r
        }
    }
}

/// Quién hace qué en un culto. Espejo de `servicio_puestos`.
struct ServicioPuestoFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "servicioPuesto"
    var id: String
    var servicioId: String
    var puesto: String
    var nombre: String
    var miembroId: String?
    var actualizadoEn: String?
    var borrado: Bool
}

/// Un punto del orden del culto. Espejo de `servicio_orden`.
struct ServicioOrdenFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "servicioOrden"
    var id: String
    var servicioId: String
    var posicion: Int
    var hora: String
    var titulo: String
    var encargado: String
    var actualizadoEn: String?
    var borrado: Bool
}
