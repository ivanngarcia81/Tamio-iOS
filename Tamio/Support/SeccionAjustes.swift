import SwiftUI

/// **Las ocho secciones de Ajustes, definidas una sola vez.**
///
/// Había dos enumeraciones con los mismos ocho casos —`AjustesRuta` en el
/// teléfono y `SeccionConfig` en el iPad— y cada una llevaba su propia tabla de
/// iconos y de colores. El resultado es el que cabía esperar de un dato con dos
/// dueños: **ninguna fila usaba el mismo símbolo en las dos plataformas**.
/// Iglesia era `building.2.fill` aquí y `house` allí; Institución,
/// `doc.richtext.fill` y `doc.text`; y hasta los azules eran distintos
/// (`0x007AFF` contra `0x0A84FF`).
///
/// Dos elecciones de símbolo que valen la pena explicar:
///
/// - **Tesorero y pastor lleva `signature`.** Tenía `waveform` en el teléfono y
///   `waveform.path.ecg` en el iPad: uno es un nivel de audio y el otro un
///   ELECTROCARDIOGRAMA. Los dos se eligieron porque de lejos parecen una
///   rúbrica, que es justo de lo que va la fila —quién firma los documentos—, y
///   para eso existe un símbolo que lo dice.
/// - **Acceso y áreas lleva `person.badge.key.fill`** y no una llave a secas.
///   La pregunta de esa pantalla es *quién* entra, no *con qué*.
///
/// Los colores son los del sistema y no hexes fijos. Se adaptan a claro y
/// oscuro solos, que es lo que las dos tablas de antes no hacían: una tenía la
/// paleta clara de iOS y la otra la oscura, así que una de las dos iba a fallar
/// siempre. Son cromo de lista al estilo de los Ajustes de iOS, no color de
/// marca: el verde de Tamio sigue reservado a lo seleccionado y a las cifras.
enum SeccionAjustes: String, CaseIterable, Identifiable, Hashable {
    case cuenta, iglesia, institucion, tesorero, acceso, categorias, preferencias, zona

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .cuenta:       return L.t("Cuenta", "Account")
        case .iglesia:      return L.t("Iglesia", "Church")
        case .institucion:  return L.t("Institución", "Institution")
        case .tesorero:     return L.t("Tesorero y pastor", "Treasurer & pastor")
        case .acceso:       return L.t("Acceso y áreas", "Access & areas")
        case .categorias:   return L.t("Categorías", "Categories")
        case .preferencias: return L.t("Preferencias", "Preferences")
        case .zona:         return L.t("Zona de riesgo", "Danger zone")
        }
    }

    /// Todos comprobados contra `UIImage(systemName:)` en iOS 26: un nombre que
    /// no existe no da error de compilación, solo deja el hueco vacío.
    var icono: String {
        switch self {
        case .cuenta:       return "person.crop.circle.fill"
        // `building.2` y no `cross`: la fila son los datos legales y fiscales
        // de la institución, no su credo, y Tamio sirve a congregaciones de
        // tradiciones distintas.
        case .iglesia:      return "building.2.fill"
        case .institucion:  return "doc.richtext.fill"
        case .tesorero:     return "signature"
        case .acceso:       return "person.badge.key.fill"
        case .categorias:   return "tag.fill"
        // `textformat.size` y no `macwindow`, que además de abstracto dibujaba
        // una ventana de Mac dentro de un iPhone. Dos de los tres ajustes que
        // quedan aquí —idioma y tamaño— son sobre leer.
        case .preferencias: return "textformat.size"
        case .zona:         return "exclamationmark.triangle.fill"
        }
    }

    /// **El color de la sección: el de iOS en oscuro, uno más hondo en claro.**
    ///
    /// Eran los ocho colores de sistema a secas, como en Ajustes de iOS. Con el
    /// símbolo blanco encima, medidos en el aparato, daban entre 2.16:1 (cian)
    /// y 5.09:1 (índigo); el mínimo para texto es 4.5:1. El rojo, que además se
    /// usa como TEXTO en "Zona de riesgo", daba 3.57:1.
    ///
    /// En claro baja el brillo hasta **5:1**, no hasta 4.5 —solo el brillo: el
    /// tono y la saturación son los de Apple, así que el verde sigue siendo el
    /// verde de iOS, más hondo—. Índigo no se movió porque ya llegaba.
    ///
    /// **Medio punto de margen, y es medido.** La primera vuelta apuntó al
    /// 4.55 y el iPhone físico dio 4.43 en el cian: la pantalla es P3 y el
    /// píxel que vuelve no es el que se pidió. Un umbral sin margen deja la
    /// placa por debajo del mínimo y la prueba en verde, que es lo peor de los
    /// dos mundos.
    /// En oscuro se queda el del sistema: ahí el problema no era el fondo sino
    /// el símbolo, y lo arregla `Paleta.sobre(_:_:)`.
    var color: Color {
        switch self {
        case .cuenta:       return Paleta.placa(claro: 0x6F6F73, oscuroSistema: .systemGray)
        case .iglesia:      return Paleta.placa(claro: 0x217F39, oscuroSistema: .systemGreen)
        case .institucion:  return Paleta.placa(claro: 0x6155F5, oscuroSistema: .systemIndigo)
        case .tesorero:     return Paleta.placa(claro: 0x007993, oscuroSistema: .systemCyan)
        case .acceso:       return Paleta.placa(claro: 0x006FD1, oscuroSistema: .systemBlue)
        case .categorias:   return Paleta.placa(claro: 0xA75C1A, oscuroSistema: .systemOrange)
        case .preferencias: return Paleta.placa(claro: 0xB62BC9, oscuroSistema: .systemPurple)
        case .zona:         return Paleta.placa(claro: 0xD22E32, oscuroSistema: .systemRed)
        }
    }

    /// El párrafo de la tarjeta grande del iPad.
    var descripcion: String {
        switch self {
        case .cuenta:
            return L.t("Tu sesión, la versión de Tamio y el estado de sincronización de este aparato.",
                       "Your session, Tamio version, and sync status of this device.")
        case .iglesia:
            return L.t("Nombre, ubicación, logo y datos fiscales de la iglesia. Se usan en el membrete de cartas, actas y reportes.",
                       "Church name, location, logo, and tax data used in the letterhead of letters, minutes, and reports.")
        case .institucion:
            return L.t("El membrete institucional: dirección, contacto y firmas que encabezan los documentos impresos.",
                       "Institutional letterhead: address, contact, and signatures at the top of printed documents.")
        case .tesorero:
            return L.t("Datos y firmas del tesorero y del pastor, que aparecen al pie de los reportes y las cartas.",
                       "Treasurer and pastor data and signatures, shown at the bottom of reports and letters.")
        case .acceso:
            return L.t("Quién entra a Tesorería y quién a Secretaría, invitaciones, permisos del rol, sincronización y plan.",
                       "Who accesses Treasury and Secretary areas, invitations, role permissions, sync, and plan.")
        case .categorias:
            return L.t("Las categorías de ingresos y gastos que aparecen en formularios, filtros, reportes y PDFs.",
                       "Income and expense categories shown in forms, filters, reports, and PDFs.")
        case .preferencias:
            return L.t("Apariencia, idioma y tamaño de texto de la aplicación.",
                       "Appearance, language, and text size of the app.")
        case .zona:
            return L.t("Respaldos, restauración, mantenimiento y borrado de datos. Los cambios aquí no se pueden deshacer.",
                       "Backups, restore, maintenance, and data deletion. Changes here cannot be undone.")
        }
    }
}
