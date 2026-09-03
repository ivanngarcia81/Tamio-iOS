import Foundation

/// Saca a CSV lo que hay en Aportantes.
///
/// El formato que se genera aquí **es el mismo que aceptará la importación**:
/// se puede exportar, editar en Excel y volver a subir. Por eso las columnas
/// llevan nombres estables en vez de los títulos traducidos que se ven en
/// pantalla — un archivo exportado en inglés tiene que poder importarse en un
/// aparato en español.
enum ExportadorAportantes {

    static let columnasAportantes = [
        "id", "nombre", "estado", "rol", "miembro_desde", "congrega_desde",
        "telefono", "correo", "nacimiento", "direccion", "estado_civil",
        "id_fiscal", "frecuencia_aporte", "total_aportado",
    ]

    static let columnasAportes = [
        "aportante_id", "aportante_nombre", "fecha", "concepto", "monto",
    ]

    static func aportantes(_ lista: [Aportante]) -> URL? {
        let filas = lista.map { a in
            [a.id, a.nombre, estadoTexto(a.estado), a.rol, a.miembroDesde,
             a.congregaDesde, a.telefono, a.correo, a.nacimiento, a.direccion,
             a.estadoCivil, a.idFiscal, a.frecuencia.rawValue,
             CSV.importe(a.aportesTotal)]
        }
        return CSV.archivo(nombre: "aportantes-\(CSV.fecha(Date()))",
                           encabezados: columnasAportantes, filas: filas)
    }

    static func aportes(_ lista: [Aportante]) -> URL? {
        // Ordenado por fecha para que el archivo se lea como un libro de
        // cuentas y no como el volcado interno que es.
        let filas = lista
            .flatMap { a in a.aportes.map { (a, $0) } }
            .sorted { $0.1.fecha > $1.1.fecha }
            .map { par in
                [par.0.id, par.0.nombre, CSV.fecha(par.1.fecha),
                 par.1.concepto, CSV.importe(par.1.monto)]
            }
        return CSV.archivo(nombre: "aportes-\(CSV.fecha(Date()))",
                           encabezados: columnasAportes, filas: filas)
    }

    /// El mismo formato, vacío y con una fila de ejemplo. Es la forma más
    /// corta de explicar el formato: se abre en Excel, se ve qué va en cada
    /// columna y se rellena encima.
    static func plantilla() -> URL? {
        let ejemplo = ["", "María Hernández Ríos", "activo", "diezmo", "2014", "2012",
                       "81 1234 5678", "maria@correo.mx", "1978-03-14",
                       "Av. Constitución 1234", "casado", "HERM780314IJ5",
                       "semanal", CSV.importe(0)]
        return CSV.archivo(nombre: L.t("plantilla-aportantes", "givers-template"),
                           encabezados: columnasAportantes, filas: [ejemplo])
    }

    /// Sin traducir: el archivo se vuelve a leer, y un "Activo" exportado en
    /// español tiene que significar lo mismo al importarlo en inglés.
    private static func estadoTexto(_ e: EstadoMiembro) -> String {
        switch e {
        case .activo:   return "activo"
        case .nuevo:    return "nuevo"
        case .traslado: return "traslado"
        case .baja:     return "baja"
        case .recibido: return "recibido"
        }
    }
}
