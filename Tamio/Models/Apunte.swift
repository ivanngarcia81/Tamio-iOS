import Foundation

/// Área de la iglesia a la que pertenece un apunte del registro.
enum ApunteArea {
    case tesoreria, secretaria
    var etiqueta: String {
        switch self {
        case .tesoreria: return L.t("Tesorería", "Treasury")
        case .secretaria: return L.t("Secretaría", "Secretary")
        }
    }
}

/// Filtros de la barra superior del Registro.
enum FiltroRegistro: String, CaseIterable, Identifiable {
    case todo, tesoreria, secretaria, notas
    var id: String { rawValue }
    var etiqueta: String {
        switch self {
        case .todo: return L.t("Todo", "All")
        case .tesoreria: return L.t("Tesorería", "Treasury")
        case .secretaria: return L.t("Secretaría", "Secretary")
        case .notas: return L.t("Notas", "Notes")
        }
    }
}

/// Un apunte del registro: una línea de lo que pasó en la iglesia. El registro
/// guarda copias, no referencias — por eso `folio`/`texto` quedan congelados.
struct Apunte: Identifiable, Hashable {
    let id: Int
    let area: ApunteArea
    let texto: String        // "El corte «Domingo 23 de agosto» llegó al banco"
    let autor: String        // "Tamio" · o "Rocío Ibarra"
    let hora: String         // "12:40"
    let grupo: String        // "HOY" · "AYER" · "22 AGO 2026"
    let fecha: String        // "Hoy · 30 de agosto" (para el detalle)
    var esNota: Bool = false // nota escrita a mano (badge NOTA + resaltado ámbar)
    var esAlerta: Bool = false // algo que no cuadró (punto rojo + resaltado)
    var folio: String? = nil // referencia congelada, si aplica

    static func == (l: Apunte, r: Apunte) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
