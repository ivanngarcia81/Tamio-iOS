import SwiftUI

/// Un renglón de la sidebar: icono + título, badge opcional (gris para conteos,
/// rojo para lo urgente), y el estado seleccionado en verde Tamio con tinte —
/// el único lugar, junto a las cifras, donde el color aparece.
private struct SidebarRow: View {
    let titulo: String
    let icono: String
    var badge: Int? = nil
    var badgeRojo: Bool = false
    let seleccionado: Bool
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 12) {
                Image(systemName: icono)
                    .font(.system(size: 16))
                    .frame(width: 22)
                    .foregroundStyle(seleccionado ? Paleta.brand : .primary)
                Text(titulo)
                    .font(.subheadline)
                    .foregroundStyle(seleccionado ? Paleta.brand : .primary)
                Spacer(minLength: 6)
                if let badge {
                    Text("\(badge)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(badgeRojo ? .white : .secondary)
                        .padding(.horizontal, badgeRojo ? 7 : 2)
                        .padding(.vertical, badgeRojo ? 2 : 0)
                        .background {
                            if badgeRojo { Capsule().fill(Paleta.badge) }
                        }
                }
            }
            .padding(.horizontal, Esp.pantalla)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(seleccionado ? Paleta.brandFill : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarSectionTitle: View {
    let texto: String
    var body: some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Esp.pantalla)
            .padding(.top, 14)
            .padding(.bottom, 2)
    }
}

/// La barra lateral de navegación del iPad, fiel al handoff: cabecera de la
/// iglesia, buscador, y las áreas de Tesorería y Secretaría con sus badges.
struct Sidebar: View {
    @Binding var seleccion: String
    /// El membrete sale de Ajustes, no de esta vista. El nombre iba escrito a
    /// mano aquí y en otros nueve sitios, con DOS valores distintos —"Iglesia
    /// Getsemaní" y "Iglesia Nueva Vida"—, así que los documentos y la sidebar
    /// nombraban iglesias diferentes.
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    /// El mismo ViewModel que el badge del tab del iPhone: el conteo de la
    /// bandeja se calcula UNA vez y lo leen todos.
    @State private var revisarVM = RevisarViewModel.compartido
    private var iglesia: ConfiguracionIglesia { cfg.config }

    var body: some View {
        VStack(spacing: 0) {
            cabeceraIglesia
            buscador

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    SidebarRow(titulo: L.t("Inicio", "Home"), icono: "house",
                               seleccionado: seleccion == "inicio") { seleccion = "inicio" }

                    SidebarSectionTitle(texto: L.t("TESORERÍA", "TREASURY"))
                    grupo(tesoreria)

                    SidebarSectionTitle(texto: L.t("SECRETARÍA", "SECRETARY"))
                    grupo(secretaria)
                }
                .padding(.horizontal, Esp.hueco)
            }

            Divider()
            piePagina
        }
        .background(.clear)
        .task { await cfg.cargar() }
        .task { await revisarVM.cargar() }
    }

    private func grupo(_ items: [(String, String, String, Int?, Bool)]) -> some View {
        ForEach(items, id: \.0) { item in
            SidebarRow(titulo: item.1, icono: item.2, badge: item.3, badgeRojo: item.4,
                       seleccionado: seleccion == item.0) { seleccion = item.0 }
        }
    }

    // Los badges salen de los mismos repositorios que alimentan cada
    // pantalla. Antes eran tres números escritos a mano —248, 10 y 4—
    // que no coincidían con lo que la pantalla acababa mostrando.
    // id, título, icono, badge, badgeRojo
    private var tesoreria: [(String, String, String, Int?, Bool)] {
        [
            ("ingresos", L.t("Ingresos", "Income"), "arrow.down", nil, false),
            ("gastos", L.t("Gastos", "Expenses"), "arrow.up", nil, false),
            ("miembros", L.t("Aportantes", "Contributors"), "person.2",
             MockMiembrosRepository.activosCount, false),
            ("reportes", L.t("Reportes", "Reports"), "chart.bar", nil, false),
            ("depositos", L.t("Depósitos", "Deposits"), "building.columns", nil, false),
            ("porRevisar", L.t("Por revisar", "To review"), "tray",
             revisarVM.porRevisarCount, true),
        ]
    }

    private var secretaria: [(String, String, String, Int?, Bool)] {
        [
            ("membresia", L.t("Membresía", "Membership"), "person.text.rectangle", nil, false),
            ("actas", L.t("Actas", "Minutes"), "doc.text", nil, false),
            ("servicios", L.t("Registro de servicios", "Service log"), "book", nil, false),
            ("cartas", L.t("Cartas y traslados", "Letters & transfers"), "envelope", nil, false),
            ("informes", L.t("Informes de membresía", "Membership reports"), "doc.plaintext", nil, false),
            ("agenda", L.t("Agenda", "Calendar"), "calendar",
             MockAgendaRepository.pendientesCount, false),
        ]
    }

    private var cabeceraIglesia: some View {
        HStack(spacing: 10) {
            Text(iglesia.iniciales)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(iglesia.nombre).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(iglesia.ubicacionLegible).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Esp.pantalla)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var buscador: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.subheadline).foregroundStyle(.secondary)
            Text(L.t("Buscar en Tamio", "Search Tamio")).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text("⌘K").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Esp.chip)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, Esp.pantalla)
        .padding(.bottom, 8)
    }

    private var piePagina: some View {
        VStack(alignment: .leading, spacing: 2) {
            SidebarRow(titulo: L.t("Registro", "Log"), icono: "list.bullet.rectangle",
                       seleccionado: seleccion == "registro") { seleccion = "registro" }
            SidebarRow(titulo: L.t("Configuración", "Settings"), icono: "gearshape",
                       seleccionado: seleccion == "config") { seleccion = "config" }

            HStack(spacing: 10) {
                Text("IG")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.tertiarySystemFill), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Iván García").font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(L.t("Administrador · al día 9:38", "Admin · synced 9:38"))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Circle().fill(Paleta.brand).frame(width: 8, height: 8)
            }
            .padding(.horizontal, Esp.pantalla)
            .padding(.top, 6)
        }
        .padding(.horizontal, Esp.hueco)
        .padding(.vertical, 8)
    }
}
