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

/// A dónde manda el enlace de un chequeo. Antes el enlace era un `String`
/// suelto que la vista comparaba contra el literal "Asignar cuenta": con la
/// app en inglés la comparación fallaba y el menú no salía. La acción es un
/// caso, no un texto traducido.
enum AccionChequeo {
    case asignarCuenta
    case irAPorRevisar
    case cambiarPeriodo
}

/// Un ítem del checklist "Antes de depositar".
struct Chequeo: Identifiable {
    let id: Int
    let tipo: TipoChequeo
    let titulo: String
    let detalle: String
    var accion: AccionChequeo? = nil

    /// El texto del enlace, derivado de la acción: no hay forma de escribir un
    /// enlace que no lleve a ningún sitio.
    var enlace: String? {
        switch accion {
        case .asignarCuenta:  return L.t("Asignar cuenta", "Assign account")
        case .irAPorRevisar:  return L.t("Ir a Por revisar", "Go to Review")
        case .cambiarPeriodo: return L.t("Cambiar periodo", "Change period")
        case nil:             return nil
        }
    }
}

/// Un movimiento incluido en el corte (dinero en caja). `seleccionado` es
/// mutable: el usuario marca/desmarca qué entra al depósito y los totales se
/// recalculan.
struct MovimientoCaja: Identifiable {
    /// `var`: al agregarlo a un corte se le asigna el siguiente id libre de
    /// ESE corte, igual que `Movimiento.folio` lo asigna el contador.
    var id: Int
    let categoria: String
    let folio: String
    let cuando: String    // "Domingo 23 · 12:38 p.m."
    let monto: Centavos
    var seleccionado: Bool
    var esCheque: Bool = false   // separa efectivo de cheques al totalizar
    /// Número del cheque ("4102"). Solo cuando `esCheque`. Antes iba escrito
    /// dentro de `cuando` ("Cheque 3841 · Banamex"), donde no se podía leer ni
    /// buscar: el número del cheque es lo que el banco pide en la ficha.
    var numeroCheque: String? = nil

    /// Lo que se lee bajo la categoría: el cheque manda sobre la hora.
    var referencia: String {
        if esCheque, let n = numeroCheque, !n.isEmpty {
            return L.t("Cheque \(n)", "Check \(n)")
        }
        return L.t("Efectivo", "Cash")
    }
}

/// Cómo se registrará el depósito ("Se registrará así"). Solo lo que el
/// usuario decide: el monto NO vive aquí, se calcula desde la selección.
struct RegistroDeposito {
    var cuenta: String
    var fecha: String
    var periodo: String
}

/// Un corte de caja (depósito).
///
/// **Todo lo que es una suma es una propiedad calculada.** Antes los totales,
/// los contadores y el subtítulo eran campos guardados que se escribían a mano
/// en el repositorio y solo se recalculaban al marcar un movimiento: un corte
/// recién abierto decía "14 movimientos" con tres en la lista, "4 de 5
/// seleccionados" con tres seleccionados, y un total de la fila ($18,540.00)
/// distinto al del detalle ($11,445.00). En una tesorería esa cifra se firma.
struct Corte: Identifiable, Hashable {
    let id: String
    var titulo: String
    var descripcion: String
    var estado: EstadoDeposito
    var movimientos: [MovimientoCaja]
    var registro: RegistroDeposito

    /// Efectivo que la iglesia estima tener en caja a esa fecha. Es dato de
    /// fuera del corte (incluye lo que no entra en este depósito), así que se
    /// guarda; `nil` cuando no se ha contado, y entonces no se enseña una cifra
    /// inventada.
    var efectivoEstimado: Centavos? = nil

    /// Cuántos movimientos de esa fecha están marcados "por revisar" y por eso
    /// se quedan fuera del corte.
    var porRevisar: Int = 0

    /// Nombre del archivo de la ficha del banco adjunta (nil = sin adjuntar).
    var fichaAdjunta: String? = nil

    // MARK: - Derivados

    var seleccion: [MovimientoCaja] { movimientos.filter(\.seleccionado) }
    var efectivoSeleccionado: Centavos {
        seleccion.filter { !$0.esCheque }.reduce(0) { $0 + $1.monto }
    }
    var cheques: [MovimientoCaja] { seleccion.filter(\.esCheque) }
    var chequesMonto: Centavos { cheques.reduce(0) { $0 + $1.monto } }
    var chequesCount: Int { cheques.count }
    var listoParaDepositar: Centavos { efectivoSeleccionado + chequesMonto }
    /// El monto del corte **es** lo que se va a depositar. Eran dos campos
    /// distintos y no coincidían.
    var montoTotal: Centavos { listoParaDepositar }
    var seleccionados: Int { seleccion.count }
    var totalSeleccionables: Int { movimientos.count }
    var sinDepositar: Bool { estado == .pendiente }
    var sinCuenta: Bool { registro.cuenta.isEmpty || registro.cuenta == Self.sinAsignar }

    static let sinAsignar = L.t("Sin asignar", "Unassigned")

