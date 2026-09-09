import Foundation
import GRDB

protocol CartasRepository {
    func emitidas() async throws -> [CartaEmitida]
    /// Alta o edición: lo que llega es la carta entera. No existía, y por eso
    /// emitir una carta solo la metía en un array del view model.
    func guardar(_ c: CartaEmitida) async throws
    func eliminar(id: String) async throws
    /// **El folio lo decide el repositorio, no la pantalla.** Estaba en el
    /// ViewModel, contando de la lista que tuviera cargada y con OTRO formato
    /// —"2026-014" frente al `CAR-2026-0014` del web—, así que la misma iglesia
    /// llevaba dos series de folios y la del teléfono no veía las cartas
    /// emitidas desde el escritorio: contaba solo las suyas.
    ///
    /// Es la misma razón por la que el registro se anota aquí: emitir una carta
    /// desde otro sitio tiene que numerarla igual.
    func siguienteFolio(fecha: Date) async -> String
}

/// `CAR-2026-0007`. **El formato es el del web** (`nextFolio` en su `db.ts`):
/// prefijo, año de la fecha de emisión y cuatro dígitos.
enum FolioCarta {
    static let prefijo = "CAR"

    static func texto(anio: String, seq: Int) -> String {
        "\(prefijo)-\(anio)-\(String(format: "%04d", seq))"
    }

    /// `"P-6"`. El que lleva una carta que todavía no ha subido. La marca es la
    /// misma que la de los movimientos: quien lo vea sabe que ese número aún no
    /// es el suyo, y por eso no se imprime.
    static func provisional(seq: Int) -> String { "P-\(seq)" }

    /// El número de un folio provisional. **Cuenta para el siguiente**: sin
    /// esto, dos borradores sin subir salían los dos "P-1" y en la lista no se
    /// distinguían. Lo cazó una prueba, no la pantalla.
    static func seqProvisional(de folio: String) -> Int? {
        guard folio.hasPrefix("P-") else { return nil }
        return Int(folio.dropFirst(2))
    }

    /// El número de un folio de ese año, o `nil` si no lo es. Con esto, contar
    /// mira TODAS las cartas de la iglesia —las que subió el escritorio
    /// incluidas—, que es lo que evita repetir número.
    static func seq(de folio: String, anio: String) -> Int? {
        let esperado = "\(prefijo)-\(anio)-"
        guard folio.hasPrefix(esperado) else { return nil }
        return Int(folio.dropFirst(esperado.count))
    }
}

extension CartasRepository {
    /// El siguiente libre del año, contado de las cartas que ya existen. La
    /// cuenta es idéntica a la del web —`MAX(seq) + 1` del año— y por eso vive
    /// en la extensión del protocolo: no es algo que cada implementación deba
    /// repetir a su manera.
    func siguienteFolio(_ emitidas: [CartaEmitida], fecha: Date) -> String {
        let anio = String(Fechas.claveDia(fecha).prefix(4))
        let maximo = emitidas.compactMap { FolioCarta.seq(de: $0.folio, anio: anio) }.max() ?? 0
        return FolioCarta.texto(anio: anio, seq: maximo + 1)
    }
}

struct MockCartasRepository: CartasRepository {
    func emitidas() async throws -> [CartaEmitida] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        // Lo emitido en esta sesión primero.
        return Self.añadidas.reversed() + Self.semilla
    }

    func guardar(_ c: CartaEmitida) async throws {
        Self.añadidas.removeAll { $0.id == c.id }
        Self.añadidas.append(c)
    }

    func siguienteFolio(fecha: Date) async -> String {
        siguienteFolio((try? await emitidas()) ?? [], fecha: fecha)
    }

    func eliminar(id: String) async throws {
        Self.añadidas.removeAll { $0.id == id }
    }

    nonisolated(unsafe) private static var añadidas: [CartaEmitida] = []

    /// El año es el corriente para que la maqueta no envejezca, como pasó con
    /// los compromisos del hub.
    private static var semilla: [CartaEmitida] {
        let año = Calendar.current.component(.year, from: Date())
        return [
            CartaEmitida(id: "1", folio: FolioCarta.texto(anio: String(año), seq: 1), tipo: .traslado,
                         fechaEmision: "\(año)-08-20",
                         lugarEmision: "Monterrey, Nuevo León",
                         destinatarioTipo: "iglesia",
                         destinatarioNombre: "Javier Medina Cruz",
                         asunto: L.t("Carta de traslado", "Transfer letter"),
                         estado: "emitida"),
            CartaEmitida(id: "2", folio: FolioCarta.texto(anio: String(año), seq: 2), tipo: .certificadoMiembro,
                         fechaEmision: "\(año)-08-28",
                         lugarEmision: "Monterrey, Nuevo León",
                         destinatarioTipo: "miembro",
                         destinatarioNombre: "Ana Lucía Torres",
                         asunto: L.t("Constancia de membresía", "Membership certificate"),
                         estado: "emitida"),
        ]
    }
}

