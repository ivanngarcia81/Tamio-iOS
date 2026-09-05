import Foundation
import GRDB

/// Frontera de datos de los movimientos recurrentes. Igual que el resto: la
/// pantalla solo habla con esto y no sabe si detrás hay SQLite o una lista en
/// memoria.
protocol RecurrentesRepository {
    /// Todas las definiciones vivas, activas y paradas. La pantalla separa.
    func lista() async throws -> [MovimientoRecurrente]
    func crear(_ r: MovimientoRecurrente) async throws
    func actualizar(_ r: MovimientoRecurrente) async throws
    /// Borrado lógico de la definición. **No toca los movimientos ya
    /// generados**: están registrados y contados, y hacerlos desaparecer
    /// descuadraría meses ya cerrados. Para dejar de generar sin borrar nada
    /// está `activo`.
    func eliminar(id: String) async throws
    /// Marca hasta qué mes está ya registrada una serie. Se escribe en la
    /// MISMA transacción que los movimientos que genera, o un cierre a
    /// destiempo dejaría rentas registradas sin marca y se duplicarían.
    func marcarGenerado(id: String, hasta mes: String) async throws
}

/// En modo revisión no hay base: se recuerda en memoria, como los demás mocks,
/// para poder recorrer la pantalla y ver aparecer lo que se crea.
func repositorioRecurrentes() -> RecurrentesRepository {
    ModoRevision.sinLogin ? MockRecurrentesRepository() : OfflineRecurrentesRepository()
}

// MARK: - Contra la base del teléfono

struct OfflineRecurrentesRepository: RecurrentesRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func lista() async throws -> [MovimientoRecurrente] {
        try await cola.read { db in
            try MovimientoRecurrenteFila
                .filter(Column("borrado") == false)
                .fetchAll(db)
                .map(\.recurrente)
        }
    }

    func crear(_ r: MovimientoRecurrente) async throws { try await guardar(r, operacion: .crear) }

    func actualizar(_ r: MovimientoRecurrente) async throws { try await guardar(r, operacion: .actualizar) }

    func eliminar(id: String) async throws {
        try await cola.write { db in
            try db.execute(sql: "update movimientoRecurrente set borrado = 1 where id = ?",
                           arguments: [id])
            try Self.encolar(db, id: id, operacion: .eliminar)
        }
    }

    func marcarGenerado(id: String, hasta mes: String) async throws {
        try await cola.write { db in
            try Self.marcar(db, id: id, hasta: mes)
        }
    }

    /// Dentro de una transacción ya abierta, para poder marcar en el mismo
    /// `write` que inserta los movimientos.
    static func marcar(_ db: Database, id: String, hasta mes: String) throws {
        try db.execute(sql: "update movimientoRecurrente set ultimoMesGenerado = ? where id = ?",
                       arguments: [mes, id])
        try encolar(db, id: id, operacion: .actualizar)
    }

    private func guardar(_ r: MovimientoRecurrente,
                         operacion: OperacionPendiente.Operacion) async throws {
        let fila = MovimientoRecurrenteFila(r)
        try await cola.write { db in
            try fila.save(db)
            try Self.encolar(db, id: r.id, operacion: operacion)
        }
    }

    /// Una sola operación pendiente por definición: al servidor le importa cómo
    /// quedó, no por cuántos cambios de importe pasó.
    private static func encolar(_ db: Database, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        try OperacionPendiente
            .filter(Column("entidad") == "movimientoRecurrente" && Column("registroId") == id)
            .deleteAll(db)
        var op = OperacionPendiente(id: nil, entidad: "movimientoRecurrente",
                                    registroId: id, operacion: operacion.rawValue,
                                    creadoEn: Date().timeIntervalSince1970,
                                    intentos: 0, ultimoError: nil)
        try op.insert(db)
    }
}

// MARK: - Modo revisión

