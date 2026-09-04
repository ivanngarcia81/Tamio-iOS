import Foundation

/// Un aporte individual (renglón del historial).
struct Aporte: Identifiable {
    let id: String
    let concepto: String   // "Diezmo", "Misiones"
    /// Fecha real, no el texto ya formateado. Antes era un `String` como
    /// "27 ago": servía para pintarlo y para nada más — con eso no se puede
    /// saber cuánto lleva alguien sin aportar.
    let fecha: Date
    let monto: Centavos
}

/// Cada cuánto se espera que aporte una persona.
///
/// Es por persona y no una regla de la iglesia porque no todos dan igual: hay
/// quien diezma cada semana y quien lo hace al cobrar, una vez al mes.
enum FrecuenciaAporte: String, CaseIterable, Identifiable, Hashable {
    case semanal, quincenal, mensual, ocasional

    var id: String { rawValue }

    var etiqueta: String {
        switch self {
        case .semanal:   return L.t("Semanal", "Weekly")
        case .quincenal: return L.t("Quincenal", "Biweekly")
        case .mensual:   return L.t("Mensual", "Monthly")
        case .ocasional: return L.t("Ocasional", "Occasional")
        }
    }

    /// Días que dura un periodo. `nil` en "ocasional": a quien da de forma
    /// suelta no se le puede reprochar un retraso, así que no se le vigila.
    var dias: Int? {
        switch self {
        case .semanal:   return 7
        case .quincenal: return 14
        case .mensual:   return 30
        case .ocasional: return nil
        }
    }

    /// Nombre del periodo en plural, para los textos ("3 semanas sin aportar").
    func periodos(_ n: Int) -> String {
        switch self {
        case .semanal:   return L.t("\(n) semanas", "\(n) weeks")
        case .quincenal: return L.t("\(n) quincenas", "\(n) biweekly periods")
        case .mensual:   return L.t("\(n) meses", "\(n) months")
        case .ocasional: return ""
        }
    }
}

/// Un mes de la gráfica de aportes.
struct MesAporte: Identifiable {
    var id: String { mes }
    let mes: String
    let monto: Centavos
}

/// Un pariente (pestaña Familia).
struct Pariente: Identifiable {
    let id: String
    let relacion: String   // "Cónyuge", "Hijo"
    let nombre: String
}

/// Un aportante (Miembros · Tesorería): sus datos fiscales/personales y su
/// historial de aportes. Distinto de `Miembro` (Secretaría, asistencia).
struct Aportante: Identifiable, Hashable {
    var id: String   // var: Supabase asigna el UID al crear (vacío = nuevo)
    let nombre: String
    /// `var`: la bandeja reactiva a un aportante dado de baja desde su asunto
    /// "Restaurar", que antes solo apagaba el aviso sin tocar al aportante.
    var estado: EstadoMiembro
    let rol: String            // "diezmo" / "donador" — para el subtítulo de la lista
    let miembroDesde: String   // "2018"

    // Ficha. Bautismo, ministerios y cargos NO viven aquí: son del padrón, que
    // lleva Secretaría. Están en `Miembro`, sobre la misma fila de `members`.
    let telefono: String
    let correo: String
    let nacimiento: String
    let direccion: String
    let estadoCivil: String
    let idFiscal: String
    let congregaDesde: String  // "2016"
    /// Ritmo con el que se espera que aporte, para medir su constancia.
    let frecuencia: FrecuenciaAporte

    // Aportes. **Solo el historial se guarda**: el total, el promedio y la
    // gráfica se derivan de él.
    //
    // Los tres iban como campos y cada constructor los rellenaba por su
    // cuenta: el mock ponía un total distinto por persona, el MISMO texto de
    // promedio para todo el mundo y la MISMA gráfica de ocho meses. Para Ana
    // Lucía la ficha decía Total $19,600, el promedio $3,275 × 8 meses =
    // $26,200 y la constancia —que sí sumaba el historial— $23,000. Tres
    // cifras para la misma persona, dos de ellas en la misma tarjeta. Como
    // derivados no hay dónde mentir.
    let aportes: [Aporte]         // historial completo

    // Familia.
    let familia: [Pariente]


    /// Los tres aportes más recientes, para el resumen.
    var aportesRecientes: [Aporte] { Array(aportes.prefix(3)) }

    // MARK: - Aportes derivados

    /// Todo lo aportado, de siempre. Es lo que suma el pie de la lista.
    var aportesTotal: Centavos { aportes.reduce(0) { $0 + $1.monto } }

    func aportes(anio: Int) -> [Aporte] {
        aportes.filter { Calendar.current.component(.year, from: $0.fecha) == anio }
    }

