import Foundation
import GRDB
import Supabase

/// Frontera de datos de la configuración institucional.
protocol ConfiguracionIglesiaRepository {
    func cargar() async throws -> ConfiguracionIglesia
    func guardar(_ c: ConfiguracionIglesia) async throws
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
}

func repositorioConfiguracionIglesia() -> ConfiguracionIglesiaRepository {
    ModoRevision.sinLogin
        ? MockConfiguracionIglesiaRepository()
        : OfflineConfiguracionIglesiaRepository()
}
