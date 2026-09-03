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
enum Catalogos {
    static var categoriasIngreso: [String] {
        [L.t("Diezmo", "Tithe"),
         L.t("Ofrenda", "Offering"),
         L.t("Misiones", "Missions"),
         L.t("Eventos", "Events"),
         L.t("Donativo", "Donation"),
         L.t("Otro", "Other")]
    }

    static var categoriasGasto: [String] {
        [L.t("Compensación", "Compensation"),
         L.t("Pastores", "Pastors"),
         L.t("Músicos", "Musicians"),
         L.t("Suministros", "Supplies"),
         L.t("Mobiliario", "Furniture"),
         L.t("Limpieza", "Cleaning"),
         L.t("Utilidades", "Utilities"),
         L.t("Mantenimiento", "Maintenance"),
         L.t("Alimentos", "Food"),
         L.t("Tecnología", "Technology"),
         L.t("Misiones", "Missions"),
         L.t("Ayudas", "Assistance"),
         L.t("Ayuda social", "Social aid"),
         L.t("Transporte", "Transport"),
         L.t("Publicidad", "Advertising"),
         L.t("Renta", "Rent"),
         L.t("Seguros", "Insurance"),
         L.t("Varios", "Misc"),
         L.t("Otro", "Other")]
    }

    static func categorias(_ tipo: TipoMovimiento) -> [String] {
        tipo == .ingreso ? categoriasIngreso : categoriasGasto
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
