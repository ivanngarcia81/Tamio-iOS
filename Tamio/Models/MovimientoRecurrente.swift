import Foundation

/// **La REGLA que crea movimientos, no un movimiento.**
///
/// Antes esto era un booleano suelto en `Movimiento.repiteMensual`: la hoja de
/// captura lo marcaba, el detalle escribía "Periodicidad: mensual" y ahí se
/// acababa todo. No generaba nada, y al dar una vuelta por el servidor se
/// borraba solo, porque la columna no viajaba a Supabase. Con un booleano
/// tampoco se puede saber si un recurrente VENCIÓ —"la luz se repite cada mes y
/// este mes no está"—, que era la octava regla de la bandeja: estuvo declarada
/// sin que nada la generara nunca y se quitó de allí para poder resolverla aquí.
///
/// Hacen falta dos datos que el booleano no tenía: desde qué mes se repite
/// (`mesInicio`) y cuál fue el último que ya se registró
/// (`ultimoMesGenerado`).
///
/// ## Se aparta de la app web a propósito, en un punto
///
/// La web materializa **desde enero del año de la fecha elegida** hasta el mes
/// pasado, porque asume que la iglesia ya tiene historial cargado. Una
/// instalación nueva no lo tiene: una iglesia que compra la app hoy y marca la
/// renta como recurrente se encontraría ocho rentas que nunca pagó por la app y
/// el saldo en negativo.
///
/// > **Un recurrente arranca en el MES EN QUE SE CREA y va hacia adelante.
/// > Nunca retrocede por su cuenta.** Solo se retrocede si la persona lo pide
/// > —quien importó un CSV con su historial—, eligiendo el mes de inicio a mano.
///
/// De la web sí se toma el resto de la doctrina, que está bien razonada:
/// materializar **solo meses concluidos**, **nunca meses futuros**, e
/// idempotencia por `ultimoMesGenerado` para que abrir la app dos veces no
/// genere dos rentas.
struct MovimientoRecurrente: Identifiable, Equatable {
    /// `var` por lo mismo que en `Movimiento`: se crea con uid de cliente.
    var id: String
    /// No cambia nunca: alterarlo reescribiría el historial ya generado.
    let tipo: TipoMovimiento
    var categoria: String
    var subcategoria: String?
    /// El `concepto` de Supabase, que en iOS se llama `nota` en todas partes.
    /// Es lo que se lee en la lista: "Renta del local".
    var nota: String?
    var monto: Centavos
    var metodo: String
    /// Beneficiario del gasto. En un ingreso no se usa.
    var pagadoA: String?
    var rfc: String?
    /// Día del mes en que se registra. Se ajusta en meses cortos: un
    /// recurrente del 31 cae el 28 en febrero, no se salta el mes.
    var dia: Int
    /// Primer mes a generar, `"2026-09"`. **No se edita**: cambiarlo movería
    /// movimientos ya registrados. Solo se elige al crear.
    let mesInicio: String
    /// Último mes ya registrado como movimiento, `"2026-09"`. `nil` mientras no
    /// se ha generado ninguno. Es lo que hace la operación idempotente.
    var ultimoMesGenerado: String?
    /// **Parar no es borrar.** Una renta que sube se para y se crea otra; un
    /// contrato que acaba se para y su historial se queda. Borrar la definición
    /// dejaría los movimientos ya generados sin explicación.
    var activo: Bool = true

    /// Lo que se enseña en la lista. La nota manda porque es lo que la persona
    /// escribió; si no la puso, la categoría.
    var titular: String {
        if let nota, !nota.trimmingCharacters(in: .whitespaces).isEmpty { return nota }
        return categoria
    }

    var categoriaCompleta: String {
        if let subcategoria, !subcategoria.isEmpty { return "\(categoria) · \(subcategoria)" }
        return categoria
    }
}

// MARK: - La aritmética de los meses

/// Las cuentas de calendario, aparte y **puras**, para poder comprobarlas sin
/// base de datos ni pantalla. Es la misma separación que hace la app web
/// (`mesesPendientesRecurrente`), y por el mismo motivo: aquí es donde se
/// duplican las rentas o se saltan meses, y no hay target de tests donde
/// atraparlo.
///
/// Todas las claves son `"YYYY-MM"`, que ordenan bien como texto. Por eso las
/// comparaciones son `<` y `>` sobre `String` y no hay `Date` de por medio: una
/// fecha arrastra husos horarios y un mes no los tiene.
enum MesesRecurrentes {

