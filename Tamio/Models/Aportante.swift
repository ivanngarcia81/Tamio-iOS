import Foundation

/// Un aporte individual (renglón del historial).
struct Aporte: Identifiable {
    let id: String
    let concepto: String   // "Diezmo", "Misiones"
    let fecha: String      // "27 ago"
    let monto: Centavos
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
    let estado: EstadoMiembro
    let rol: String            // "diezmo" / "donador" — para el subtítulo de la lista
    let miembroDesde: String   // "2018"

    // Ficha.
    let bautizadoAnio: String  // "Bautizado 2018"
    let ministerios: String    // "Música · Medios"
    let cargos: String         // "Diácono"
    let telefono: String
    let correo: String
    let nacimiento: String
    let direccion: String
    let estadoCivil: String
    let idFiscal: String
    let congregaDesde: String  // "2016"
    let bautismo: String       // "9 dic 2018"

    // Aportes.
    let aportesTotal: Centavos
    let aportesPromedio: String   // "Promedio $3,275.00 en 8 meses con aporte"
    let aportesSerie: [MesAporte]
    let aportes: [Aporte]         // historial completo

    // Familia.
    let familia: [Pariente]

    // Asistencia.
    let serviciosRegistrados: Int
    let presencias: String        // "30 · 88%"
    let ultimaVisita: String      // "23 ago 2026"

    /// Los tres aportes más recientes, para el resumen.
    var aportesRecientes: [Aporte] { Array(aportes.prefix(3)) }

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
