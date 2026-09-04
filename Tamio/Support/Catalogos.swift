import Foundation

/// **Las categorías y los métodos de pago, en un solo sitio.**
///
/// Antes cada hoja llevaba su propia lista y no coincidían: el alta ofrecía
/// "Ofrenda" donde la edición ofrecía "Ofrenda general" y "Ofrenda misionera",
/// y "Utilidades" donde la otra decía "Servicios". El mismo campo, dos
/// vocabularios según por dónde se entrara.
///
/// Peor: las del alta eran literales españoles sin `L.t`, mientras los
/// movimientos guardan el valor ya resuelto por `L.t`. Con el sistema en
/// inglés, abrir a editar un movimiento cuya categoría es "Tithe" daba un
/// `Picker` cuyas opciones eran "Diezmo", "Ofrenda"… — ninguna coincidía con la
/// selección, así que salía sin nada marcado.
///
/// En la app real esto lo alimentará Ajustes → Categorías, que es donde la
/// iglesia las crea; de momento es el catálogo del prototipo.
/// **La identidad de una categoría, independiente del idioma.**
///
/// `Movimiento.categoria` guarda la etiqueta ya resuelta por `L.t`: "Diezmo"
/// con el sistema en español, "Tithe" en inglés. Todo lo que decidía algo
/// mirando ese texto —el color y el ícono de la fila— comparaba contra
/// literales españoles (`contains("diezmo")`), así que en inglés no acertaba
/// NINGUNA rama y las nueve filas de Ingresos salían con el mismo círculo gris.
/// Es el mismo fallo que `Catalogos` ya documenta para el `Picker`, una capa
/// más abajo.
///
/// La clave rompe el vínculo: el catálogo dice qué clave es cada etiqueta, y
/// el color y el ícono se eligen por clave. La etiqueta vuelve a ser lo que
/// debe ser, texto para leer.
enum CategoriaClave: String, CaseIterable {
    // Ingreso
    case diezmo, ofrenda, misiones, eventos, donativo
    // Gasto
    case compensacion, pastores, musicos, suministros, mobiliario, limpieza
    case utilidades, mantenimiento, alimentos, tecnologia, ayudas, ayudaSocial
    case transporte, publicidad, renta, seguros, varios
    // Ambos
    case otro
}

enum Catalogos {
    /// Una entrada del catálogo: la clave manda, la etiqueta solo se lee.
    struct Categoria {
        let clave: CategoriaClave
        /// Las dos etiquetas, siempre las dos. Se guardan juntas para poder
        /// reconocer un movimiento capturado en el otro idioma.
        let es: String
        let en: String
        var etiqueta: String { L.t(es, en) }
    }

    static let catalogoIngreso: [Categoria] = [
        Categoria(clave: .diezmo,   es: "Diezmo",   en: "Tithe"),
        Categoria(clave: .ofrenda,  es: "Ofrenda",  en: "Offering"),
        Categoria(clave: .misiones, es: "Misiones", en: "Missions"),
        Categoria(clave: .eventos,  es: "Eventos",  en: "Events"),
        Categoria(clave: .donativo, es: "Donativo", en: "Donation"),
        Categoria(clave: .otro,     es: "Otro",     en: "Other"),
    ]

    static let catalogoGasto: [Categoria] = [
        Categoria(clave: .compensacion,  es: "Compensación",  en: "Compensation"),
        Categoria(clave: .pastores,      es: "Pastores",      en: "Pastors"),
        Categoria(clave: .musicos,       es: "Músicos",       en: "Musicians"),
        Categoria(clave: .suministros,   es: "Suministros",   en: "Supplies"),
        Categoria(clave: .mobiliario,    es: "Mobiliario",    en: "Furniture"),
        Categoria(clave: .limpieza,      es: "Limpieza",      en: "Cleaning"),
        Categoria(clave: .utilidades,    es: "Utilidades",    en: "Utilities"),
        Categoria(clave: .mantenimiento, es: "Mantenimiento", en: "Maintenance"),
        Categoria(clave: .alimentos,     es: "Alimentos",     en: "Food"),
        Categoria(clave: .tecnologia,    es: "Tecnología",    en: "Technology"),
        Categoria(clave: .misiones,      es: "Misiones",      en: "Missions"),
        Categoria(clave: .ayudas,        es: "Ayudas",        en: "Assistance"),
        Categoria(clave: .ayudaSocial,   es: "Ayuda social",  en: "Social aid"),
        Categoria(clave: .transporte,    es: "Transporte",    en: "Transport"),
        Categoria(clave: .publicidad,    es: "Publicidad",    en: "Advertising"),
        Categoria(clave: .renta,         es: "Renta",         en: "Rent"),
        Categoria(clave: .seguros,       es: "Seguros",       en: "Insurance"),
        Categoria(clave: .varios,        es: "Varios",        en: "Misc"),
        Categoria(clave: .otro,          es: "Otro",          en: "Other"),
    ]

    static func catalogo(_ tipo: TipoMovimiento) -> [Categoria] {
        tipo == .ingreso ? catalogoIngreso : catalogoGasto
    }

    static var categoriasIngreso: [String] { catalogoIngreso.map(\.etiqueta) }
    static var categoriasGasto: [String] { catalogoGasto.map(\.etiqueta) }

    static func categorias(_ tipo: TipoMovimiento) -> [String] {
        catalogo(tipo).map(\.etiqueta)
    }

    // MARK: - De etiqueta a clave

