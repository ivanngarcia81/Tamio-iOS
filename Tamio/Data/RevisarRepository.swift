import Foundation

protocol RevisarRepository {
    func asuntos() async -> [Revision]
    /// Visto bueno: el movimiento pasa a `aprobado` y cuenta en los totales.
    func aprobar(id: String) async
    /// Devolver al tesorero: pasa a `rechazado` y deja de contar en el mes. No
    /// se borra —se conserva con su historial—, que es justo la diferencia
    /// entre devolver y eliminar.
    func devolver(id: String) async
    /// Aprueba de golpe **solo los que esperan visto bueno**. No existe un
    /// "resuélvelo todo": un duplicado o un gasto sin comprobante no se aprueban
    /// en bloque, que es justo lo que su bandera está pidiendo.
    func aprobarPendientes() async
    /// Reactiva a un aportante dado de baja.
    func reactivarMiembro(id: String) async
    /// Deshace lo último: el movimiento vuelve a esperar visto bueno.
    func revertir(_ r: Revision) async
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

        return CalculadoraRevisiones.calcular(movimientos: movs,
                                              archivados: (await bajas) ?? [],
                                              cortesSinFirma: sinFirma)
    }

    /// **Cada acción escribe en el dato, y el aviso desaparece porque deja de
    /// calcularse.** No hay ninguna lista que tachar ni ningún "ya lo miré":
    /// mientras el hueco siga ahí, el aviso vuelve — que es el punto.
    func aprobar(id: String) async { await cambiar(id, a: .aprobado) }
    func devolver(id: String) async { await cambiar(id, a: .rechazado) }
    func revertir(_ r: Revision) async { await cambiar(r.id, a: .pendiente) }

    private func cambiar(_ asuntoId: String, a estado: EstadoRevision) async {
        guard var m = await movimiento(de: asuntoId) else { return }
        m.estadoRevision = estado
        try? await movimientos.actualizar(m)
    }

    func aprobarPendientes() async {
        for r in await asuntos() where r.tipo == .vistoBueno {
            await aprobar(id: r.id)
        }
    }

    func reactivarMiembro(id: String) async {
        // El id del asunto es "m-<id del aportante>-archivado".
        let partes = id.split(separator: "-").map(String.init)
        guard partes.count >= 2, partes[0] == "m" else { return }
        guard let a = try? await miembros.lista(filtro: .bajas)
            .first(where: { $0.id == partes[1] }) else { return }
        var vivo = a
        vivo.estado = .activo
        try? await miembros.actualizar(vivo)
    }

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
        return try? await movimientos.porId(partes[1])
    }
}

/// El repositorio de la bandeja que usa la app. En modo revisión también se
/// calcula: los datos de ejemplo son movimientos y cortes de verdad, así que la
/// bandeja sale de ellos igual que en producción.
func repositorioRevisar() -> RevisarRepository { RevisarCalculado() }
