import Foundation
import SwiftUI

/// **Una categoría que se inventó la iglesia.**
///
/// El catálogo de `Catalogos` es fijo y viene con la app: sirve para que dos
/// iglesias distintas no llamen "Servicios" y "Utilidades" a lo mismo. Pero
/// ninguna congregación cabe entera en una lista escrita por otro, y por eso
/// existe esta tabla —`categorias_custom` en Supabase, con datos desde antes
/// de que la app de iPhone existiera— y la pantalla de Ajustes → Categorías.
///
/// Es un tipo aparte y no una `Catalogos.Categoria` porque le falta lo que
/// define a aquellas: **una clave independiente del idioma**. Las del catálogo
/// existen en español y en inglés y se reconocen en los dos; esta tiene el
/// nombre que alguien escribió, y ese nombre es su identidad. Por eso el color
/// se guarda —no se puede derivar de una clave que no hay— y por eso una
/// personalizada nunca hereda el ícono de una integrada.
struct CategoriaCustom: Identifiable, Equatable {
    let id: String
    var tipo: TipoMovimiento
    var nombre: String
    /// Hex de seis dígitos sin almohadilla, como se guarda en la app web.
    var color: String

    init(id: String = UUID().uuidString,
         tipo: TipoMovimiento,
         nombre: String,
         color: String) {
        self.id = id
        self.tipo = tipo
        self.nombre = nombre
        self.color = color
    }

    var colorSwiftUI: Color { Color(hexTexto: color) ?? Paleta.brand }

    /// Los colores que se ofrecen al crear una. Son los mismos que usa la app
    /// web, para que una categoría creada allí y otra creada aquí no se vean
    /// de dos familias distintas en la misma lista.
    static let paleta: [String] = [
        "1A7F37", "7C3AED", "0E6BA8", "A3123A", "1D4ED8",
        "0F766E", "A44A00", "5B21EC", "A03412", "0369A1",
        "4B5563", "B45309",
    ]
}