/// Las cartas de verdad: tabla `carta` de la base local, y de ahí a
/// `public.cartas` por el motor de sincronización.
struct OfflineCartasRepository: CartasRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func emitidas() async throws -> [CartaEmitida] {
        try await cola.read { db in
            try CartaFila
                .filter(Column("borrado") == false)
                .order(Column("fechaEmision").desc)
                .fetchAll(db)
                .map(Self.aCarta)
        }
    }

    func guardar(_ c: CartaEmitida) async throws {
        let previa = try await cola.read { db in try CartaFila.fetchOne(db, key: c.id) }
        try await cola.write { db in
            try Self.aFila(c, previa: previa).save(db)
            try Self.encolar(db, id: c.id, operacion: previa == nil ? .crear : .actualizar)
        }
        // **El registro se anota aquí y no en la pantalla.** Emitir una carta
        // desde otro sitio —el iPad, un flujo nuevo— tiene que dejar el mismo
        // rastro. Y solo al PASAR a emitida: guardar dos veces una carta ya
        // emitida no es emitirla dos veces.
        if c.estado == "emitida" && previa?.estado != "emitida" {
            // `destinatario`, no `nombre`: las claves de `datos` las lee
            // también el web, y allí la frase pide esa. Ver `SUCESOS` en su
            // `src/db.ts`.
            await anotarSuceso(.cartaEmitida, ["folio": c.folio,
                                               "destinatario": c.destinatarioNombre])
        }
    }

    /// **Un folio PROVISIONAL, porque el bueno lo da el servidor.**
    ///
    /// Contarlo aquí es lo que hizo nacer cuatro actas con el mismo folio: dos
    /// aparatos sin sincronizar calculan el mismo número. El definitivo lo
    /// entrega el contador de Postgres al subir, en un solo statement, y hasta
    /// entonces la carta lleva este —marcado con "P-", como los movimientos—
    /// que se ve y no se imprime.
    ///
    /// Se cuentan también las borradas: su número se emitió y está citado.
    func siguienteFolio(fecha: Date) async -> String {
        let anio = String(Fechas.claveDia(fecha).prefix(4))
        let maximo = (try? await cola.read { db in
            let folios = try String.fetchAll(db, sql: "select folio from carta")
            // Los definitivos del año y los provisionales que esperan turno:
            // el siguiente tiene que ir por delante de los dos.
            return folios.compactMap {
                FolioCarta.seq(de: $0, anio: anio) ?? FolioCarta.seqProvisional(de: $0)
            }.max()
        }) ?? nil
        return FolioCarta.provisional(seq: (maximo ?? 0) + 1)
    }

    func eliminar(id: String) async throws {
        try await cola.write { db in
            guard var fila = try CartaFila.fetchOne(db, key: id) else { return }
            fila.borrado = true
            try fila.update(db)
            try Self.encolar(db, id: id, operacion: .eliminar)
        }
    }

    // MARK: - Traducción

    static func aCarta(_ f: CartaFila) -> CartaEmitida {
        CartaEmitida(id: f.id,
                     folio: f.folio,
                     // Por la CLAVE del web, no por el nombre del `case`:
                     // `constanciaActivo`, `constanciaServicio` y
                     // `certificacion` no coinciden. Ver `TipoPlantilla.clave`.
                     tipo: TipoPlantilla(clave: f.tipo),
                     fechaEmision: f.fechaEmision,
                     lugarEmision: f.lugarEmision,
                     destinatarioTipo: f.destinatarioTipo,
                     destinatarioNombre: f.destinatarioNombre,
                     destinatarioDireccion: f.destinatarioDireccion,
                     asunto: f.asunto,
                     saludo: f.saludo,
                     cuerpo: f.cuerpoHtml,
                     despedida: f.despedida,
                     firmas: Self.firmas(f.firmas),
                     observaciones: f.observaciones,
                     estado: f.estado,
                     entregadaA: f.entregadaA,
                     fechaEntrega: f.fechaEntrega)
    }

    /// **Una carta nueva nace con folio provisional**; una que se edita conserva
    /// lo que ya tuviera. Las que bajan del servidor llegan con el suyo bueno y
    /// no pasan por aquí.
    static func aFila(_ c: CartaEmitida, previa: CartaFila?) -> CartaFila {
        CartaFila(id: c.id,
                  folio: c.folio,
                  tipo: c.tipo.clave,
                  fechaEmision: c.fechaEmision,
                  lugarEmision: c.lugarEmision,
                  miembroId: previa?.miembroId,
                  destinatarioTipo: c.destinatarioTipo,
                  destinatarioNombre: c.destinatarioNombre,
                  destinatarioDireccion: c.destinatarioDireccion,
                  asunto: c.asunto,
                  saludo: c.saludo,
                  cuerpoHtml: c.cuerpo,
                  despedida: c.despedida,
                  firmas: Self.jsonFirmas(c.firmas),
                  observaciones: c.observaciones,
                  estado: c.estado,
                  // El historial lo lleva el web; aquí no se toca para no
                  // borrarlo al reeditar una carta que vino de allá.
                  historialEstados: previa?.historialEstados ?? "[]",
                  entregadaA: c.entregadaA,
                  fechaEntrega: c.fechaEntrega,
                  actualizadoEn: previa?.actualizadoEn,
                  borrado: false,
                  // Nueva: el folio que lleva es el provisional. Editada:
                  // conserva lo que tuviera, que puede ser un folio ya bueno.
                  folioProvisional: previa?.folioProvisional ?? true)
    }

    /// **La firma del web es un objeto**, con nombre y cargo; el iOS solo pide
    /// el nombre. Se leen los dos y se escribe el nombre con el cargo vacío,
    /// igual que con los acuerdos de las actas.
    private struct FirmaJSON: Codable {
        var nombre: String
        var cargo: String = ""
    }

    static func firmas(_ json: String) -> [String] {
        guard let d = json.data(using: .utf8) else { return [] }
        if let v = try? JSONDecoder().decode([FirmaJSON].self, from: d) { return v.map(\.nombre) }
        // Una fila vieja puede traer una lista de cadenas.
        return (try? JSONDecoder().decode([String].self, from: d)) ?? []
    }

    static func jsonFirmas(_ nombres: [String]) -> String {
        let v = nombres.map { FirmaJSON(nombre: $0) }
        guard let d = try? JSONEncoder().encode(v),
              let s = String(data: d, encoding: .utf8) else { return "[]" }
        return s
    }

    private static func encolar(_ db: Database, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        let previa = try OperacionPendiente
            .filter(Column("entidad") == "carta" && Column("registroId") == id)
            .fetchOne(db)
        let efectiva: OperacionPendiente.Operacion =
            (previa?.operacion == OperacionPendiente.Operacion.crear.rawValue
             && operacion == .actualizar) ? .crear : operacion
        try OperacionPendiente
            .filter(Column("entidad") == "carta" && Column("registroId") == id)
            .deleteAll(db)
        var nueva = OperacionPendiente(id: nil, entidad: "carta", registroId: id,
                                       operacion: efectiva.rawValue,
                                       creadoEn: previa?.creadoEn ?? Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}

// MARK: - Las plantillas

/// Una plantilla de carta, como la guarda el web.
/// **Las `{{variables}}` de una plantilla, sustituidas.** Reflejo de
/// `aplicarVariables` y `contextoDe` de `services/cartas/plantillas.ts` del web:
/// mismas quince claves, misma expresión regular y —lo que más importa— la
/// misma regla para las que no tienen valor.
///
/// **Una variable sin valor se deja A LA VISTA.** No se borra ni se cambia por
/// un hueco: el web lo decidió así para que quien redacta note qué falta antes
/// de firmar, y una carta que dice `{{iglesia_destino}}` es menos peligrosa que
/// una que dice "a la congregación " y se firma igual.
///
/// **Esto no existía.** El cuerpo de una plantilla de la iglesia llega del web
/// con sus variables dentro, `cuerpoLlano` las conserva a propósito —el editor
/// del iPhone es de texto llano— y el comentario que lo explica decía que "las
/// sustituye quien imprime". No las sustituía nadie: ni la vista previa ni el
/// PDF. Al llenar "Nombre del miembro" con "Jose", la carta seguía diciendo
/// "We certify that {{miembro_nombre}} is an active member of
/// {{iglesia_nombre}}". Lo vio Iván en su iPhone, con una carta de verdad.
enum VariablesCarta {

    /// Las quince del web, en su orden. Están escritas aquí para que se vea qué
    /// se puede poner en una plantilla; el `switch` de abajo es quien las llena.
    static let claves = [
        "iglesia_nombre", "iglesia_direccion", "iglesia_telefono", "iglesia_correo",
        "ciudad", "fecha_actual", "miembro_nombre", "fecha_membresia",
        "estado_membresia", "iglesia_destino", "iglesia_procedencia",
        "pastor_nombre", "secretaria_nombre", "numero_documento", "fecha_emision",
    ]

    /// Sustituye `{{clave}}` por su valor; deja intacta la que no lo tenga.
    static func aplicar(_ texto: String, _ contexto: [String: String]) -> String {
        guard texto.contains("{{") else { return texto }
        // La misma expresión que el web: admite espacios dentro de las llaves.
        guard let re = try? NSRegularExpression(pattern: "\\{\\{\\s*([a-z_]+)\\s*\\}\\}") else { return texto }
        var salida = texto
        let ns = texto as NSString
        // De atrás hacia delante, para que los rangos no se muevan al sustituir.
        for m in re.matches(in: texto, range: NSRange(location: 0, length: ns.length)).reversed() {
            let clave = ns.substring(with: m.range(at: 1))
            guard let valor = contexto[clave], !valor.isEmpty else { continue }
            let r = Range(m.range, in: salida)!
            salida.replaceSubrange(r, with: valor)
        }
        return salida
    }
}

struct Plantilla: Identifiable, Hashable {
    let id: String
    let nombre: String
    let tipo: TipoPlantilla
    var asunto: String = ""
    var saludo: String = ""
    /// **En HTML y con variables `{{miembro_nombre}}`**, tal como llega. No se
    /// interpreta al guardar: el web lo escribe así y lo imprime así.
    var cuerpoHtml: String = ""
    var despedida: String = ""
    var predeterminada: Bool = false

    /// El cuerpo en texto llano, que es lo que el editor del iPhone sabe
    /// enseñar. **Se pierde el formato a propósito**: meter HTML crudo en un
    /// `TextField` sería peor que quitarlo, y un editor de texto con formato
    /// es otra pantalla. Las variables se dejan como están —quien redacta las
    /// reconoce— y las sustituye quien imprime.
    var cuerpoLlano: String {
        var t = cuerpoHtml
        for (etiqueta, corte) in [("</p>", "\n\n"), ("<br>", "\n"), ("<br/>", "\n"),
                                  ("<br />", "\n"), ("</div>", "\n")] {
            t = t.replacingOccurrences(of: etiqueta, with: corte)
        }
        t = t.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

protocol PlantillasRepository {
    func lista() async -> [Plantilla]
}

/// La maqueta las deriva del `enum`, que es de donde salían antes: sin sesión
/// no hay base de la que leerlas y la pantalla tiene que enseñar algo.
struct MockPlantillasRepository: PlantillasRepository {
    func lista() async -> [Plantilla] {
        TipoPlantilla.allCases.map {
            Plantilla(id: $0.rawValue, nombre: $0.titulo, tipo: $0)
        }
    }
}

/// **Las de la iglesia.** Solo bajan: el iPhone todavía no crea ni edita
/// plantillas, así que no hay `subirPlantilla` —escribir código de subida para
/// algo que nadie puede cambiar es código que nunca se ejecuta y que nadie
/// prueba—. Se editan en el web y llegan aquí.
struct OfflinePlantillasRepository: PlantillasRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func lista() async -> [Plantilla] {
        (try? await cola.read { db in
            try PlantillaFila
                .filter(Column("borrado") == false && Column("activa") == true)
                .order(Column("nombre").asc)
                .fetchAll(db)
                .map {
                    Plantilla(id: $0.id, nombre: $0.nombre,
                              tipo: TipoPlantilla(clave: $0.tipo),
                              asunto: $0.asunto, saludo: $0.saludo,
                              cuerpoHtml: $0.cuerpoHtml, despedida: $0.despedida,
                              predeterminada: $0.predeterminada)
                }
        }) ?? []
    }
}

/// Maqueta sin sesión, base con ella. **Y maqueta también si la base todavía
/// no las ha bajado**: una pantalla de cartas sin ninguna plantilla no es
/// utilizable, y la primera sincronización puede tardar.
func repositorioPlantillas() -> PlantillasRepository {
    ModoRevision.sinLogin ? MockPlantillasRepository() : OfflinePlantillasRepository()
}

/// Maqueta sin sesión, base con ella.
func repositorioCartas() -> CartasRepository {
    ModoRevision.sinLogin ? MockCartasRepository() : OfflineCartasRepository()
}