    /// "3 movimientos · Banorte ··4821". Se contaba a mano.
    var subtitulo: String {
        let n = movimientos.count
        let cuenta = sinCuenta ? L.t("Sin cuenta asignada", "No account assigned") : registro.cuenta
        return L.t("\(n) movimiento\(n == 1 ? "" : "s") · \(cuenta)",
                   "\(n) entr\(n == 1 ? "y" : "ies") · \(cuenta)")
    }

    /// El checklist "Antes de depositar", **generado desde el corte**. Antes
    /// eran tres textos guardados con los importes escritos dentro: seguían
    /// diciendo "$8,045.00 en efectivo" después de desmarcar el movimiento que
    /// los sostenía, y "los 6 movimientos son en efectivo" con uno en la lista.
    var chequeos: [Chequeo] {
        var lista: [Chequeo] = []

        if estado == .depositado {
            return [Chequeo(id: 1, tipo: .ok,
                            titulo: L.t("Depósito registrado", "Deposit recorded"),
                            detalle: fichaAdjunta.map {
                                L.t("Ficha adjunta: \($0).", "Slip attached: \($0).")
                            } ?? L.t("Registrado sin ficha del banco adjunta.",
                                     "Recorded without a bank slip attached."))]
        }

        if sinCuenta {
            lista.append(Chequeo(id: 1, tipo: .aviso,
                                 titulo: L.t("Sin cuenta asignada", "No account assigned"),
                                 detalle: L.t("Elige a qué cuenta va este depósito antes de registrarlo.",
                                              "Pick which account this deposit goes to before recording it."),
                                 accion: .asignarCuenta))
        }

        if porRevisar > 0 {
            lista.append(Chequeo(id: 2, tipo: .aviso,
                                 titulo: L.t("\(porRevisar) movimiento\(porRevisar == 1 ? "" : "s") marcado\(porRevisar == 1 ? "" : "s") por revisar",
                                             "\(porRevisar) entr\(porRevisar == 1 ? "y" : "ies") flagged for review"),
                                 detalle: L.t("No se cuentan en los totales del mes hasta que los confirmes, así que tampoco entran en este depósito.",
                                              "They don't count in monthly totals until confirmed, so they're not in this deposit either."),
                                 accion: .irAPorRevisar))
        }

        if movimientos.isEmpty {
            lista.append(Chequeo(id: 3, tipo: .duda,
                                 titulo: L.t("Corte sin movimientos", "Empty cut"),
                                 detalle: L.t("Agrega el dinero en caja que va en este depósito. Mientras esté vacío no hay nada que llevar al banco.",
                                              "Add the cash entries this deposit covers. While it's empty there's nothing to take to the bank.")))
        } else if seleccionados == 0 {
            lista.append(Chequeo(id: 3, tipo: .aviso,
                                 titulo: L.t("Nada seleccionado", "Nothing selected"),
                                 detalle: L.t("Los \(totalSeleccionables) movimientos están desmarcados, así que el depósito suma \(Money.fmt(0)).",
                                              "All \(totalSeleccionables) entries are unchecked, so the deposit totals \(Money.fmt(0)).")))
        } else if chequesCount == 0 {
            lista.append(Chequeo(id: 3, tipo: .ok,
                                 titulo: L.t("Todo en efectivo", "All cash"),
                                 detalle: L.t("Los \(seleccionados) movimientos seleccionados son en efectivo y suman \(Money.fmt(efectivoSeleccionado)).",
                                              "The \(seleccionados) selected entries are cash, totaling \(Money.fmt(efectivoSeleccionado)).")))
        } else {
            lista.append(Chequeo(id: 3, tipo: .ok,
                                 titulo: L.t("Efectivo y cheques", "Cash and checks"),
                                 detalle: L.t("\(Money.fmt(efectivoSeleccionado)) en efectivo y \(chequesCount) cheque\(chequesCount == 1 ? "" : "s") por \(Money.fmt(chequesMonto)) van en la misma ficha.",
                                              "\(Money.fmt(efectivoSeleccionado)) in cash and \(chequesCount) check\(chequesCount == 1 ? "" : "s") for \(Money.fmt(chequesMonto)) go on the same slip.")))
        }

        if let estimado = efectivoEstimado, efectivoSeleccionado > estimado {
            lista.append(Chequeo(id: 4, tipo: .aviso,
                                 titulo: L.t("El efectivo no alcanza", "Not enough cash"),
                                 detalle: L.t("Vas a depositar \(Money.fmt(efectivoSeleccionado)) pero en caja se estiman \(Money.fmt(estimado)). Cuenta el efectivo antes de ir al banco.",
                                              "You'd deposit \(Money.fmt(efectivoSeleccionado)) but only \(Money.fmt(estimado)) is estimated on hand. Count the cash before going to the bank.")))
        }

        lista.append(Chequeo(id: 5, tipo: .duda,
                             titulo: L.t("Periodo contable: \(registro.periodo)",
                                         "Accounting period: \(registro.periodo)"),
                             detalle: L.t("Si este dinero es de otro mes, cambia el periodo: suma en el periodo que elijas, no en la fecha en que lo llevas al banco.",
                                          "If this is another month's money, change the period: it adds to the period you pick, not the bank date."),
                             accion: .cambiarPeriodo))
        return lista
    }

    static func == (l: Corte, r: Corte) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
