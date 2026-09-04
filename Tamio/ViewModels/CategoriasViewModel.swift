import Foundation
import Observation

/// Estado de Ajustes → Categorías, compartido por iPhone e iPad.
///
/// Es un singleton por la misma razón que el de la iglesia: las categorías que
/// se crean aquí las tienen que ver los formularios de alta, los filtros y los
/// reportes. Si cada pantalla cargara las suyas, crear una categoría en Ajustes
/// no aparecería en "Nuevo gasto" hasta relanzar la app.
///
/// Además es quien alimenta `Catalogos.personalizadas`, que es de donde salen
/// las opciones de los `Picker`. Ese empujón se hace en un solo sitio, aquí, y
/// no en cada pantalla: un catálogo que cada vista rellena a su manera es
/// exactamente el problema que `Catalogos` nació para resolver.
@Observable
final class CategoriasViewModel {

    static let compartido = CategoriasViewModel()

    private(set) var personalizadas: [CategoriaCustom] = []
    /// Cuántos movimientos usan cada categoría, por *cubo*: `clave:diezmo`
    /// para las de fábrica, `custom:<id>` para las de la iglesia.
    ///
    /// **Se cuenta, no se escribe.** Ajustes enseñaba números a mano —"Diezmo:
    /// 9 movimientos", "Ofrenda: 4"— que no salían de ningún sitio y que además
    /// no coincidían entre el iPhone y el iPad. Un número inventado en una
    /// pantalla de contabilidad se lo cree quien lo lee.
    private(set) var conteos: [String: Int] = [:]
    /// Categorías que aparecen en movimientos ya capturados y no están ni en
    /// el catálogo ni entre las de la iglesia: la semilla trae "Fondo de
    /// construcción", y una iglesia que venga de la app web puede traer las
    /// suyas. Se enseñan aparte para que la suma de la pantalla cuadre con los
    /// movimientos que hay; si no, esos quedan contados en ninguna fila.
    private(set) var sueltas: [String: [String: Int]] = [:]
    private(set) var cargadas = false

    private let repo = repositorioCategorias()

    private init() {}

    // MARK: - Lectura

    @MainActor
    func cargar() async {
        personalizadas = (try? await repo.lista()) ?? []
        Catalogos.personalizadas = personalizadas
        await recontar()
        cargadas = true
    }

    /// Las de una pestaña, de fábrica primero y las de la iglesia después, cada
    /// una con su color y su cuenta. Es lo único que necesita la pantalla.
    struct FilaCategoria: Identifiable {
        let id: String
        let nombre: String
        let clave: CategoriaClave?
        let colorHex: String?
        let movimientos: Int
        /// Las integradas no se pueden borrar ni renombrar: son el vocabulario
        /// común, y cambiarlo aquí dejaría los reportes de dos iglesias sin
        /// comparar.
        let deFabrica: Bool
        /// La categoría de la iglesia, cuando la fila es suya.
        let custom: CategoriaCustom?
        /// Está en movimientos pero en ningún catálogo. No se puede borrar
        /// —borrar qué— ni renombrar, pero tiene que verse.
        var huerfana = false
    }

    func filas(_ tipo: TipoMovimiento) -> [FilaCategoria] {
        let fabrica = Catalogos.catalogo(tipo).map { c in
            FilaCategoria(id: "fabrica-\(c.clave.rawValue)",
                          nombre: c.etiqueta,
                          clave: c.clave,
                          colorHex: nil,
                          movimientos: conteos["\(clave(tipo)):clave:\(c.clave.rawValue)"] ?? 0,
                          deFabrica: true,
                          custom: nil)
        }
        let propias = personalizadas
            .filter { $0.tipo == tipo }
            .sorted { $0.nombre.localizedCaseInsensitiveCompare($1.nombre) == .orderedAscending }
            .map { c in
                FilaCategoria(id: c.id,
                              nombre: c.nombre,
                              clave: nil,
                              colorHex: c.color,
                              movimientos: conteos["\(clave(tipo)):custom:\(c.id)"] ?? 0,
                              deFabrica: false,
                              custom: c)
            }
        let huerfanas = (sueltas[clave(tipo)] ?? [:])
            .sorted { $0.key < $1.key }
            .map { etiqueta, n in
                FilaCategoria(id: "huerfana-\(etiqueta)",
                              nombre: etiqueta,
                              clave: nil,
                              colorHex: nil,
                              movimientos: n,
                              deFabrica: false,
                              custom: nil,
                              huerfana: true)
            }
        return fabrica + propias + huerfanas
    }