    /// Raíces que reconocen una categoría **escrita a mano** o heredada de
    /// otra versión del catálogo: la semilla trae "Ofrenda misionera" y
    /// "Ofrenda de gratitud", y una iglesia puede haber capturado "Servicios"
    /// cuando el catálogo llamaba así a Utilidades. El orden importa: lo más
    /// específico primero, o "Ayuda social" se resolvería como "Ayudas".
    private static let raices: [(CategoriaClave, [String])] = [
        (.ayudaSocial,   ["ayuda social", "social aid"]),
        (.diezmo,        ["diezmo", "tithe"]),
        (.ofrenda,       ["ofrenda", "offering"]),
        (.misiones,      ["mision", "mission"]),
        (.eventos,       ["evento", "event"]),
        (.donativo,      ["donativ", "donaci", "donation"]),
        (.compensacion,  ["compensa", "compensation"]),
        (.pastores,      ["pastor"]),
        (.musicos,       ["music"]),
        (.suministros,   ["suministro", "material", "suppl"]),
        (.mobiliario,    ["mobiliario", "furniture"]),
        (.limpieza,      ["limpieza", "cleaning"]),
        (.utilidades,    ["utilidad", "utilit", "servicio", "service"]),
        (.mantenimiento, ["manten", "maintenance"]),
        (.alimentos,     ["aliment", "food"]),
        (.tecnologia,    ["tecnolog", "technolog"]),
        (.ayudas,        ["ayuda", "assistance"]),
        (.transporte,    ["transport"]),
        (.publicidad,    ["publicidad", "advertis"]),
        (.renta,         ["renta", "rent"]),
        (.seguros,       ["seguro", "insurance"]),
        (.varios,        ["varios", "misc"]),
    ]

    /// Todas las etiquetas del catálogo, en los dos idiomas, con su clave.
    private static let porEtiqueta: [String: CategoriaClave] = {
        var tabla: [String: CategoriaClave] = [:]
        for c in catalogoIngreso + catalogoGasto {
            tabla[normalizar(c.es)] = c.clave
            tabla[normalizar(c.en)] = c.clave
        }
        return tabla
    }()

    /// Sin acentos, sin mayúsculas y sin espacios de sobra: "Tecnología" y
    /// "tecnologia" son la misma categoría.
    private static func normalizar(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }

    /// La etiqueta canónica de una clave, en el idioma de la app. Es con la
    /// que se rotula un grupo de categorías (la dona de Inicio), para no tener
    /// que elegir una de las variantes que la iglesia haya escrito.
    static func etiqueta(de clave: CategoriaClave) -> String {
        (catalogoIngreso + catalogoGasto).first { $0.clave == clave }?.etiqueta
            ?? clave.rawValue
    }

    /// La clave de una etiqueta guardada, venga del idioma que venga. `nil`
    /// para una categoría que la iglesia se inventó y que no se parece a
    /// ninguna del catálogo: esas son las que salen en gris, y ahora **solo**
    /// esas.
    static func clave(deEtiqueta etiqueta: String) -> CategoriaClave? {
        let n = normalizar(etiqueta)
        guard !n.isEmpty else { return nil }
        if let exacta = porEtiqueta[n] { return exacta }
        return raices.first { _, formas in formas.contains { n.contains($0) } }?.0
    }

    /// Cargos y roles de las personas de la iglesia. Iban como literales
    /// españoles dentro de los `Picker` de Ajustes, así que con la app en
    /// inglés el cuerpo del PDF salía traducido y las firmas debajo decían
    /// "Pastor / Tesorero / Secretario". Lo que la iglesia ESCRIBE en esos
    /// campos es suyo y se respeta; lo que la app OFRECE es interfaz.
    enum Cargos {
        /// "Tesorero" y "Tesorera" son la misma palabra en inglés. Sin quitar
        /// el repetido, el `ForEach(id: \.self)` del Picker tendría dos
        /// opciones con la misma identidad, que SwiftUI no sabe distinguir.
        private static func sinRepetir(_ v: [String]) -> [String] {
            var vistos = Set<String>()
            return v.filter { vistos.insert($0).inserted }
        }

        static var tesoreria: [String] {
            sinRepetir([L.t("Tesorero", "Treasurer"),
                        L.t("Tesorera", "Treasurer"),
                        L.t("Administrador", "Administrator")])
        }
        static var pastoral: [String] {
            [L.t("Pastor", "Pastor"),
             L.t("Pastor principal", "Lead pastor"),
             L.t("Pastor asociado", "Associate pastor")]
        }
        static var roles: [String] {
            [L.t("Tesorero", "Treasurer"),
             L.t("Secretaria", "Secretary"),
             L.t("Pastor", "Pastor"),
             L.t("Administrador", "Administrator")]
        }
    }

    static var metodos: [String] {
        [L.t("Efectivo", "Cash"),
         L.t("Transferencia", "Transfer"),
         L.t("Cheque", "Check"),
         L.t("Tarjeta", "Card"),
         L.t("Domiciliado", "Direct debit")]
    }

    /// Las opciones del catálogo **más el valor vigente si no está en él**. Un
    /// `Picker` solo puede mostrar marcada una selección que exista entre sus
    /// opciones: sin esto, abrir un movimiento con una categoría que ya no está
    /// en el catálogo —o escrita de otra forma, como "Ofrenda de gratitud"—
    /// dejaba el control en blanco y al guardar se perdía el valor.
    static func conValorVigente(_ opciones: [String], _ vigente: String) -> [String] {
        guard !vigente.isEmpty, !opciones.contains(vigente) else { return opciones }
        return [vigente] + opciones
    }
}
