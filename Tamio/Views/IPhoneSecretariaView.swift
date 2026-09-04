import SwiftUI

/// Hub de Secretaría para iPhone, fiel al handoff: KPI de padrón activo,
/// secciones PADRÓN, REGISTRO, EQUIPO y PRÓXIMOS COMPROMISOS.
struct IPhoneSecretariaView: View {
    /// Mismas cifras que encabezan Membresía, no un número propio.
    private let padron = MockMembresiaRepository.resumenPadron
    /// Mismo conteo que muestra la Agenda y el badge de la sidebar del iPad.
    private let agendaPendientes = MockAgendaRepository.pendientesCount

    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    private var permisos: Permisos {
        Permisos(rol: sesion?.perfil.rol ?? .administrador, iglesia: cfg.config)
    }

    var body: some View {
        List {
            Section {
                kpiPadron
            }

            Section(L.t("PADRÓN", "ROSTER")) {
                // Membresía solo si esta persona ve el padrón. Ver `Permisos`.
                if permisos.vePadron {
                    NavigationLink { MembresiaView() } label: {
                        HubRow(icono: "person.text.rectangle.fill", color: Paleta.brand,
                               titulo: L.t("Membresía", "Membership"),
                               subtitulo: L.t("\(padron.total) personas · \(padron.activos) activos",
                                              "\(padron.total) people · \(padron.activos) active"))
                    }
                }
                NavigationLink { InformesMembresiaView() } label: {
                    HubRow(icono: "chart.pie.fill", color: Paleta.enlace,
                           titulo: L.t("Informes de membresía", "Membership reports"),
                           subtitulo: L.t("Panorama, padrón y seguimiento",
                                          "Overview, roster & tracking"))
                }
            }

            Section(L.t("REGISTRO", "RECORDS")) {
                NavigationLink { AgendaView() } label: {
                    HubRow(icono: "calendar", color: Color(hex: 0x0D9488),
                           titulo: L.t("Agenda", "Calendar"),
                           subtitulo: L.t("\(L.mesEnCurso) · \(agendaPendientes) compromisos",
                                          "\(L.mesEnCurso) · \(agendaPendientes) events"))
                }
                NavigationLink { ServiciosView() } label: {
                    HubRow(icono: "checklist", color: Paleta.aviso,
                           titulo: L.t("Registro de servicios", "Service log"),
                           subtitulo: L.t("Roster y asistencia por culto",
                                          "Roster & attendance per service"))
                }
                NavigationLink { ActasView() } label: {
                    HubRow(icono: "doc.text.fill", color: Color(hex: 0x7C3AED),
                           titulo: L.t("Actas", "Minutes"),
                           subtitulo: L.t("Acta 2026-08 en borrador", "Draft minutes 2026-08"),
                           badge: 1)
                }
                NavigationLink { CartasView() } label: {
                    HubRow(icono: "envelope.fill", color: Color(hex: 0x06B6D4),
                           titulo: L.t("Cartas y traslados", "Letters & transfers"),
                           subtitulo: L.t("3 documentos abiertos", "3 open documents"))
                }
            }

            Section(L.t("EQUIPO", "TEAM")) {
                // Mensajes: pantalla pendiente de construir.
                HubRow(icono: "bubble.left.and.bubble.right.fill", color: Color(hex: 0x64748B),
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
        .task { await cfg.cargar() }
    }

    // MARK: - KPI Padrón

    private var kpiPadron: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.t("PADRÓN ACTIVO", "ACTIVE ROSTER"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(padron.activos)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Paleta.brand)
                Text(L.t("de alta", "enrolled"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            // Las tres cifras salen del mismo resumen y cuadran entre sí: antes
            // este KPI decía 12 de alta y 14 en el directorio mientras
            // Membresía encabezaba 248 / 236.
            Text(L.t("\(padron.total) en el directorio · \(padron.total - padron.activos) de baja o inactivos",
                     "\(padron.total) in directory · \(padron.total - padron.activos) removed or inactive"))
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
