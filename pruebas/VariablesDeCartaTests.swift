import XCTest
@testable import Tamio

/// **Las `{{variables}}` de una carta: lo que se sustituye, y lo que se avisa.**
///
/// Son las dos mitades de una misma decisión, del 21 de septiembre: una
/// variable sin valor se sustituye por NADA —el web la deja a la vista y aquí
/// no— y, justo porque el hueco deja de verse, el aviso lo tiene que dar la
/// pantalla antes de guardar. Se prueban juntas a propósito: separadas, cada
/// una parece arbitraria.
///
/// El caso de verdad está en la base de su iglesia y es lo que hizo falta esto:
/// `CAR-2026-0008` se guardó diciendo *"has been a member of Iglesia de prueba
/// since  and has requested their transfer"*. Se lee entera y no hay forma de
/// sospechar, mirándola, que le faltan dos datos.
@MainActor
final class VariablesDeCartaTests: XCTestCase {

    /// `fecha_membresia` viene con espacios: es la trampa. Una clave que existe
    /// en el contexto y trae blancos imprime lo mismo que una que no existe.
    private let contexto = [
        "miembro_nombre": "Ana Torres",
        "iglesia_nombre": "Iglesia de prueba",
        "fecha_membresia": "   ",
    ]

    func testSustituyeLaQueTieneValor() {
        let salida = VariablesCarta.aplicar("Certificamos que {{miembro_nombre}} es miembro.", contexto)
        XCTAssertEqual(salida, "Certificamos que Ana Torres es miembro.")
    }

    /// La decisión, escrita como prueba: **no se quedan las llaves**. Una carta
    /// que sale impresa diciendo `{{iglesia_destino}}` no se puede entregar.
    func testLaQueNoTieneValorNoImprimeLasLlaves() {
        let salida = VariablesCarta.aplicar("La encomendamos a {{iglesia_destino}}.", contexto)
        XCTAssertEqual(salida, "La encomendamos a .")
        XCTAssertFalse(salida.contains("{{"))
    }

    /// Y el precio de esa decisión, también escrito: el hueco no se ve.
    ///
    /// **Y el valor en blancos es el mismo caso que el valor ausente.**
    /// `aplicar` escribe lo que haya —tres espacios, aquí— y en el papel eso es
    /// exactamente igual de invisible que no escribir nada; por eso
    /// `faltantes` cuenta las dos. Si contara solo las ausentes, la carta que
    /// más engaña —la que trae el campo con espacios— se emitiría sin aviso.
    func testElHuecoNoSeVeYPorEsoHaceFaltaElAviso() {
        let plantilla = "Ha sido miembro desde {{fecha_membresia}} y solicita su traslado."
        XCTAssertEqual(VariablesCarta.aplicar(plantilla, contexto),
                       "Ha sido miembro desde     y solicita su traslado.",
                       "los tres espacios del contexto más el que ya llevaba la frase")
        XCTAssertEqual(VariablesCarta.faltantes(en: [plantilla], contexto: contexto),
                       ["fecha_membresia"],
                       "en blancos cuenta como vacía: en el papel se lee igual")
    }

    func testFaltantesNombraSoloLasQueSalenEnBlanco() {
        let faltan = VariablesCarta.faltantes(
            en: ["Certificamos que {{miembro_nombre}} es miembro de {{iglesia_nombre}}",
                 "desde {{fecha_membresia}}, y la encomendamos a {{iglesia_destino}}."],
            contexto: contexto)
        XCTAssertEqual(faltan, ["fecha_membresia", "iglesia_destino"],
                       "las dos que tienen valor no se nombran")
    }

    /// **En el orden del texto y sin repetir.** El aviso se lee en voz de
    /// frase —"la fecha de membresía y la iglesia de destino"—, así que una
    /// repetida lo rompe y el orden importa.
    func testNoRepiteYSigueElOrdenDelTexto() {
        let faltan = VariablesCarta.faltantes(
            en: ["{{iglesia_destino}} recibe a quien fue miembro desde {{fecha_membresia}}",
                 "y lo encomendamos a {{iglesia_destino}}."],
            contexto: contexto)
        XCTAssertEqual(faltan, ["iglesia_destino", "fecha_membresia"])
    }

    func testUnTextoSinVariablesNoDaNada() {
        XCTAssertEqual(VariablesCarta.faltantes(en: ["Sin llaves ninguna."], contexto: contexto), [])
    }

    /// **La lista de las que no tienen dónde llenarse se DERIVA, no se opina.**
    ///
    /// Con la carta entera escrita y la ficha de la iglesia entera puesta, las
    /// únicas que siguen vacías tienen que ser exactamente `sinOrigen`. Si
    /// alguien le añade una clave a `contextoVariables` y se olvida de quitarla
    /// de ahí, el aviso mandaría a quitar del cuerpo una variable que ya
    /// funciona — y esta prueba se cae antes.
    func testLasSinOrigenSonLasQueElContextoNoLlenaNunca() {
        var iglesia = ConfiguracionIglesia()
        iglesia.nombre = "Iglesia de prueba"
        iglesia.direccion = "Calle 1"
        iglesia.ciudad = "Newark"
        iglesia.telefono = "555-0000"
        iglesia.correo = "hola@ejemplo.org"
        iglesia.pastorNombre = "Pastor"
        iglesia.secretarioNombre = "Secretario"

        var carta = CartaEnEdicion()
        carta.aportante = "Ana Torres"
        carta.iglesiaDestino = "Iglesia hermana"
        carta.miembroDesde = "2018"

        let ctx = carta.contextoVariables(iglesia)
        let vacias = Set(VariablesCarta.claves.filter {
            (ctx[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
        XCTAssertEqual(vacias, VariablesCarta.sinOrigen)
    }

    /// Cada una de las quince tiene nombre propio. El caso por omisión enseña
    /// las llaves crudas, que es feo y por eso no debe tocarle a ninguna.
    func testLasQuinceTienenRotuloEnPalabras() {
        for clave in VariablesCarta.claves {
            XCTAssertFalse(VariablesCarta.rotulo(clave).contains("{{"),
                           "\(clave) se quedó sin rótulo")
        }
    }
}