struct MockRecurrentesRepository: RecurrentesRepository {
    /// Estático y compartido, como el resto de mocks: crear un recurrente en la
    /// hoja de captura tiene que verse en la pantalla que los lista.
    private static var almacen: [MovimientoRecurrente] = [
        MovimientoRecurrente(id: "mock-renta", tipo: .gasto,
                             categoria: L.t("Servicios", "Utilities"),
                             subcategoria: nil,
                             nota: L.t("Renta del local", "Venue rent"),
                             monto: 850_00, metodo: L.t("Efectivo", "Cash"),
                             pagadoA: nil, rfc: nil, dia: 5,
                             mesInicio: Fechas.clavePeriodo(),
                             ultimoMesGenerado: Fechas.clavePeriodo()),
    ]

    func lista() async throws -> [MovimientoRecurrente] { Self.almacen }

    func crear(_ r: MovimientoRecurrente) async throws {
        var nuevo = r
        if nuevo.id.isEmpty { nuevo.id = UUID().uuidString }
        Self.almacen.append(nuevo)
    }

    func actualizar(_ r: MovimientoRecurrente) async throws {
        guard let i = Self.almacen.firstIndex(where: { $0.id == r.id }) else { return }
        Self.almacen[i] = r
    }

    func eliminar(id: String) async throws { Self.almacen.removeAll { $0.id == id } }

    func marcarGenerado(id: String, hasta mes: String) async throws {
        guard let i = Self.almacen.firstIndex(where: { $0.id == id }) else { return }
        Self.almacen[i].ultimoMesGenerado = mes
    }
}

// MARK: - La materialización

/// **Convierte las definiciones en movimientos de verdad.**
///
/// Corre al arrancar la app y al volver del fondo, que es cuando puede haber
/// cambiado el mes. No hay tarea programada ni notificación de por medio: si la
/// app no se abre en tres meses, al abrirla se ponen los tres al día de una vez.
///
/// Tres reglas, y las tres tienen su porqué:
///
/// - **Solo meses concluidos.** El mes en curso no se registra hasta que
///   termina: hasta entonces la renta todavía se puede cambiar o no pagarse, y
///   un movimiento anticipado descuadra el corte del mes.
/// - **Nunca meses futuros**, por lo mismo, pero peor: sería dinero inventado.
/// - **Idempotente por `ultimoMesGenerado`.** Abrir la app dos veces, o dos
///   aparatos el mismo día, no genera dos rentas. La marca se escribe en la
///   misma transacción que los movimientos.
enum MaterializadorRecurrentes {

    /// Lo hecho en una pasada, para poder enseñarlo y para la sonda.
    struct Resultado {
        var generados: Int = 0
        var series: Int = 0
    }

    /// Los dos repositorios entran por parámetro —con la fábrica por defecto,
    /// que es lo que usa la app— para poder ejercitar la materialización contra
    /// la base de verdad desde una sonda, sin depender de si el aparato está en
    /// modo revisión. Es lo más delicado de todo esto: aquí es donde se
    /// duplican las rentas, y no hay target de tests donde atraparlo.
    @discardableResult
    static func alDia(hoy: Date = Date(),
                      autor: String? = nil,
                      repo: RecurrentesRepository = repositorioRecurrentes(),
                      movimientos: MovimientosRepository = repositorioMovimientos()) async -> Resultado {
        var resultado = Resultado()
        let mesHoy = MesesRecurrentes.mes(de: hoy)

        guard let definiciones = try? await repo.lista() else { return resultado }

        for def in definiciones where def.activo {
            let (meses, marca) = MesesRecurrentes.pendientes(
                mesInicio: def.mesInicio,
                ultimoMesGenerado: def.ultimoMesGenerado,
                hoy: mesHoy
            )
            guard !meses.isEmpty else { continue }

            var generadosDeEsta = 0
            for mes in meses {
                guard let fecha = MesesRecurrentes.fecha(en: mes, dia: def.dia) else { continue }
                do {
                    try await movimientos.crear(movimiento(de: def, en: fecha, autor: autor))
                    generadosDeEsta += 1
                } catch {
                    // Si uno falla se para ESTA serie y no se marca: lo que
                    // quedó a medias se reintenta al abrir otra vez. Marcar
                    // hasta el final saltaría para siempre los meses que no
                    // llegaron a escribirse.
                    break
                }
            }

            // La marca solo llega hasta donde de verdad se escribió.
            let hasta = generadosDeEsta == meses.count ? marca : meses[generadosDeEsta - 1]
            if generadosDeEsta > 0 {
                try? await repo.marcarGenerado(id: def.id, hasta: hasta)
                resultado.generados += generadosDeEsta
                resultado.series += 1
            }
        }
        return resultado
    }

