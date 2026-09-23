import Foundation

/// Analiza un CSV de aportes y dice qué pasaría antes de tocar nada, igual que
/// el de aportantes.
///
/// Este es más delicado: son cifras de dinero con fecha. Un aporte mal
/// importado descuadra un total anual y acaba en una constancia fiscal.
enum ImportadorAportes {

    enum Destino {
        case nuevo(aportanteId: String)
        /// Ese mismo aporte ya está registrado.
        case duplicado
        case error(String)
    }

    struct FilaAnalizada: Identifiable {
        let id = UUID()
        let linea: Int
        let aportante: String
        let fecha: String
        let concepto: String
        let monto: String
        let destino: Destino
        let aporte: Aporte?
    }

    struct Analisis: Identifiable {
        let id = UUID()
        let filas: [FilaAnalizada]
        let columnasFaltantes: [String]

        var nuevos: Int { filas.filter { if case .nuevo = $0.destino { return true }; return false }.count }
        var duplicados: Int { filas.filter { if case .duplicado = $0.destino { return true }; return false }.count }
        var errores: [FilaAnalizada] { filas.filter { if case .error = $0.destino { return true }; return false } }

        /// Aportes a añadir, agrupados por la persona a la que pertenecen.
        var porAportante: [String: [Aporte]] {
            var mapa: [String: [Aporte]] = [:]
            for f in filas {
                if case .nuevo(let id) = f.destino, let ap = f.aporte {
                    mapa[id, default: []].append(ap)
                }
            }
            return mapa
        }

        var aplicables: Int { nuevos }
    }

    private static let obligatorias = ["fecha", "monto"]

    /// Lo que la app necesita de un archivo de aportes. Ver
    /// `ImportadorAportantes.campos` para el porqué de los alias.
    ///
    /// **A quién se le apunta el aporte puede venir por nombre o por id**, y
    /// ninguno de los dos es obligatorio por separado: un diezmo de alguien sin
    /// ficha se registra igual, con el nombre suelto. Obligatorios solo la
    /// fecha y el importe, que sin ellos no hay aporte.
    static var campos: [CSVLector.Campo] {
        [.init("fecha", L.t("Fecha", "Date"), obligatorio: true,
               alias: ["date", "dia", "day", "fecha_del_aporte", "fecha_de_pago"]),
         .init("monto", L.t("Importe", "Amount"), obligatorio: true,
               alias: ["amount", "importe", "cantidad", "valor", "total", "monto_del_aporte"]),
         // Rótulos del handoff «Trae tus datos», y también como alias: son
         // los encabezados de la plantilla que se descarga.
         .init("aportante_nombre", L.t("Aportante (nombre)", "Contributor (name)"),
               alias: ["nombre", "name", "giver", "miembro", "member", "donante",
                       "aportante", "contributor", "contributor_name"]),
         .init("aportante_id", L.t("Id del aportante", "Contributor id"),
               alias: ["member_uid", "uid", "id", "id_del_aportante", "contributor_id"]),
         .init("concepto", L.t("Concepto", "Concept"),
               alias: ["description", "descripcion", "detalle", "memo", "nota", "concept"])]
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

        let porId = Dictionary(existentes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let porNombre = Dictionary(existentes.map { ($0.nombre.lowercased(), $0) },
                                   uniquingKeysWith: { a, _ in a })

        // Huella de lo que ya está registrado, para no volver a meterlo si se
        // importa el mismo archivo dos veces.
        var yaRegistrados = Set<String>()
        for a in existentes {
            for ap in a.aportes { yaRegistrados.insert(huella(a.id, ap.fecha, ap.concepto, ap.monto)) }
        }

        var analizadas: [FilaAnalizada] = []

        for (i, fila) in doc.filas.enumerated() {
            let linea = i + 2
            let nombre = doc.valor(fila, "aportante_nombre")
            let idArchivo = doc.valor(fila, "aportante_id")
            let textoFecha = doc.valor(fila, "fecha")
            let textoMonto = doc.valor(fila, "monto")
            let concepto = doc.valor(fila, "concepto")
            let conceptoFinal = concepto.isEmpty ? L.t("Aporte", "Gift") : concepto

            func fallo(_ motivo: String) -> FilaAnalizada {
                FilaAnalizada(linea: linea, aportante: nombre.isEmpty ? idArchivo : nombre,
                              fecha: textoFecha, concepto: conceptoFinal, monto: textoMonto,
                              destino: .error(motivo), aporte: nil)
            }

            guard let persona = porId[idArchivo] ?? porNombre[nombre.lowercased()] else {
                analizadas.append(fallo(L.t("No hay ningún aportante con ese nombre",
                                            "No contributor with that name")))
                continue
            }
            // **`diaDeCalendario`**: lo que viene del archivo es un DÍA, y
            // las dos cosas que se hacen con él formatean en local —la previa
            // con `Fechas.corta` y la huella con `CSV.fecha`—. Parseado en UTC,
            // un aporte del 27 se enseñaba como 26 y su huella se calculaba
            // sobre el 26, así que no casaba con la del mismo aporte ya
            // guardado y el duplicado se colaba.
            guard let fecha = Fechas.diaDeCalendario(textoFecha) else {
                analizadas.append(fallo(L.t("Fecha no válida", "Invalid date")))
                continue
            }
            guard let centavos = Money.desdeTexto(textoMonto), centavos > 0 else {
                analizadas.append(fallo(L.t("Importe no válido", "Invalid amount")))
                continue
            }

            let marca = huella(persona.id, fecha, conceptoFinal, centavos)
            let destino: Destino = yaRegistrados.contains(marca)
                ? .duplicado
                : .nuevo(aportanteId: persona.id)
            if case .nuevo = destino { yaRegistrados.insert(marca) }

            analizadas.append(FilaAnalizada(
                linea: linea, aportante: persona.nombre,
                fecha: Fechas.corta(fecha), concepto: conceptoFinal,
                monto: Money.fmt(centavos), destino: destino,
                aporte: Aporte(id: UUID().uuidString, concepto: conceptoFinal,
                               fecha: fecha, monto: centavos)))
        }

        return Analisis(filas: analizadas, columnasFaltantes: [])
    }

    /// Dos aportes de la misma persona, el mismo día, por el mismo concepto y
    /// el mismo importe se consideran el mismo. Puede haber un falso positivo
    /// —alguien que da dos veces lo mismo el mismo día— pero omitir de más es
    /// preferible a duplicar cifras de dinero.
    private static func huella(_ id: String, _ fecha: Date, _ concepto: String, _ monto: Centavos) -> String {
        // El concepto por su clave del catálogo: el aporte guardado dice
        // «diezmo» y el archivo «Diezmo» o «Tithe», y sin esto reimportar el
        // mismo archivo no reconocía ninguno como ya registrado.
        "\(id)|\(CSV.fecha(fecha))|\(Catalogos.clave(deEtiqueta: concepto)?.rawValue ?? concepto.lowercased())|\(monto)"
    }
}
