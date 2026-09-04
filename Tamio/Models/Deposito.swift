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

/// **Cómo verificó la segunda persona.** La diferencia no es cosmética, y por
/// eso el modo se guarda:
///
/// - `conteo` — volvió a contar el dinero y trae SU cifra. Compara el efectivo
///   físico contra lo registrado: es el único control de la app que hace eso.
/// - `revision` — revisó el registro. Es lo único que cabe cuando la firma
///   llega días después y el dinero ya está en el banco: puede decir que lo
///   apuntado es coherente consigo mismo, no que el dinero estuviera.
///
/// Viene de la app web (migración 47), no se inventa aquí. **Ojo:** no describe
/// el canal —si firmó en este teléfono o en el suyo—, sino QUÉ verificó.
enum ModoSegundaFirma: String {
    case conteo, revision
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
    /// **Los movimientos de Ingresos que este corte agrupa, no copias suyas.**
    /// Antes eran `MovimientoCaja`, un modelo paralelo con `id: Int` que no
    /// podía apuntar a nada: capturar un diezmo en Ingresos no lo hacía
    /// aparecer en su corte, y meter dinero en el corte no lo registraba en
    /// Ingresos. Dos puertas de entrada al mismo dato, que es justo lo que la
    /// regla "un dato, un dueño" existe para evitar.
    ///
    /// El repositorio los resuelve por id desde la tabla puente. Estar en la
    /// lista ES estar en el corte: no hay un `seleccionado` que pueda
    /// contradecir a la fila puente.
    var movimientos: [Movimiento]
    var registro: RegistroDeposito

    /// Efectivo que la iglesia tiene en caja a esa fecha. **Calculado**, no
    /// tecleado: como lo contado se deposita íntegro —nunca se paga un gasto
    /// con el dinero de la ofrenda—, el efectivo en caja es exactamente lo
    /// recibido en efectivo que ningún corte depositado reclama. Lo pone el
    /// repositorio; era un campo que había que escribir a mano, y contra un
    /// número tecleado el aviso "el efectivo no alcanza" no comprobaba nada.
    var efectivoEnCaja: Centavos = 0

    /// Cuántos movimientos de esa fecha están marcados "por revisar" y por eso
    /// se quedan fuera del corte.
    var porRevisar: Int = 0

    /// Nombre del archivo de la ficha del banco adjunta (nil = sin adjuntar).
    var fichaAdjunta: String? = nil

    // MARK: - Doble conteo
    //
    // El tesorero cuenta el dinero y lo captura; el ASISTENTE cuenta el mismo
    // dinero por su lado y firma que le sale la misma cantidad. Por eso
    // `segundaConteo` es un importe y no un booleano: es SU cuenta, para poder
    // compararla contra `montoTotal`, que la app calcula sola.
    //
    // El conteo va A CIEGAS: la pantalla le pide su cifra sin enseñarle el
    // total. Si lo ve antes, la mano tiende a escribirlo y el control se vuelve
    // un sello.
    //
    // Las columnas y la doctrina vienen de la app web (migración 47); esto es
    // el mismo control, no uno nuevo. La app todavía no lo enseña.

    /// Quién armó el corte. Se usa para EXCLUIRLO de los candidatos a firmar:
    /// nadie se firma a sí mismo.
    var registradoPor: String = ""

    var dobleFirmaPedida: Bool = false
    var segundaFirma: String? = nil
    var segundaFirmaRol: String? = nil
    var segundaFirmaEn: String? = nil
    /// Ver `ModoSegundaFirma`. Se guarda como texto por ser lo que viaja.
    var segundaFirmaModo: String? = nil
    /// El importe que contó el asistente, en centavos.
    var segundaConteo: Centavos? = nil

    /// Diferencia entre lo que contó el asistente y lo que suma el corte.
    /// `nil` mientras no haya segundo conteo. Cero es que cuadra.
    var diferenciaConteo: Centavos? {
        segundaConteo.map { $0 - montoTotal }
    }

