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

    var pastorNombre: String = ""
    var pastorCargo: String = "Pastor"
    var tesoreroNombre: String = ""
    var tesoreroCargo: String = "Tesorero"
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
