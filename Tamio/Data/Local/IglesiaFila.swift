import Foundation
import GRDB

/// La configuración de la iglesia tal y como vive en SQLite.
struct IglesiaFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "iglesia"

    var id: String
    var nombre: String
    var direccion: String
    var ciudad: String
    var estado: String
    var pais: String
    var codigoPostal: String
    var idFiscal: String
    var telefono: String
    var correo: String
    var moneda: String
    var pieInstitucional: String
    var saldoInicial: Int
    var pastorNombre: String
    var pastorCargo: String
    var tesoreroNombre: String
    var tesoreroCargo: String
    var secretarioNombre: String
    var secretarioCargo: String
    var imprimirFirmas: Bool
    var tesoreroVePadron: Bool
    var tesoreroPuedeEliminar: Bool
    var plan: String
    var subEstado: String
    var subVence: String
    var actualizadoEn: String?

    init(id: String, _ c: ConfiguracionIglesia, actualizadoEn: String? = nil) {
        self.id = id
        nombre = c.nombre
        direccion = c.direccion
        ciudad = c.ciudad
        estado = c.estado
        pais = c.pais
        codigoPostal = c.codigoPostal
        idFiscal = c.idFiscal
        telefono = c.telefono
        correo = c.correo
        moneda = c.moneda
        pieInstitucional = c.pieInstitucional
        saldoInicial = c.saldoInicial
        pastorNombre = c.pastorNombre
        pastorCargo = c.pastorCargo
        tesoreroNombre = c.tesoreroNombre
        tesoreroCargo = c.tesoreroCargo
        secretarioNombre = c.secretarioNombre
        secretarioCargo = c.secretarioCargo
        imprimirFirmas = c.imprimirFirmas
        tesoreroVePadron = c.tesoreroVePadron
        tesoreroPuedeEliminar = c.tesoreroPuedeEliminar
        plan = c.plan
        subEstado = c.subEstado
        subVence = c.subVence
        self.actualizadoEn = actualizadoEn
    }

    var configuracion: ConfiguracionIglesia {
        ConfiguracionIglesia(
            nombre: nombre, direccion: direccion, ciudad: ciudad, estado: estado,
            pais: pais, codigoPostal: codigoPostal, idFiscal: idFiscal,
            telefono: telefono, correo: correo, moneda: moneda,
            pieInstitucional: pieInstitucional,
            saldoInicial: saldoInicial,
            pastorNombre: pastorNombre, pastorCargo: pastorCargo,
            tesoreroNombre: tesoreroNombre, tesoreroCargo: tesoreroCargo,
            secretarioNombre: secretarioNombre, secretarioCargo: secretarioCargo,
            imprimirFirmas: imprimirFirmas,
            tesoreroVePadron: tesoreroVePadron,
            tesoreroPuedeEliminar: tesoreroPuedeEliminar,
            plan: plan, subEstado: subEstado, subVence: subVence
        )
    }
}