    /// Hay cifra del asistente y NO cuadra con el corte.
    var conteoDescuadra: Bool { (diferenciaConteo ?? 0) != 0 && segundaConteo != nil }

    /// **La firma está dada solo si hay nombre.** Puede haber conteo sin firma:
    /// es lo que pasa cuando no cuadra.
    var tieneSegundaFirma: Bool {
        !(segundaFirma?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }

    /// Ya depositado = el dinero está en el banco y no se puede volver a
    /// contar. Solo cabe revisar el registro.
    var soloRevision: Bool { estado == .depositado }

    var modoSegundaFirma: ModoSegundaFirma? {
        segundaFirmaModo.flatMap(ModoSegundaFirma.init(rawValue:))
    }

    // MARK: - Derivados

    var efectivo: [Movimiento] { movimientos.filter(\.esEfectivo) }
    var efectivoSeleccionado: Centavos { efectivo.reduce(0) { $0 + $1.monto } }
    var cheques: [Movimiento] { movimientos.filter(\.esCheque) }
    /// Efectivo sin depositar que NO está en este corte.
    var efectivoFuera: Centavos { max(0, efectivoEnCaja - efectivoSeleccionado) }
    var chequesMonto: Centavos { cheques.reduce(0) { $0 + $1.monto } }
    var chequesCount: Int { cheques.count }
    var listoParaDepositar: Centavos { efectivoSeleccionado + chequesMonto }
    /// El monto del corte **es** lo que se va a depositar. Eran dos campos
    /// distintos y no coincidían.
    var montoTotal: Centavos { listoParaDepositar }
    /// Cuántos movimientos agrupa. Ya no hay "N de M seleccionados": estar en
    /// el corte ES estar seleccionado, así que los dos números eran el mismo.
    var cuantos: Int { movimientos.count }
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
        } else if chequesCount == 0 {
            lista.append(Chequeo(id: 3, tipo: .ok,
                                 titulo: L.t("Todo en efectivo", "All cash"),
                                 detalle: L.t("Los \(cuantos) movimientos del corte son en efectivo y suman \(Money.fmt(efectivoSeleccionado)).",
                                              "All \(cuantos) entries in this cut are cash, totaling \(Money.fmt(efectivoSeleccionado)).")))
        } else {
            lista.append(Chequeo(id: 3, tipo: .ok,
                                 titulo: L.t("Efectivo y cheques", "Cash and checks"),
                                 detalle: L.t("\(Money.fmt(efectivoSeleccionado)) en efectivo y \(chequesCount) cheque\(chequesCount == 1 ? "" : "s") por \(Money.fmt(chequesMonto)) van en la misma ficha.",
                                              "\(Money.fmt(efectivoSeleccionado)) in cash and \(chequesCount) check\(chequesCount == 1 ? "" : "s") for \(Money.fmt(chequesMonto)) go on the same slip.")))
        }

        // Lo que se queda en la caja fuerte si va al banco solo con este sobre.
        //
        // Aquí ANTES había un aviso de "el efectivo no alcanza", que comparaba
        // contra un número tecleado. Ya no puede existir: el efectivo en caja
        // se calcula desde los ingresos sin depositar, e incluye los de este
        // corte, así que jamás se quedaría corto. Y un movimiento no puede
        // estar en dos cortes —Postgres lo impide con un índice único—, que era
        // la única forma de descuadrar. Cambiar un aviso falso por uno que no
        // puede saltar no es arreglarlo, así que dice otra cosa: cuánto dinero
        // estás dejando atrás.
        if efectivoFuera > 0 {
            lista.append(Chequeo(id: 4, tipo: .duda,
                                 titulo: L.t("Queda efectivo fuera de este corte", "Cash left out of this cut"),
                                 detalle: L.t("Hay \(Money.fmt(efectivoFuera)) más en efectivo sin depositar que no están aquí. Si va todo al banco de una vez, agrégalo.",
                                              "There's \(Money.fmt(efectivoFuera)) more in undeposited cash that isn't here. If it all goes to the bank at once, add it.")))
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
