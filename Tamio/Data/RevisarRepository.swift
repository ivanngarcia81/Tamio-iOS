import Foundation

protocol RevisarRepository {
    func asuntos() async -> [Revision]
    func resolver(id: String) async
    /// Resuelve de golpe solo los tipos que se le pasen. No existe un
    /// "resuélvelo todo": un duplicado o un gasto sin comprobante no se
    /// aprueban en bloque, que es justo lo que su bandera está pidiendo.
    func resolverTodos(tipos: Set<RevisionTipo>) async
    func restaurar(_ r: Revision) async
    func actualizar(_ r: Revision) async
}

/// **La bandeja de verdad: se calcula, no se guarda.**
///
/// Lee los movimientos, los aportantes de baja y los cortes sin segunda firma, y
/// deja que `CalculadoraRevisiones` decida qué merece una mirada. Sustituye a la
/// semilla de diez asuntos escritos a mano, que no salían de ningún dato: por
/// eso el badge del tab decía 8 mientras Ingresos tenía UN movimiento marcado y
/// el corte del domingo decía 2.
struct RevisarCalculado: RevisarRepository {
    private let movimientos = repositorioMovimientos()
    private let miembros = repositorioMiembros()
    private let depositos = repositorioDepositos()

    /// **Lo que el usuario ya miró y decidió dejar pasar.**
    ///
    /// La mayoría de las alertas no necesitan esto: desaparecen solas en cuanto
    /// el dato se arregla —adjuntas el comprobante y el aviso se va—. Pero
    /// "no es duplicado" es una decisión sobre algo que NO está mal, así que no
    /// hay dato que cambiar; sin recordarla, el mismo par volvería a salir en
    /// cada carga. Provisional en memoria: su sitio es una columna del
    /// movimiento, como `markTxRejected` en la app web.
    private static var silenciados: Set<String> = []

    func asuntos() async -> [Revision] {
        async let ingresos = try? movimientos.lista(tipo: .ingreso)
        async let gastos = try? movimientos.lista(tipo: .gasto)
        async let bajas = try? miembros.lista(filtro: .bajas)
        async let pendientes = try? depositos.cortes(estado: .pendiente)
        async let depositados = try? depositos.cortes(estado: .depositado)

        let movs = ((await ingresos) ?? []) + ((await gastos) ?? [])
        // Un corte pide firma esté depositado o no: si se firmó tarde, el modo
        // "revisión" sigue siendo posible con el dinero ya en el banco.
        let cortes = ((await pendientes) ?? []) + ((await depositados) ?? [])
        let sinFirma = cortes.filter { $0.dobleFirmaPedida && !$0.tieneSegundaFirma }

        return CalculadoraRevisiones
            .calcular(movimientos: movs,
                      archivados: (await bajas) ?? [],
                      cortesSinFirma: sinFirma)
            .filter { !Self.silenciados.contains($0.id) }
    }

    /// Resolver actúa sobre EL DATO, no sobre una lista. Aprobar un movimiento
    /// le quita la marca de pendiente, y entonces la alerta deja de calcularse
    /// sola — no hay que borrarla de ningún sitio.
    func resolver(id: String) async {
        guard let m = await movimiento(de: id) else {
            Self.silenciados.insert(id)
            return
        }
        if id.hasSuffix("-\(RevisionTipo.vistoBueno.rawValue)") {
            var actualizado = m
            actualizado.marcadoPendiente = false
            try? await movimientos.actualizar(actualizado)
        } else {
            // Las demás se arreglan en otra pantalla (adjuntar el comprobante,
            // poner la categoría) y desaparecen al arreglarse. Marcar "ya lo
            // miré" es lo único que cabe aquí.
            Self.silenciados.insert(id)
        }
    }

    func resolverTodos(tipos: Set<RevisionTipo>) async {
        for r in await asuntos() where tipos.contains(r.tipo) && !r.archivado {
            await resolver(id: r.id)
        }
    }

    func restaurar(_ r: Revision) async { Self.silenciados.remove(r.id) }

    /// Editar toca el movimiento de verdad; la bandeja se recalcula después.
    func actualizar(_ r: Revision) async {
        guard var m = await movimiento(de: r.id) else { return }
        if let cat = r.editCategoria, !cat.isEmpty { m.categoria = cat }
        try? await movimientos.actualizar(m)
    }

    /// El id de un asunto de movimiento es "tx-<id del movimiento>-<tipo>".
    private func movimiento(de asuntoId: String) async -> Movimiento? {
        let partes = asuntoId.split(separator: "-", maxSplits: 2).map(String.init)
        guard partes.count == 3, partes[0] == "tx" else { return nil }
        let todos = ((try? await movimientos.lista(tipo: .ingreso)) ?? [])
            + ((try? await movimientos.lista(tipo: .gasto)) ?? [])
        return todos.first { $0.id == partes[1] }
    }
}

/// El repositorio de la bandeja que usa la app. En modo revisión también se
/// calcula: los datos de ejemplo son movimientos y cortes de verdad, así que la
/// bandeja sale de ellos igual que en producción.
func repositorioRevisar() -> RevisarRepository { RevisarCalculado() }
