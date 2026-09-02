import SwiftUI

/// Hub de Secretaría para iPhone, fiel al handoff: KPI de padrón activo,
/// secciones PADRÓN, REGISTRO, EQUIPO y PRÓXIMOS COMPROMISOS.
struct IPhoneSecretariaView: View {
    var body: some View {
        List {
            Section {
                kpiPadron
            }

            Section(L.t("PADRÓN", "ROSTER")) {
                NavigationLink { MembresiaView() } label: {
                    HubRow(iniciales: "Me", color: Paleta.brand,
                           titulo: L.t("Membresía", "Membership"),
                           subtitulo: L.t("14 personas · altas y bajas",
                                          "14 people · additions & removals"))
                }
                NavigationLink { InformesMembresiaView() } label: {
                    HubRow(iniciales: "In", color: Paleta.enlace,
                           titulo: L.t("Informes de membresía", "Membership reports"),
                           subtitulo: L.t("Panorama, padrón y seguimiento",
                                          "Overview, roster & tracking"))
                }
            }

            Section(L.t("REGISTRO", "RECORDS")) {
                NavigationLink { AgendaView() } label: {
                    HubRow(iniciales: "Ag", color: Color(hex: 0x0D9488),
                           titulo: L.t("Agenda", "Calendar"),
                           subtitulo: L.t("Agosto 2026 · 7 compromisos",
                                          "August 2026 · 7 events"))
                }
                NavigationLink { ServiciosView() } label: {
                    HubRow(iniciales: "Se", color: Paleta.aviso,
                           titulo: L.t("Registro de servicios", "Service log"),
                           subtitulo: L.t("Roster y asistencia por culto",
                                          "Roster & attendance per service"))
                }
                NavigationLink { ActasView() } label: {
                    HubRow(iniciales: "Ac", color: Color(hex: 0x7C3AED),
                           titulo: L.t("Actas", "Minutes"),
                           subtitulo: L.t("Acta 2026-08 en borrador", "Draft minutes 2026-08"),
                           badge: 1)
                }
                NavigationLink { CartasView() } label: {
                    HubRow(iniciales: "Ca", color: Color(hex: 0x06B6D4),
                           titulo: L.t("Cartas y traslados", "Letters & transfers"),
                           subtitulo: L.t("3 documentos abiertos", "3 open documents"))
                }
            }

            Section(L.t("EQUIPO", "TEAM")) {
                // Mensajes: pantalla pendiente de construir.
                HubRow(iniciales: "Ms", color: Color(hex: 0x64748B),
                       titulo: L.t("Mensajes", "Messages"),
                       subtitulo: L.t("Secretaría, tesorería y pastor",
                                      "Secretary, treasury & pastor"),
                       badge: 2)
            }

            Section(L.t("PRÓXIMOS COMPROMISOS", "UPCOMING")) {
                proximosCompromisos
            }
        }
        .listStyle(.insetGrouped)
        .encabezadoNav(L.t("Secretaría", "Secretary"),
                       L.t("Padrón, servicios y documentos", "Roster, services & documents"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - KPI Padrón

    private var kpiPadron: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.t("PADRÓN ACTIVO", "ACTIVE ROSTER"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("12")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.brand)
                Text(L.t("de alta", "enrolled"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(L.t("14 en el directorio · 2 de baja o inactivos",
                     "14 in directory · 2 removed or inactive"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Próximos compromisos

    private var proximosCompromisos: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L.t("MAÑANA · 19:00", "TOMORROW · 19:00"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Paleta.aviso)
                Text(L.t("Consejo de ancianos", "Council of elders"))
                    .font(.subheadline.weight(.semibold))
                Text(L.t("Salón anexo · levantar acta", "Annex room · take minutes"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                statCell(L.t("Esta semana", "This week"), "5")
                Divider().frame(height: 30)
                statCell(L.t("En agosto", "In August"), "7")
                Divider().frame(height: 30)
                statCell(L.t("Días al próximo", "Days to next"), "1")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(spacing: 0) {
                eventoRow("VIE", "21",
                          L.t("Consejo de ancianos", "Council of elders"),
                          L.t("Salón anexo · levantar acta", "Annex room · take minutes"),
                          L.t("19:00 mañana", "19:00 tomorrow"))
                Divider().padding(.leading, 52)
                eventoRow("SÁB", "22",
                          L.t("Escuela bíblica", "Bible school"),
                          L.t("Salón 2 · maestros de niños", "Room 2 · children's teachers"),
                          "17:00")
            }
        }
        .padding(.vertical, 4)
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func eventoRow(_ dia: String, _ num: String,
                           _ titulo: String, _ lugar: String, _ hora: String) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(dia).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(num).font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(lugar).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(hora).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