    /// Lo aportado en un año: lo que encabeza la ficha y lo que certifica la
    /// constancia de ese año. Es la MISMA función para los dos.
    func total(anio: Int) -> Centavos {
        aportes(anio: anio).reduce(0) { $0 + $1.monto }
    }

    /// Los años con aporte, del más reciente al más antiguo, y siempre el año
    /// en curso: quien no ha dado nada este año también tiene ficha que mirar.
    var aniosConAportes: [Int] {
        let cal = Calendar.current
        let enCurso = cal.component(.year, from: Date())
        return Set(aportes.map { cal.component(.year, from: $0.fecha) } + [enCurso])
            .sorted(by: >)
    }

    /// "Promedio $3,275.00 en 8 meses con aporte" — sobre los meses en que de
    /// verdad aportó, no sobre doce: quien da solo en diciembre no tiene un
    /// promedio mensual de una doceava parte.
    func promedio(anio: Int) -> String {
        let delAnio = aportes(anio: anio)
        guard !delAnio.isEmpty else {
            return L.t("Sin aportes en \(anio)", "No giving in \(anio)")
        }
        let cal = Calendar.current
        let meses = Set(delAnio.map { cal.component(.month, from: $0.fecha) }).count
        let media = delAnio.reduce(0) { $0 + $1.monto } / max(1, meses)
        return L.t("Promedio \(Money.fmt(media)) en \(meses) meses con aporte",
                   "Avg \(Money.fmt(media)) over \(meses) months with giving")
    }

    /// Los doce meses del año para la gráfica. Los meses sin aporte van a cero
    /// y no desaparecen: el hueco es justo lo que se quiere ver.
    func serie(anio: Int) -> [MesAporte] {
        let cal = Calendar.current
        let delAnio = aportes(anio: anio)
        return (1...12).compactMap { mes in
            guard let fecha = cal.date(from: DateComponents(year: anio, month: mes)) else { return nil }
            let suma = delAnio
                .filter { cal.component(.month, from: $0.fecha) == mes }
                .reduce(0) { $0 + $1.monto }
            return MesAporte(mes: L.mesCorto(fecha), monto: suma)
        }
    }

    // MARK: - Constancia
    //
    // El equivalente en Tesorería de lo que la asistencia es en Secretaría: a
    // la secretaria le importa quién lleva tres domingos sin venir; al tesorero,
    // quién diezma cada semana y lleva tres semanas sin hacerlo. Un aportante
    // constante que desaparece es o alguien que se alejó, o un cobro
    // traspapelado: las dos cosas se quieren ver.

    /// A la tercera falta se avisa.
    static let periodosParaAvisar = 3

    var ultimoAporte: Date? { aportes.map(\.fecha).max() }

    /// Periodos completos transcurridos desde el último aporte. `nil` cuando no
    /// hay ritmo que vigilar (ocasional) o cuando la persona no ha aportado
    /// nunca, que no es un retraso sino otra cosa.
    var periodosSinAportar: Int? {
        guard let dias = frecuencia.dias, let ultimo = ultimoAporte else { return nil }
        let transcurridos = Calendar.current.dateComponents([.day], from: ultimo, to: Date()).day ?? 0
        return max(0, transcurridos / dias)
    }

    var atrasadoEnAportes: Bool {
        (periodosSinAportar ?? 0) >= Self.periodosParaAvisar
    }

    /// En cuántos de los últimos periodos hubo aporte. Da contexto al retraso:
    /// no es lo mismo fallar tres veces tras un año perfecto que fallar siempre.
    func constanciaReciente(periodos: Int = 6) -> (conAporte: Int, total: Int)? {
        guard let dias = frecuencia.dias else { return nil }
        let cal = Calendar.current
        let hoy = Date()
        var cumplidos = 0
        for i in 0..<periodos {
            guard let fin = cal.date(byAdding: .day, value: -dias * i, to: hoy),
                  let inicio = cal.date(byAdding: .day, value: -dias, to: fin) else { continue }
            if aportes.contains(where: { $0.fecha > inicio && $0.fecha <= fin }) { cumplidos += 1 }
        }
        return (cumplidos, periodos)
    }

    /// Subtítulo de la fila: "Miembro desde 2018 · diezmo".
    var subtitulo: String {
        L.t("Miembro desde \(miembroDesde) · \(rol)", "Member since \(miembroDesde) · \(rol)")
    }

    var iniciales: String {
        let ini = nombre.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
        return ini.uppercased()
    }

    static func == (l: Aportante, r: Aportante) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
