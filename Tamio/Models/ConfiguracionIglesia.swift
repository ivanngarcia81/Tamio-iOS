import Foundation

/// Los datos institucionales de la iglesia: el membrete de los documentos y
/// quiénes los firman.
///
/// **Es el único origen de esta información.** Antes había tres copias sueltas
/// —los `@State` de Ajustes en iPhone, otros distintos en iPad, y el nombre
/// escrito a mano dentro de los PDF— y ninguna mandaba sobre las demás.
struct ConfiguracionIglesia: Equatable {
    var nombre: String = ""
    var direccion: String = ""
    var ciudad: String = ""
    var estado: String = ""
    var pais: String = ""
    var codigoPostal: String = ""
    /// EIN en Estados Unidos, RFC en México.
    var idFiscal: String = ""
    var telefono: String = ""
    var correo: String = ""
    /// Código ISO de la moneda. Dólar por defecto: la iglesia está en Estados
    /// Unidos. Se cambia en Ajustes · Iglesia.
    var moneda: String = "USD"
    var pieInstitucional: String = ""
    /// **El saldo de apertura, en centavos.** El dinero que la tesorería ya
    /// tenía antes del primer movimiento registrado.
    ///
    /// Era un `@State` de la pantalla de Ajustes: se tecleaba, se veía escrito,
    /// y al salir se perdía. Ahora se guarda y se sincroniza
    /// (`iglesias.saldo_inicial`, migración del 2026-09-04).
    ///
    /// **Todavía no entra en ninguna cifra, y es a propósito.** Lo que Tamio
    /// llama "saldo en caja" es el EFECTIVO SIN DEPOSITAR —lo contado se
    /// deposita íntegro, así que es lo recibido en efectivo que ningún corte
    /// depositado reclama— y un saldo de apertura no es efectivo de ofrenda
    /// esperando ir al banco: sumárselo falsearía justo la cifra que le dice al
    /// tesorero cuánto dinero tiene delante. Su sitio es el saldo acumulado del
    /// estado financiero, que hoy no existe: Reportes enseña balance por mes y
    /// sigue con cifras escritas a mano.
    var saldoInicial: Centavos = 0

    var pastorNombre: String = ""
    var pastorCargo: String = "Pastor"
    var tesoreroNombre: String = ""
    var tesoreroCargo: String = "Tesorero"

    /// **El contacto de la PERSONA**, no el de la iglesia.
    ///
    /// `correo` y `telefono` de arriba son los institucionales, los que van en
    /// el membrete; estos son los del tesorero y del pastor. En el iPad esas
    /// cuatro filas existían desde el principio pero eran texto FIJO —parecían
    /// campos y no lo eran— y en el teléfono no estaban. Los nombres de las
    /// columnas son los de la app web, que es donde ya vivía este dato.
    var tesoreroCorreo: String = ""
    var tesoreroTelefono: String = ""
    var pastorCorreo: String = ""
    var pastorTelefono: String = ""
    var secretarioNombre: String = ""
    var secretarioCargo: String = "Secretario"
    var imprimirFirmas: Bool = true

    // MARK: - Permisos del rol Tesorería

    /// **Son de la iglesia, no de la persona**: valen para quien ocupe el
    /// puesto. Los valores por omisión son los de Supabase.
    ///
    /// Los dos tiran para lados distintos y por eso no se leen igual:
    /// `tesoreroVePadron` **da** —hoy el tesorero no entra a Membresía y esto
    /// le abre esa pantalla, para la iglesia chica donde la misma persona
    /// lleva la tesorería y el padrón—, mientras que `tesoreroPuedeEliminar`
    /// **quita**: hoy sí puede, y apagarlo se lo retira.
    ///
    /// Hasta dónde llega cada uno, sin adornos: el del borrado es un control de
    /// verdad, pero **el que manda es el servidor** —el disparador
    /// `frenar_borrado_tesorero` deshace la baja—, y lo que hace la app es no
    /// enseñar un botón que no va a funcionar. El del padrón NO es una barrera
    /// de datos y no puede serlo: el padrón se sincroniza entero a todos los
    /// aparatos porque Aportantes lo necesita. Abre una PANTALLA.
    ///
    /// **No se suben con el resto.** Los escribe el RPC
    /// `fijar_permisos_tesoreria`, que solo acepta al administrador; meterlos
    /// en el `update` general de la iglesia dejaría que cualquiera se los
    /// cambiara a sí mismo desde su propio teléfono.
    var tesoreroVePadron: Bool = false
    var tesoreroPuedeEliminar: Bool = true

