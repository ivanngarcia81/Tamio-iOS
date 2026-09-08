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

    /// **Lo que la app necesita, y por qué nombres suele venir.** Se enseña en
    /// el paso de mapeo, en este orden. Los alias son los encabezados que se
    /// reconocen solos —van sin acentos, que `CSVLector.normalizar` los quita
    /// de los dos lados— para que un archivo exportado por Tamio, o uno con
    /// nombres razonables en español o inglés, no haya que mapearlo a mano.
    static var campos: [CSVLector.Campo] {
        [.init("nombre", L.t("Nombre", "Name"), obligatorio: true,
               alias: ["name", "nombre_completo", "full_name", "aportante", "miembro", "member"]),
         .init("id", L.t("Identificador", "Identifier"), alias: ["uid", "codigo", "code"]),
         .init("id_fiscal", L.t("Identificación fiscal", "Tax ID"),
               alias: ["rfc", "tax_id", "ein", "idfiscal"]),
         .init("estado", L.t("Estado", "Status"), alias: ["status", "situacion"]),
         .init("rol", L.t("Tipo de aporte", "Gift type"), alias: ["tipo", "type"]),
         .init("telefono", L.t("Teléfono", "Phone"), alias: ["phone", "tel", "celular", "movil", "numero", "numero_de_telefono"]),
         .init("correo", L.t("Correo", "Email"), alias: ["email", "e_mail", "mail"]),
         .init("direccion", L.t("Domicilio", "Address"), alias: ["address", "domicilio", "direccion_completa", "calle"]),
         .init("nacimiento", L.t("Nacimiento", "Birth date"),
               alias: ["birth_date", "fecha_nacimiento", "fecha_de_nacimiento", "cumpleanos", "cumpleaños"]),
         .init("estado_civil", L.t("Estado civil", "Marital status"), alias: ["marital_status"]),
         .init("miembro_desde", L.t("Miembro desde", "Member since"),
               alias: ["member_since", "fecha_ingreso", "fecha_de_ingreso", "ingreso", "fecha_de_alta", "alta"]),
         .init("congrega_desde", L.t("Congrega desde", "Attending since"),
               alias: ["fecha_congregacion", "fecha_de_congregacion", "attending_since", "congrega"]),
         .init("frecuencia_aporte", L.t("Frecuencia", "Frequency"),
               alias: ["frecuencia", "frequency"])]
    }

    /// **Recibe el documento ya mapeado, no el archivo.** Antes leía el URL y
    /// exigía que las cabeceras fueran las claves exactas; ahora quien llama
    /// pasa por `MapearColumnasView` primero, y lo que llega aquí ya trae las
    /// claves de la app. `columnasFaltantes` se queda como red de seguridad:
    /// con el mapeo delante no debería llenarse nunca.
    static func analizar(_ doc: CSVLector.Documento, existentes: [Aportante]) throws -> Analisis {
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

    /// Las claves del modelo, más lo que esta app escribía antes en sus
    /// archivos: "nuevo" y "recibido" eran personas activas con una etiqueta
    /// de más, y "traslado" era un traslado en curso, que tampoco es una
    /// baja. Un archivo viejo no puede dar de baja a nadie por accidente.
    private static func estado(_ texto: String, _ porDefecto: EstadoMiembro) -> EstadoMiembro {
        switch texto.lowercased() {
        case "active":                        return .activo
        case "removed":                       return .baja("", "")
        case "nuevo", "new", "recibido", "received",
             "traslado", "transfer":          return .activo
        default: return EstadoMiembro.desde(clave: texto) ?? porDefecto
        }
    }
}