    /// **La definición que nace al marcar el interruptor** sobre un movimiento
    /// que se acaba de capturar.
    ///
    /// `ultimoMesGenerado` arranca en el mes de ese movimiento, no en `nil`:
    /// el que la persona acaba de escribir ES la renta de ese mes y ya está
    /// registrada. Sin esto, la definición volvería a generarla en cuanto el
    /// mes concluyera y la renta saldría dos veces —es el mismo caso que la app
    /// web resuelve con `skipMes`—.
    ///
    /// Y `mesInicio` es el mes del movimiento y no enero: un recurrente arranca
    /// donde se crea y nunca retrocede por su cuenta.
    static func definicion(desde m: Movimiento) -> MovimientoRecurrente {
        let mes = MesesRecurrentes.mes(de: m.fecha)
        let dia = Calendar(identifier: .gregorian).component(.day, from: m.fecha)
        return MovimientoRecurrente(
            id: UUID().uuidString,
            tipo: m.tipo,
            categoria: m.categoria,
            subcategoria: m.subcategoria,
            nota: m.nota,
            monto: m.monto,
            metodo: m.metodo,
            pagadoA: m.pagadoA,
            rfc: m.rfc,
            dia: dia,
            mesInicio: mes,
            ultimoMesGenerado: mes,
            activo: true)
    }

    /// El movimiento que le toca a una definición en un mes. `crear` le pone id
    /// y folio; aquí solo se rellena lo que sale de la regla.
    static func movimiento(de def: MovimientoRecurrente,
                           en fecha: Date,
                           autor: String? = nil) -> Movimiento {
        let hf = DateFormatter()
        hf.locale = Locale(identifier: "en_US_POSIX")
        hf.dateFormat = "HH:mm"
        let firma = autor ?? L.t("Automático", "Automatic")

        return Movimiento(
            id: "",
            tipo: def.tipo,
            categoria: def.categoria,
            persona: def.tipo == .gasto ? def.pagadoA : nil,
            folio: "",
            metodo: def.metodo,
            monto: def.monto,
            hora: hf.string(from: fecha),
            fecha: fecha,
            // **Firmado como automático, no con el nombre de quien abrió la
            // app.** Quien abre la app el día 1 no registró esa renta: la
            // registró la regla. Poner su nombre en el rastro de auditoría
            // sería atribuirle un movimiento que no capturó.
            registradoPor: firma,
            miembro: nil,
            categoriaCompleta: def.categoriaCompleta,
            nota: def.nota,
            // Un ingreso recurrente nace sin depositar, como cualquier otro;
            // el corte decide después.
            sinDepositar: def.tipo == .ingreso,
            comprobante: nil,
            auditoria: [
                AuditEntry(id: "1",
                           titulo: L.t("Generado por un movimiento recurrente",
                                       "Created by a recurring entry"),
                           detalle: L.t("\(def.titular) · cada mes el día \(def.dia)",
                                        "\(def.titular) · monthly on day \(def.dia)"))
            ],
            pagadoA: def.tipo == .gasto ? def.pagadoA : nil,
            rfc: def.rfc,
            notasAuditoria: nil,
            // **Nace aprobado, no pendiente.** La cifra la fijó la persona al
            // crear la regla; mandar a la bandeja doce rentas idénticas al año
            // convertiría "Por revisar" en ruido y nadie miraría las que sí
            // importan.
            estadoRevision: .aprobado,
            incluidoEnCorte: false,
            darConstanciaAnual: false,
            repiteMensual: true,
            recurrenteId: def.id,
            memberUid: nil,
            subcategoria: def.subcategoria,
            aportanteNombre: nil
        )
    }
}
