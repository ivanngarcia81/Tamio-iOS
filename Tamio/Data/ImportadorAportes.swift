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

    static func analizar(_ url: URL, existentes: [Aportante]) throws -> Analisis {
        let doc = try CSVLector.leer(url)
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
                                            "No giver matches that name")))
                continue
            }
            guard let fecha = Fechas.desdeTextoFlexible(textoFecha) else {
                analizadas.append(fallo(L.t("Fecha no válida", "Invalid date")))
                continue
            }
            guard let centavos = Money.desdeTexto(textoMonto), centavos > 0 else {
                analizadas.append(fallo(L.t("Monto no válido", "Invalid amount")))
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
        "\(id)|\(CSV.fecha(fecha))|\(concepto.lowercased())|\(monto)"
    }
}