    private func clave(_ tipo: TipoMovimiento) -> String {
        tipo == .ingreso ? "ingreso" : "gasto"
    }

    // MARK: - Escritura

    @MainActor
    func crear(nombre: String, tipo: TipoMovimiento) async {
        let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty, !existe(limpio, tipo: tipo) else { return }
        // El color se reparte en orden por la paleta en vez de sortearse: dos
        // categorías creadas seguidas con el mismo color se distinguen peor que
        // dos con colores contiguos, y un color al azar puede repetir el de la
        // de al lado.
        let color = CategoriaCustom.paleta[personalizadas.count % CategoriaCustom.paleta.count]
        let nueva = CategoriaCustom(tipo: tipo, nombre: limpio, color: color)
        try? await repo.crear(nueva)
        await cargar()
    }

    @MainActor
    func renombrar(_ c: CategoriaCustom, a nombre: String) async {
        let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty, limpio != c.nombre, !existe(limpio, tipo: c.tipo) else { return }
        var copia = c
        copia.nombre = limpio
        try? await repo.actualizar(copia)
        await cargar()
    }

    @MainActor
    func eliminar(_ c: CategoriaCustom) async {
        try? await repo.eliminar(id: c.id)
        await cargar()
    }

    /// Ya existe con ese nombre, sea de fábrica o de la iglesia. Se compara
    /// normalizado: "cafeteria" y "Cafetería" serían dos filas y un mismo gasto
    /// repartido entre las dos.
    func existe(_ nombre: String, tipo: TipoMovimiento) -> Bool {
        let n = Catalogos.normalizar(nombre)
        return Catalogos.categorias(tipo).contains { Catalogos.normalizar($0) == n }
    }

    // MARK: - Conteo

    @MainActor
    private func recontar() async {
        let repoMov = repositorioMovimientos()
        var tabla: [String: Int] = [:]
        var perdidas: [String: [String: Int]] = [:]
        for tipo in [TipoMovimiento.ingreso, .gasto] {
            let movs = (try? await repoMov.lista(tipo: tipo)) ?? []
            for m in movs {
                let c = cubo(de: m.categoria)
                tabla["\(clave(tipo)):\(c)", default: 0] += 1
                if c.hasPrefix("suelta:") {
                    perdidas[clave(tipo), default: [:]][m.categoria, default: 0] += 1
                }
            }
        }
        conteos = tabla
        sueltas = perdidas
    }

    /// A qué fila de la pantalla pertenece una categoría guardada.
    ///
    /// No basta con comparar el texto. `Movimiento.categoria` guarda la
    /// etiqueta ya resuelta por `L.t`, así que un gasto capturado con la app en
    /// inglés dice "Tithe" y en español no coincidiría con "Diezmo": la fila
    /// saldría en cero y el movimiento no se contaría en ninguna parte. Para
    /// eso está `Catalogos.clave`, que reconoce las dos formas.
    ///
    /// **Las de la iglesia se miran primero.** Una llamada "Ofrenda de cumpleaños"
    /// se parece bastante a "Ofrenda" como para que la búsqueda por raíces la
    /// reclamara, y entonces sus movimientos se contarían en la integrada y su
    /// propia fila diría cero.
    private func cubo(de etiqueta: String) -> String {
        let n = Catalogos.normalizar(etiqueta)
        if let propia = personalizadas.first(where: { Catalogos.normalizar($0.nombre) == n }) {
            return "custom:\(propia.id)"
        }
        if let clave = Catalogos.clave(deEtiqueta: etiqueta) {
            return "clave:\(clave.rawValue)"
        }
        return "suelta:\(n)"
    }
}
