import Foundation

/// Área de la iglesia a la que pertenece un apunte del registro.
enum ApunteArea: String {
    case tesoreria, secretaria
    /// Lo que ve todo el mundo. Existe en el web desde el principio —el `area`
    /// decide quién lo ve— y aquí faltaba, así que una nota no tenía dónde
    /// caer y se guardaba como si fuera de secretaría.
    case general

    var etiqueta: String {
        switch self {
        case .tesoreria:  return L.t("Tesorería", "Treasury")
        case .secretaria: return L.t("Secretaría", "Secretary")
        case .general:    return L.t("General", "General")
        }
    }

    init(clave: String) { self = ApunteArea(rawValue: clave) ?? .general }
}

/// **Qué se registra.** Las claves son las del web (`SUCESOS` en `src/db.ts`):
/// lo que viaja a la base es la clave, y el TEXTO se compone al leer.
///
/// Esa es la razón de ser de esta tabla. El web la escribió para sustituir a
/// `mensajes`, que guardaba la frase ya armada y "por eso se quedaba congelada
/// en un idioma"; el iOS estaba repitiendo el mismo error, con el `texto` ya
/// escrito dentro del apunte. Un registro anotado en español ahora se lee en
/// inglés si quien mira tiene la app en inglés.
enum TipoSuceso: String, CaseIterable {
    // Tesorería
    case movEliminado, corteEntregado, corteDepositado, segundaFirma, descuadre
    // Secretaría
    case estadoMiembro, bajaMiembro, cartaEmitida, actaCerrada
    // De la casa: el único que escribe una persona, y el único que usa `cuerpo`.
    case nota

    /// El área decide quién lo ve, y va aquí —no en cada sitio que registra—
    /// para que la respuesta a "¿quién ve esto?" esté en un solo lugar.
    var area: ApunteArea {
        switch self {
        case .movEliminado, .corteEntregado, .corteDepositado, .segundaFirma, .descuadre:
            return .tesoreria
        case .estadoMiembro, .bajaMiembro, .cartaEmitida, .actaCerrada:
            return .secretaria
        case .nota:
            return .general
        }
    }

    /// **Lo que no cuadró.** Los dos que piden que alguien mire: un descuadre
    /// y una baja de movimiento, que es "el único que hace desaparecer dinero
    /// de las cuentas", como lo dice el web.
    var esAlerta: Bool { self == .descuadre || self == .movEliminado }

    init(clave: String) { self = TipoSuceso(rawValue: clave) ?? .nota }
}

/// Filtros de la barra superior del Registro.
enum FiltroRegistro: String, CaseIterable, Identifiable {
    case todo, tesoreria, secretaria, notas
    var id: String { rawValue }
    var etiqueta: String {
        switch self {
        case .todo: return L.t("Todo", "All")
        case .tesoreria: return L.t("Tesorería", "Treasury")
        case .secretaria: return L.t("Secretaría", "Secretary")
        case .notas: return L.t("Notas", "Notes")
        }
    }
}

/// Un apunte del registro: una línea de lo que pasó en la iglesia.
///
/// **Guarda las piezas, no la frase.** Tenía `texto`, `hora`, `grupo` y
/// `fecha` escritos: cuatro cadenas ya redactadas, en el idioma de quien las
/// escribió y con "HOY" congelado en el día que se guardaron —al día siguiente
/// el apunte seguía diciendo HOY—. Ahora lleva el `tipo`, los `datos` que lo
/// rellenan y el instante, y las cuatro se componen al leer.
///
/// El registro sigue guardando copias y no referencias: el `folio` y el nombre
/// de quien hizo la cosa van dentro de `datos` como instantánea, porque si esa
/// persona se da de baja el registro tiene que seguir diciendo quién fue.
struct Apunte: Identifiable, Hashable {
    let id: String
    let tipo: TipoSuceso
    /// Las piezas del texto: `["nombre": "María", "de": "activo"]`. Vacío en
    /// las notas, que traen su `cuerpo`.
    let datos: [String: String]
    /// Solo las notas. Lo automático lo compone `tipo` + `datos`.
    let cuerpo: String
    /// Quién lo hizo, como instantánea del nombre.
    let autor: String
    /// El instante, ISO 8601. Antes eran `hora` y `grupo` ya escritos.
    let creadoEn: Date

