import Foundation
import GRDB
import Supabase

/// Frontera de datos de la configuración institucional.
protocol ConfiguracionIglesiaRepository {
    func cargar() async throws -> ConfiguracionIglesia
    func guardar(_ c: ConfiguracionIglesia) async throws
    /// Los dos permisos del rol Tesorería. **No pasa por la cola de subida.**
    ///
    /// Es la excepción al "escribe local y ya sale cuando haya señal", y a
    /// propósito: quien decide si un permiso cambia es el servidor —el RPC
    /// rechaza a quien no sea administrador— y un permiso que se pinta
    /// encendido en el teléfono y luego se cae solo es peor que uno lento,
    /// porque quien lo tocó se va creyendo que lo dejó puesto. Primero el
    /// servidor, y solo si acepta se escribe el espejo local.
    func fijarPermisos(vePadron: Bool, puedeEliminar: Bool) async throws
}

/// Guarda en el teléfono y encola para subir, igual que los movimientos: se
/// puede corregir el domicilio de la iglesia sin señal y sale cuando la haya.
struct OfflineConfiguracionIglesiaRepository: ConfiguracionIglesiaRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func cargar() async throws -> ConfiguracionIglesia {
        let fila = try await cola.read { db in
            try IglesiaFila.fetchOne(db, key: churchIdActivo)
        }
        return fila?.configuracion ?? ConfiguracionIglesia()
    }

    func fijarPermisos(vePadron: Bool, puedeEliminar: Bool) async throws {
        struct Args: Encodable {
            let pVePadron: Bool
            let pPuedeEliminar: Bool
            enum CodingKeys: String, CodingKey {
                case pVePadron      = "p_ve_padron"
                case pPuedeEliminar = "p_puede_eliminar"
            }
        }
        try await supabase
            .rpc("fijar_permisos_tesoreria",
                 params: Args(pVePadron: vePadron, pPuedeEliminar: puedeEliminar))
            .execute()

        // El espejo local, solo ahora. Se escribe a mano y sin encolar nada:
        // estas dos columnas no viajan en el `update` general de la iglesia.
        try await cola.write { db in
            try db.execute(sql: """
                update iglesia set tesoreroVePadron = ?, tesoreroPuedeEliminar = ?
                where id = ?
                """, arguments: [vePadron, puedeEliminar, churchIdActivo])
        }
    }

    func guardar(_ c: ConfiguracionIglesia) async throws {
        try await cola.write { db in
            try IglesiaFila(id: churchIdActivo, c).save(db)
            // Una sola operación pendiente por iglesia: al servidor solo le
            // importa cómo quedó, no por cuántas ediciones pasó.
            try OperacionPendiente
                .filter(Column("entidad") == "iglesia")
                .deleteAll(db)
            var op = OperacionPendiente(id: nil, entidad: "iglesia",
                                        registroId: churchIdActivo,
                                        operacion: OperacionPendiente.Operacion.actualizar.rawValue,
                                        creadoEn: Date().timeIntervalSince1970,
                                        intentos: 0, ultimoError: nil)
            try op.insert(db)
        }
    }
}

/// En modo revisión no hay sesión ni base que sincronizar: se recuerda en
/// memoria para poder recorrer la pantalla y ver los documentos con datos.
struct MockConfiguracionIglesiaRepository: ConfiguracionIglesiaRepository {
    private static var almacen = ConfiguracionIglesia(
        nombre: "Iglesia Nueva Vida",
        direccion: "Av. Constitución 1234",
        ciudad: "Monterrey", estado: "Nuevo León", pais: "México",
        codigoPostal: "64000", idFiscal: "INV010203AB4",
        telefono: "81 1234 5678", correo: "contacto@nuevavida.mx",
        pieInstitucional: "Asociación Religiosa registrada",
        pastorNombre: "Samuel Ruvalcaba",
        tesoreroNombre: "Iván García",
        secretarioNombre: "Lucía Márquez"
    )

    func cargar() async throws -> ConfiguracionIglesia { Self.almacen }
    func guardar(_ c: ConfiguracionIglesia) async throws { Self.almacen = c }

    func fijarPermisos(vePadron: Bool, puedeEliminar: Bool) async throws {
        Self.almacen.tesoreroVePadron = vePadron
        Self.almacen.tesoreroPuedeEliminar = puedeEliminar
    }
}

func repositorioConfiguracionIglesia() -> ConfiguracionIglesiaRepository {
    ModoRevision.sinLogin
        ? MockConfiguracionIglesiaRepository()
        : OfflineConfiguracionIglesiaRepository()
}
