import Foundation

/// Analiza un CSV de aportantes y dice **qué pasaría** antes de tocar nada.
///
/// La importación es la única función de la app que puede estropear datos en
/// masa: todo lo demás toca un registro cada vez. Por eso va en dos tiempos —
/// primero se analiza y se enseña el resumen, y solo si el usuario confirma se
/// aplica.
enum ImportadorAportantes {

    /// Qué se hará con una fila del archivo.
    enum Destino {
        case nuevo
        /// Ya existe alguien con ese id o identificación fiscal.
        case actualiza(String)
        case error(String)
    }

    struct FilaAnalizada: Identifiable {
        let id = UUID()
        /// Número de línea en el archivo, contando el encabezado, para que el
        /// usuario pueda ir a arreglarla.
        let linea: Int
        let nombre: String
        let destino: Destino
        let aportante: Aportante?
    }

    struct Analisis: Identifiable {
        let id = UUID()
        let filas: [FilaAnalizada]
        /// Columnas del formato que el archivo no trae.
        let columnasFaltantes: [String]

        var nuevos: Int { filas.filter { if case .nuevo = $0.destino { return true }; return false }.count }
        var actualizados: Int { filas.filter { if case .actualiza = $0.destino { return true }; return false }.count }
        var errores: [FilaAnalizada] { filas.filter { if case .error = $0.destino { return true }; return false } }
        var aplicables: Int { nuevos + actualizados }
    }

    /// Solo el nombre es imprescindible: sin él no hay a quién apuntar el
    /// aporte. Lo demás puede completarse después desde la ficha.
    private static let obligatorias = ["nombre"]

    static func analizar(_ url: URL, existentes: [Aportante]) throws -> Analisis {
        let doc = try CSVLector.leer(url)
        let faltantes = obligatorias.filter { !doc.encabezados.contains($0) }
        guard faltantes.isEmpty else {
            return Analisis(filas: [], columnasFaltantes: faltantes)
        }

        // Índices para no recorrer la lista entera en cada fila.
        let porId = Dictionary(existentes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let porFiscal = Dictionary(
            existentes.filter { !$0.idFiscal.isEmpty }.map { ($0.idFiscal.uppercased(), $0) },
            uniquingKeysWith: { a, _ in a })
        let porNombre = Dictionary(
            existentes.map { ($0.nombre.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

        var analizadas: [FilaAnalizada] = []
        // Nombres ya vistos EN EL PROPIO ARCHIVO: un CSV puede traer la misma
        // persona dos veces, y sin esto se crearía por duplicado.
        var vistosEnArchivo = Set<String>()

        for (i, fila) in doc.filas.enumerated() {
            let linea = i + 2   // +1 por el encabezado, +1 porque se cuenta desde 1
            let nombre = doc.valor(fila, "nombre")

            guard !nombre.isEmpty else {
                analizadas.append(FilaAnalizada(
                    linea: linea, nombre: "—",
                    destino: .error(L.t("Sin nombre", "Missing name")),
                    aportante: nil))
                continue
            }

            let clave = nombre.lowercased()
            if vistosEnArchivo.contains(clave) {
                analizadas.append(FilaAnalizada(
                    linea: linea, nombre: nombre,
                    destino: .error(L.t("Repetido en el archivo", "Duplicated in the file")),
                    aportante: nil))
                continue
            }
            vistosEnArchivo.insert(clave)

            let idArchivo = doc.valor(fila, "id")
            let fiscal = doc.valor(fila, "id_fiscal").uppercased()
            let existente = porId[idArchivo] ?? porFiscal[fiscal] ?? porNombre[clave]

            let a = construir(doc: doc, fila: fila, nombre: nombre, existente: existente)
            analizadas.append(FilaAnalizada(
                linea: linea, nombre: nombre,
                destino: existente == nil ? .nuevo : .actualiza(existente!.nombre),
                aportante: a))
        }

        return Analisis(filas: analizadas, columnasFaltantes: [])
    }

    private static func construir(doc: CSVLector.Documento, fila: [String],
                                  nombre: String, existente: Aportante?) -> Aportante {
        func v(_ col: String, _ porDefecto: String = "") -> String {
            let valor = doc.valor(fila, col)
            return valor.isEmpty ? porDefecto : valor
        }
        let frecuencia = FrecuenciaAporte(rawValue: v("frecuencia_aporte").lowercased())
            ?? existente?.frecuencia ?? .ocasional

        return Aportante(
            // Se conserva el id del existente: importar sobre alguien que ya
            // está no puede crear un segundo registro suyo.
            id: existente?.id ?? "",
            nombre: nombre,
            estado: estado(v("estado"), existente?.estado ?? .activo),
            rol: v("rol", existente?.rol ?? L.t("diezmo", "tithe")),
            miembroDesde: v("miembro_desde", existente?.miembroDesde ?? ""),
            telefono: v("telefono", existente?.telefono ?? ""),
            correo: v("correo", existente?.correo ?? ""),
            nacimiento: v("nacimiento", existente?.nacimiento ?? ""),
            direccion: v("direccion", existente?.direccion ?? ""),
            estadoCivil: v("estado_civil", existente?.estadoCivil ?? ""),
            idFiscal: v("id_fiscal", existente?.idFiscal ?? ""),
            congregaDesde: v("congrega_desde", existente?.congregaDesde ?? ""),
            frecuencia: frecuencia,
            // El historial no se toca desde este archivo: viene en el suyo.
            aportes: existente?.aportes ?? [],
            familia: existente?.familia ?? []
        )
    }

    private static func estado(_ texto: String, _ porDefecto: EstadoMiembro) -> EstadoMiembro {
        switch texto.lowercased() {
        case "activo", "active":     return .activo
        case "nuevo", "new":         return .nuevo
        case "traslado", "transfer": return .traslado
        case "baja", "removed":      return .baja
        case "recibido", "received": return .recibido
        default:                     return porDefecto
        }
    }
}