    /// El mes de una fecha, `"2026-09"`. Es `Fechas.clavePeriodo`, nombrado
    /// aquí para que se lea lo que significa en este contexto.
    static func mes(de fecha: Date = Date()) -> String { Fechas.clavePeriodo(fecha) }

    /// `"2026-12"` → `"2027-01"`. A mano y no con `Calendar`, porque una clave
    /// de mes no necesita zona horaria y con `Calendar` la necesitaría.
    static func siguiente(_ mes: String) -> String {
        guard let (a, m) = partes(mes) else { return mes }
        return m == 12 ? clave(a + 1, 1) : clave(a, m + 1)
    }

    /// `"2026-01"` → `"2025-12"`.
    static func anterior(_ mes: String) -> String {
        guard let (a, m) = partes(mes) else { return mes }
        return m == 1 ? clave(a - 1, 12) : clave(a, m - 1)
    }

    /// Los meses de `inicio` a `fin`, ambos incluidos. Vacío si `fin` es
    /// anterior a `inicio`, que es el caso normal de un recurrente recién
    /// creado: no le toca generar nada todavía.
    static func entre(_ inicio: String, _ fin: String) -> [String] {
        guard partes(inicio) != nil, partes(fin) != nil, inicio <= fin else { return [] }
        var salida: [String] = []
        var m = inicio
        while m <= fin {
            salida.append(m)
            m = siguiente(m)
            // Cinturón: una clave corrupta que no avance colgaría la app.
            if salida.count > 1200 { break }
        }
        return salida
    }

    /// **Qué meses le faltan a una definición, y hasta dónde marcarla.**
    ///
    /// La ventana termina en el **mes pasado**: el mes en curso no se
    /// contabiliza hasta que termina, y se registra solo la primera vez que se
    /// abre la app el mes siguiente. Nunca se generan meses futuros.
    ///
    /// `saltar` cubre el caso de marcar el interruptor sobre un movimiento que
    /// se acaba de capturar: ese mes ya está cubierto por él, así que no se
    /// vuelve a generar, pero sí se da por hecho —`marcaHasta`— para que no
    /// aparezca duplicado cuando el mes concluya.
    static func pendientes(mesInicio: String,
                           ultimoMesGenerado: String?,
                           hoy: String,
                           saltar: String? = nil) -> (meses: [String], marcaHasta: String) {
        let hasta = anterior(hoy)
        let desde = ultimoMesGenerado.map(siguiente) ?? mesInicio
        let meses = entre(desde, hasta).filter { $0 != saltar }
        // Si el mes saltado es POSTERIOR a la ventana —el caso corriente: se
        // salta el mes en curso— la marca lo incluye, o el mes que viene se
        // volvería a mirar y se generaría el que ya está capturado.
        let marca = (saltar.map { $0 > hasta } ?? false) ? saltar! : hasta
        return (meses, marca)
    }

    /// La fecha en que cae un recurrente dentro de un mes, con el día ajustado
    /// a la longitud del mes: el 31 es 28 en febrero (29 en bisiesto), 30 en
    /// abril. Se construye en UTC, igual que el resto de fechas de día de la
    /// app, para que no se corra al día anterior al oeste de Greenwich.
    static func fecha(en mes: String, dia: Int) -> Date? {
        guard let (a, m) = partes(mes) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comp = DateComponents()
        comp.year = a; comp.month = m; comp.day = 1
        guard let primero = cal.date(from: comp),
              let rango = cal.range(of: .day, in: .month, for: primero) else { return nil }
        comp.day = min(max(dia, 1), rango.count)
        // Mediodía, como la web: aleja la fecha de los bordes del día para que
        // ninguna conversión de huso la mueva de mes.
        comp.hour = 12
        return cal.date(from: comp)
    }

    // MARK: Privado

    /// `"2026-09"` → `(2026, 9)`. `nil` si no es una clave de mes: así una
    /// fila con basura no genera nada en vez de generar cualquier cosa.
    private static func partes(_ mes: String) -> (Int, Int)? {
        let piezas = mes.split(separator: "-")
        guard piezas.count == 2,
              let a = Int(piezas[0]), let m = Int(piezas[1]),
              a > 1900, (1...12).contains(m) else { return nil }
        return (a, m)
    }

    private static func clave(_ anio: Int, _ mes: Int) -> String {
        String(format: "%04d-%02d", anio, mes)
    }
}
