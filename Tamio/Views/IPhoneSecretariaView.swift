import SwiftUI

/// Hub de Secretaría para iPhone, fiel al handoff: KPI de padrón activo,
/// secciones PADRÓN, REGISTRO, EQUIPO y PRÓXIMOS COMPROMISOS.
struct IPhoneSecretariaView: View {
    /// **Las dos cifras del hub se CARGAN, ya no se copian de la maqueta.**
    ///
    /// Iban como `MockMembresiaRepository.resumenPadron` y
    /// `MockAgendaRepository.pendientesCount`, leídos directamente y saltándose
    /// las fábricas. Con eso la primera pantalla de Secretaría seguía diciendo
    /// 236 de alta de 248 aunque entraras con la cuenta real y el padrón
    /// tuviera otras cifras: la maqueta no era el modo revisión, estaba
    /// clavada en el código.
    ///
    /// Ahora salen de `repositorioMembresia()` y `repositorioAgenda()`, que en
    /// modo revisión devuelven la maqueta y con sesión devuelven la base. Y
    /// `nil` mientras cargan: un guion se entiende, un cero inventado no.
    @State private var padron: MembresiaResumen?
    @State private var agenda: ResumenAgenda?

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

            // **Las seis tienen su botón de volver.** Todas colgaban del hub
            // con `sinBotonVolver()`, cuya razón escrita era que el chevron
            // gasta una cápsula y que la pestaña de Secretaría lleva al mismo
            // sitio. Las dos salidas existen y funcionan —comprobado en las
            // seis: tocar la pestaña vuelve, y el gesto de borde también— pero
            // ninguna se VE. Una secretaria que entra a Actas no tiene por qué
            // deducir cómo se sale.
            //
            // Y el argumento de la cápsula solo valía para UNA. Contadas en el
            // teléfono con la app corriendo: Informes, Agenda, Servicios,
            // Actas y Cartas usan **una** cápsula cada una, con el lado
            // izquierdo vacío, y recuperaron el chevron el 5 de septiembre.
            // Membresía usaba cinco —lupa, selector de vista, filtros y `+`— y
            // el sistema **tiraba el `+` sin avisar**: se quedaba sin dar de
            // alta. Se resolvió bajando el alta a la lista, no acortando el
            // conteo del selector, que es lo único que dice cuántas personas
            // se ven y que la lista está filtrada. Ver `MembresiaView.barra`.
            Section(L.t("PADRÓN", "ROSTER")) {
                // Membresía solo si esta persona ve el padrón. Ver `Permisos`.
                if permisos.vePadron {
                    NavigationLink { MembresiaView() } label: {
                        HubRow(icono: "person.text.rectangle.fill", color: Paleta.brand,
                               titulo: L.t("Membresía", "Membership"),
                               subtitulo: padron.map {
                                   L.t("\($0.total) personas · \($0.activos) activos",
                                       "\($0.total) people · \($0.activos) active")
                               } ?? L.t("Fichas, parentescos y traslados",
                                        "Records, relatives & transfers"))
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
                           subtitulo: agenda.map {
                               L.t("\(L.mesEnCurso) · \($0.pendientes) compromisos",
                                   "\(L.mesEnCurso) · \($0.pendientes) events")
                           } ?? L.mesEnCurso)
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
        .task {
            padron = await repositorioMembresia().resumen()
            agenda = await repositorioAgenda().resumen()
        }
    }

    // MARK: - KPI Padrón

    private var kpiPadron: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.t("PADRÓN ACTIVO", "ACTIVE ROSTER"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(padron.map { "\($0.activos)" } ?? "—")
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
            if let padron {
                Text(L.t("\(padron.total) en el directorio · \(padron.total - padron.activos) de baja o inactivos",
                         "\(padron.total) in directory · \(padron.total - padron.activos) removed or inactive"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Próximos compromisos

    /// **Nada de aquí está escrito: todo sale de `ResumenAgenda`.**
    ///
    /// Estaba clavado en el handoff de agosto —el titular decía "MAÑANA ·
    /// 19:00" y debajo listaba "VIE 21" y "SÁB 22" con las abreviaturas en
    /// español aunque la app estuviera en inglés—, así que en septiembre
    /// anunciaba como "mañana" un viernes 21 que caía dentro de dos semanas, y
    /// contaba "En agosto" dos filas debajo de una Agenda que ya encabezaba
    /// septiembre. La "Escuela bíblica" del sábado 22 ni siquiera existía en la
    /// agenda: solo vivía aquí.
    ///
    /// Las dos filas que se enseñan son las dos primeras del resumen, no una
    /// selección propia: si la Agenda y el hub eligieran por su cuenta cuál es
    /// el próximo compromiso, tarde o temprano dirían cosas distintas.
    @ViewBuilder
    private var proximosCompromisos: some View {
        if let agenda {
            if let proximo = agenda.proximo {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(proximo.titularCorto)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Paleta.aviso)
                        Text(proximo.evento.titulo)
                            .font(.subheadline.weight(.semibold))
                        if !proximo.evento.descripcion.isEmpty {
                            Text(proximo.evento.descripcion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 0) {
                        statCell(L.t("Esta semana", "This week"), "\(agenda.estaSemana)")
                        Divider().frame(height: 30)
                        // El mes en curso por su nombre, no "agosto" a mano.
                        statCell(L.t("En \(L.mesSueltoEnCurso)", "In \(L.mesSueltoEnCurso)"),
                                 "\(agenda.pendientes)")
                        Divider().frame(height: 30)
                        statCell(L.t("Días al próximo", "Days to next"), "\(proximo.enDias)")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // **Los que vienen DESPUÉS del titular.** La maqueta repetía
                    // el primero: encabezaba con el consejo de ancianos y lo
                    // volvía a listar como primera fila. Con solo dos filas,
                    // gastar una en repetir deja ver un único compromiso.
                    VStack(spacing: 0) {
                        ForEach(Array(agenda.proximos.dropFirst().prefix(2).enumerated()),
                                id: \.element.id) { i, c in
                            if i > 0 { Divider().padding(.leading, 52) }
                            eventoRow(c.diaSemana, c.numDia,
                                      c.evento.titulo, c.evento.descripcion, c.cuando)
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                // Un mes sin nada pendiente es una respuesta, no un hueco.
                Text(L.t("Sin compromisos próximos este mes",
                         "Nothing scheduled for the rest of the month"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
        }
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