    // MARK: - Plan y suscripción

    /// `iglesias.plan`, `sub_estado` y `sub_vence`. **Solo se leen**: el plan
    /// lo administra el servidor y aquí no hay forma de cambiarlo, que es lo
    /// que el pie de Ajustes lleva diciendo desde siempre. Lo que no decía es
    /// que las dos filas —"Completo" y "Cortesía"— iban escritas a mano, así
    /// que decían eso mismo con el plan que fuera.
    var plan: String = ""
    var subEstado: String = ""
    /// Fecha ISO (`yyyy-MM-dd`), tal y como la guarda Postgres.
    var subVence: String = ""

    /// El plan, listo para enseñar. Vacío se lee "—" y no "Completo": no saber
    /// qué plan tiene una iglesia no es lo mismo que darle el mejor.
    var planLegible: String {
        plan.trimmingCharacters(in: .whitespaces).isEmpty ? "—" : plan.capitalized
    }

    /// La suscripción con su vencimiento, si lo hay: "Activa · vence el 12 mar
    /// 2027". La fecha es lo único accionable de esta fila.
    var suscripcionLegible: String {
        let estado = subEstado.trimmingCharacters(in: .whitespaces)
        let base = estado.isEmpty ? "—" : estado.capitalized
        guard !subVence.isEmpty else { return base }
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        iso.locale = Locale(identifier: "en_US_POSIX")
        guard let fecha = iso.date(from: subVence) else { return base }
        let salida = DateFormatter()
        salida.locale = L.locale
        salida.dateStyle = .medium
        return base + " · " + L.t("vence el \(salida.string(from: fecha))",
                                  "expires \(salida.string(from: fecha))")
    }

    // MARK: - Derivados para los documentos

    /// Segunda línea del membrete: "Monterrey, Nuevo León, México".
    var ubicacionLegible: String {
        [ciudad, estado, pais]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Dos letras para el cuadrito de la sidebar. Iba escrito "IG" a mano,
    /// junto a un nombre también escrito a mano.
    var iniciales: String {
        let palabras = nombre.split(separator: " ").filter { $0.count > 2 }
        let letras = palabras.prefix(2).compactMap { $0.first }
        return letras.isEmpty ? "—" : String(letras).uppercased()
    }

    /// Membrete completo. Si no hay nada configurado devuelve cadena vacía en
    /// vez de un nombre inventado: un documento sin membrete es un descuido,
    /// pero uno con el nombre de otra iglesia es un error.
    var membrete: String {
        let partes = [nombre.trimmingCharacters(in: .whitespaces), ubicacionLegible]
            .filter { !$0.isEmpty }
        return partes.joined(separator: " · ")
    }

    /// Las personas con cargo en la iglesia, tengan o no activada la impresión
    /// de firmas. `firmantes` no sirve para esto: está condicionado a
    /// `imprimirFirmas`, que es una preferencia de los PDF, y la segunda firma
    /// de un corte es un control interno que no depende de cómo se imprima.
    var personas: [(nombre: String, cargo: String)] {
        [(pastorNombre, pastorCargo),
         (tesoreroNombre, tesoreroCargo),
         (secretarioNombre, secretarioCargo)]
            .filter { !$0.0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Quiénes firman, en el orden en que se imprimen. Solo los que tienen
    /// nombre: una línea de firma en blanco no vale para nada.
    var firmantes: [(nombre: String, cargo: String)] {
        guard imprimirFirmas else { return [] }
        return [(pastorNombre, pastorCargo),
                (tesoreroNombre, tesoreroCargo),
                (secretarioNombre, secretarioCargo)]
            .filter { !$0.0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Si falta algo para que una constancia anual sirva como comprobante
    /// fiscal. La pantalla lo avisa antes de generar el documento, no después.
    var faltaParaConstancia: [String] {
        var faltan: [String] = []
        if nombre.trimmingCharacters(in: .whitespaces).isEmpty {
            faltan.append(L.t("nombre de la iglesia", "church name"))
        }
        if idFiscal.trimmingCharacters(in: .whitespaces).isEmpty {
            faltan.append(L.t("identificación fiscal", "tax ID"))
        }
        if direccion.trimmingCharacters(in: .whitespaces).isEmpty {
            faltan.append(L.t("dirección", "address"))
        }
        return faltan
    }

    var listaParaConstancia: Bool { faltaParaConstancia.isEmpty }
}
