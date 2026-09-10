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
        // El id del asunto es "m-<id del aportante>-archivado", y el del
        // aportante es un UUID con guiones: ver `idDelRegistro`.
        guard let quien = Self.idDelRegistro(id, prefijo: "m") else { return }
        guard let a = try? await miembros.lista(filtro: .bajas)
            .first(where: { $0.id == quien }) else { return }
        var vivo = a
        // Se quita la baja y se conserva el registro que tenía, como hace
        // `restoreMember` en el app web.
        vivo.estado.baja = nil
        try? await miembros.actualizar(vivo)
    }

    /// **Editar toca el movimiento de verdad**; la bandeja se recalcula después.
    ///
    /// Antes escribía **solo la categoría** de los seis campos que la hoja
    /// ofrece, así que corregir el importe de un asunto —que es para lo que la
    /// bandeja existe— no hacía nada y no lo decía. Y ni la categoría llegaba,
    /// porque el `guard` del id la cortaba antes (ver `idDelRegistro`).
    ///
    /// El importe se lee con `Money.desdeTexto`, el mismo parseador que el alta:
    /// el campo de la hoja es un `.decimalPad`, y en región española eso escribe
    /// coma. Un importe que no se entiende **no se escribe**: es preferible
    /// dejar la cifra vieja que poner un cero.
    func actualizar(_ r: Revision) async {
        guard var m = await movimiento(de: r.id) else { return }
        if let cat = r.editCategoria, !cat.isEmpty {
            m.categoria = cat
            // `categoriaCompleta` es lo que leen las listas y los reportes; sin
            // esto la ficha decía "Suministros" y el reporte seguía sumando la
            // categoría vieja. Se conserva la subcategoría si la había.
            let sub = m.categoriaCompleta.contains(" · ")
                ? m.categoriaCompleta.components(separatedBy: " · ").dropFirst().joined(separator: " · ")
                : ""
            m.categoriaCompleta = sub.isEmpty ? cat : "\(cat) · \(sub)"
        }
        if let met = r.editMetodo, !met.isEmpty { m.metodo = met }
        if let nota = r.editNota { m.nota = nota.isEmpty ? nil : nota }
        if let texto = r.editImporte, let centavos = Money.desdeTexto(texto), centavos > 0 {
            m.monto = centavos
        }
        if let f = r.editFecha { m.fecha = f }
        // El aportante solo aplica a un ingreso, y `sinAsignar` significa
        // quitarlo. En un gasto la hoja ni enseña el campo.
        if m.esIngreso, let quien = r.editAportante {
            m.persona = quien.isEmpty ? nil : quien
            m.miembro = quien.isEmpty ? nil : quien
        }
        try? await movimientos.actualizar(m)
    }

    /// El id de un asunto de movimiento es `"tx-<id del movimiento>-<tipo>"`.
    private func movimiento(de asuntoId: String) async -> Movimiento? {
        guard let id = Self.idDelRegistro(asuntoId, prefijo: "tx") else { return nil }
        return try? await movimientos.porId(id)
    }

    /// **El id del registro que hay dentro del id de un asunto.**
    ///
    /// Los asuntos se identifican como `"<prefijo>-<id>-<sufijo>"` —`tx-…-vistoBueno`,
    /// `co-…-firma`, `m-…-archivado`—, y esto era un
    /// `split(separator: "-", maxSplits: 2)` que se quedaba con `partes[1]`.
    ///
    /// **Con los ids de la maqueta —"1", "207"— eso funciona, y por eso la
    /// pantalla parecía sana en modo revisión.** Los de verdad los genera
    /// `UUID().uuidString` y traen cuatro guiones, así que `partes[1]` era el
    /// primer trozo del UUID, `porId` no encontraba nada y **todas las acciones
    /// de la bandeja se iban por el `guard` sin hacer nada y sin decirlo**:
    /// aprobar, devolver, revertir, editar y reactivar a un miembro.
    ///
    /// El prefijo y el sufijo no llevan guiones nunca —el sufijo es el
    /// `rawValue` de `RevisionTipo`, que es camelCase—, así que lo de en medio
    /// es el id entero, tenga los guiones que tenga.
    static func idDelRegistro(_ asuntoId: String, prefijo: String) -> String? {
        guard asuntoId.hasPrefix(prefijo + "-"),
              let ultimoGuion = asuntoId.lastIndex(of: "-") else { return nil }
        let inicio = asuntoId.index(asuntoId.startIndex, offsetBy: prefijo.count + 1)
        guard inicio < ultimoGuion else { return nil }
        return String(asuntoId[inicio..<ultimoGuion])
    }
}

/// El repositorio de la bandeja que usa la app. En modo revisión también se
/// calcula: los datos de ejemplo son movimientos y cortes de verdad, así que la
/// bandeja sale de ellos igual que en producción.
func repositorioRevisar() -> RevisarRepository { RevisarCalculado() }