    /// **Quién lo ve.** Lo automático lo decide su `tipo` —la respuesta a
    /// "¿quién ve esto?" en un solo sitio, como en el web—, pero en las notas
    /// lo elige quien escribe: la hoja de nota ofrece Tesorería o Secretaría y
    /// esa decisión es suya, no del tipo. Por eso se guarda y solo se deriva
    /// cuando no se dice.
    let area: ApunteArea

    var esNota: Bool { tipo == .nota }
    var esAlerta: Bool { tipo.esAlerta }

    /// El folio congelado, si el suceso lo tiene.
    var folio: String? { datos["folio"] }

    /// **La frase, compuesta al leer.** Un registro anotado en español se lee
    /// en inglés si quien mira tiene la app en inglés, que es justo lo que el
    /// web arregló al retirar `mensajes`.
    var texto: String {
        if tipo == .nota { return cuerpo }
        func d(_ k: String) -> String { datos[k] ?? "—" }
        switch tipo {
        case .movEliminado:
            return L.t("Se dio de baja el movimiento \(d("folio")) de \(d("monto"))",
                       "Entry \(d("folio")) of \(d("monto")) was removed")
        case .corteEntregado:
            return L.t("Salió de la caja el corte «\(d("corte"))», con \(d("movimientos")) movimiento(s)",
                       "The «\(d("corte"))» cut left the cash box, with \(d("movimientos")) entries")
        case .corteDepositado:
            return L.t("El corte «\(d("corte"))» llegó al banco",
                       "The «\(d("corte"))» cut reached the bank")
        case .segundaFirma:
            return L.t("\(d("quien")) dio la segunda firma del corte «\(d("corte"))»",
                       "\(d("quien")) gave the second signature of the «\(d("corte"))» cut")
        case .descuadre:
            return L.t("El corte «\(d("corte"))» NO cuadró: se contaron \(d("contado")) y no coincide con lo registrado",
                       "The «\(d("corte"))» cut did NOT match: \(d("contado")) counted, which differs from what was recorded")
        case .estadoMiembro:
            return L.t("\(d("nombre")) pasó de \(d("de")) a \(d("a"))",
                       "\(d("nombre")) went from \(d("de")) to \(d("a"))")
        case .bajaMiembro:
            return L.t("\(d("nombre")) se dio de baja del padrón: \(d("motivo"))",
                       "\(d("nombre")) was removed from the roster: \(d("motivo"))")
        case .cartaEmitida:
            return L.t("Se emitió la carta \(d("folio")) a \(d("nombre"))",
                       "Letter \(d("folio")) issued to \(d("nombre"))")
        case .actaCerrada:
            return L.t("Se cerró el acta \(d("folio"))", "Minutes \(d("folio")) were closed")
        case .nota:
            return cuerpo
        }
    }

    var hora: String {
        let f = L.formateador("HH:mm")
        return f.string(from: creadoEn)
    }

    /// `"HOY"` · `"AYER"` · `"22 AGO 2026"`. **Se calcula contra hoy**: iba
    /// escrito, así que un apunte guardado ayer seguía diciendo HOY para
    /// siempre.
    var grupo: String {
        let cal = Calendar.current
        if cal.isDateInToday(creadoEn)     { return L.t("HOY", "TODAY") }
        if cal.isDateInYesterday(creadoEn) { return L.t("AYER", "YESTERDAY") }
        return L.formateador(L.t("d MMM yyyy", "MMM d, yyyy"))
            .string(from: creadoEn).uppercased()
    }

    /// `"Hoy · 30 de agosto"`, para el detalle.
    var fecha: String {
        let dia = L.formateador(L.t("d 'de' MMMM", "MMMM d")).string(from: creadoEn)
        let cal = Calendar.current
        if cal.isDateInToday(creadoEn)     { return L.t("Hoy · \(dia)", "Today · \(dia)") }
        if cal.isDateInYesterday(creadoEn) { return L.t("Ayer · \(dia)", "Yesterday · \(dia)") }
        return dia
    }

    init(id: String, tipo: TipoSuceso, datos: [String: String] = [:],
         cuerpo: String = "", autor: String, creadoEn: Date,
         area: ApunteArea? = nil) {
        self.id = id; self.tipo = tipo; self.datos = datos; self.cuerpo = cuerpo
        self.autor = autor; self.creadoEn = creadoEn
        self.area = area ?? tipo.area
    }

    static func == (l: Apunte, r: Apunte) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
