import Foundation

/// Estado de un corte: pendiente de llevar al banco, o ya depositado.
enum EstadoDeposito {
    case pendiente, depositado
}

/// Tipo de aviso en el checklist "Antes de depositar".
enum TipoChequeo {
    case aviso   // naranja, algo que revisar
    case ok      // verde, todo en orden
    case duda    // gris, decisión del usuario
}

/// Un ítem del checklist "Antes de depositar".
struct Chequeo: Identifiable {
    let id: Int
    let tipo: TipoChequeo
    let titulo: String
    let detalle: String
    let enlace: String?   // "Ir a Por revisar"
}

/// Un movimiento incluido en el corte (dinero en caja). `seleccionado` es mutable:
/// el usuario marca/desmarca qué entra al depósito y los totales se recalculan.
struct MovimientoCaja: Identifiable {
    let id: Int
    let categoria: String
    let folio: String
    let cuando: String    // "Domingo 23 · 12:38 p.m."
    let monto: Centavos
    var seleccionado: Bool
    var esCheque: Bool = false   // separa efectivo de cheques al totalizar
}

/// Cómo se registrará el depósito ("Se registrará así"). `cuenta` y `monto`
/// cambian al asignar cuenta o recomputar la selección.
struct RegistroDeposito {
    var cuenta: String
    let fecha: String
    let periodo: String
    var monto: Centavos
}

/// Un corte de caja (depósito). Reúne lo de la lista y lo del detalle. Los campos
/// derivados son `var`: se recalculan cuando cambia la selección de movimientos,
/// se asigna cuenta, se adjunta la ficha o se marca como depositado.
struct Corte: Identifiable, Hashable {
    let id: String
    var titulo: String
    var subtitulo: String       // "14 movimientos · Banorte ··4821"
    var descripcion: String     // "Dinero en caja del domingo 23 de agosto · …"
    var montoTotal: Centavos
    var estado: EstadoDeposito

    // Chips del detalle (derivados de la selección).
    var efectivoSeleccionado: Centavos
    let efectivoEstimado: Centavos
    var chequesMonto: Centavos
    var chequesCount: Int
    var listoParaDepositar: Centavos
    var seleccionados: Int
    var totalSeleccionables: Int

    var chequeos: [Chequeo]
    var movimientos: [MovimientoCaja]
    var registro: RegistroDeposito
    /// Nombre del archivo de la ficha del banco adjunta (nil = sin adjuntar).
    var fichaAdjunta: String? = nil

    var sinDepositar: Bool { estado == .pendiente }

    static func == (l: Corte, r: Corte) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
