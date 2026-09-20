import SwiftUI

/// **El panel de la derecha.**
///
/// La maqueta tiene una regla sobre él que conviene no perder: *los campos y
/// el historial solo salen cuando hay algo que enseñar*. Una ficha con los
/// rótulos puestos y los valores en blanco parece que no cargó.
/// **Lo que el inspector tiene delante.**
///
/// Empezó siendo un `Movimiento?` y dejó de valer en cuanto entró el Registro:
/// cada pantalla enseña una ficha distinta, y encadenar opcionales —uno por
/// tipo— deja estados imposibles, como dos fichas a la vez. Un enum solo puede
/// ser una cosa.
enum FichaInspector {
    case nada
    case movimiento(Movimiento)
    case apunte(Apunte)
    case servicio(Servicio)
    case aportante(Aportante, anio: Int)
    case miembro(Miembro)
    case corte(Corte)
}

struct InspectorTamio: View {
    let seccion: SeccionMac
    let ficha: FichaInspector

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch ficha {
                case .movimiento(let m): fichaMovimiento(m)
                case .apunte(let a):     fichaApunte(a)
                case .servicio(let s):   fichaServicio(s)
                case .aportante(let a, let anio): fichaAportante(a, anio: anio)
                case .miembro(let m):    fichaMiembro(m)
                case .corte(let c):      fichaCorte(c)
                case .nada:              vacio
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .inspectorColumnWidth(min: 260, ideal: 312, max: 420)
    }

    // MARK: - Con algo seleccionado

    @ViewBuilder
    private func fichaMovimiento(_ m: Movimiento) -> some View {
        Text(m.esIngreso ? L.t("INGRESO", "INCOME") : L.t("GASTO", "EXPENSE"))
            .font(.system(size: 11, weight: .bold))
            .kerning(0.55)
            .foregroundStyle(.secondary)

        Text(Money.firmado(m.monto, ingreso: m.esIngreso))
            .font(.system(size: 22, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Money.color(ingreso: m.esIngreso))
            .padding(.top, 4)

        Text("\(m.categoria) · \(L.t("folio", "folio")) \(m.folio)")
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)
            .padding(.top, 2)

        // Los campos, en el mismo orden que la maqueta.
        VStack(spacing: 0) {
            campo(L.t("Fecha", "Date"),
                  m.fecha.formatted(.dateTime.day().month(.abbreviated).year()))
            campo(L.t("Hora", "Time"), m.hora)
            campo(L.t("Método", "Method"), m.metodo)
            campo(m.esIngreso ? L.t("Aportante", "Contributor")
                              : L.t("Beneficiario", "Payee"),
                  (m.esIngreso ? m.persona : m.pagadoA) ?? "—")
            campo(L.t("Estado", "Status"), EstadoFila(m).texto, tinta: EstadoFila(m).tinta)
            campo(L.t("Registrado por", "Recorded by"), m.registradoPor, ultimo: true)
        }
        .background(.quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 14)

        if let nota = m.nota, !nota.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(L.t("NOTA", "NOTE"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            Text(nota)
                .font(.system(size: 12.5))
                .padding(.top, 6)
        }

        // **El rastro de auditoría, tal cual lo trae el movimiento.** Es lo que
        // permite decir quién tocó qué; no se resume ni se recorta.
        if !m.auditoria.isEmpty {
            Text(L.t("HISTORIAL", "HISTORY"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)

            ForEach(m.auditoria) { e in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Paleta.brand)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.titulo).font(.system(size: 12, weight: .medium))
                        Text(e.detalle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
            }
        }

        // **Sin botones todavía, y a propósito.** La maqueta pone aquí
        // "Aprobar" y "Exportar recibo (PDF)". Aprobar mueve el estado de
        // revisión de un movimiento y exportar necesita `ReportePDF`, que vive
        // en `Views` y no entra en este target. Un botón verde que no hace
        // nada, en la ficha de un apunte de dinero, promete una acción que no
        // existe.
    }

    private func campo(_ rotulo: String, _ valor: String,
                       tinta: Color? = nil, ultimo: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(rotulo)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 104, alignment: .leading)
                Text(valor)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tinta ?? .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            if !ultimo { Divider().padding(.leading, 13) }
        }
    }

    // MARK: - Un apunte del registro

    @ViewBuilder
    private func fichaApunte(_ a: Apunte) -> some View {
        Text(a.esNota ? L.t("NOTA", "NOTE") : a.area.etiqueta.uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(0.55)
            .foregroundStyle(.secondary)

        // **La frase entera, sin recortar.** En la tabla va a una línea porque
        // una fila no puede crecer; aquí es donde se lee completa, y por eso
        // esta ficha existe.
        Text(a.texto)
            .font(.system(size: 15, weight: .medium))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)

        if let aviso = a.tipo.etiquetaAlerta {
            Label(aviso, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Paleta.negativo)
                .padding(.top, 10)
        }

        VStack(spacing: 0) {
            campo(L.t("Cuándo", "When"),
                  a.creadoEn.formatted(.dateTime.day().month(.abbreviated).year()
                                       .hour().minute()))
            campo(L.t("Quién", "Who"), a.autor.isEmpty ? "—" : a.autor)
            campo(L.t("Área", "Area"), a.area.etiqueta, ultimo: a.folio == nil)
            if let folio = a.folio {
                campo(L.t("Folio", "Folio"), folio, ultimo: true)
            }
        }
        .background(.quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 14)

        // **Las piezas crudas, y no por capricho.** `texto` compone la frase a
        // partir de `datos`, y si una clave falta la frase sale con un guión.
        // Cuando alguien viene a auditar y la frase no cuadra, esto es lo
        // único que dice qué se guardó de verdad.
        if !a.datos.isEmpty {
            Text(L.t("LO QUE SE GUARDÓ", "WHAT WAS STORED"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            VStack(spacing: 0) {
                let claves = a.datos.keys.sorted()
                ForEach(Array(claves.enumerated()), id: \.element) { i, k in
                    campo(k, a.datos[k] ?? "—", ultimo: i == claves.count - 1)
                }
            }
            .background(.quaternary.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 8)
        }
    }

    // MARK: - Un servicio

    /// **Aquí es donde el Mac le gana al iPad.** En el teléfono el detalle de
    /// un culto vive en otra pantalla a la que hay que entrar y de la que hay
    /// que salir; aquí está al lado de la tabla, y se puede recorrer la lista
    /// con las flechas viendo la ficha cambiar. Comparar dos domingos deja de
    /// ser ir y volver.
    @ViewBuilder
    private func fichaServicio(_ s: Servicio) -> some View {
        Text(L.t("CULTO", "SERVICE"))
            .font(.system(size: 11, weight: .bold))
            .kerning(0.55)
            .foregroundStyle(.secondary)
        Text(s.titulo)
            .font(.system(size: 19, weight: .bold))
            .padding(.top, 5)
        Text(s.fechaLegible)
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)
            .padding(.top, 2)

        VStack(spacing: 0) {
            campo(L.t("Dirige", "Led by"), s.dirige.isEmpty ? "—" : s.dirige)
            campo(L.t("Predica", "Preacher"), s.predica.isEmpty ? "—" : s.predica)
            campo(L.t("Texto", "Scripture"),
                  s.textoBiblico.isEmpty ? "—" : s.textoBiblico, ultimo: true)
        }
        .background(.quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 14)

        if !s.tituloMensaje.isEmpty {
            Text(L.t("MENSAJE", "MESSAGE"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            Text(s.tituloMensaje)
                .font(.system(size: 14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            if !s.resumenMensaje.isEmpty {
                Text(s.resumenMensaje)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }

        // **El desglose, no solo el total.** La tabla enseña la suma porque es
        // lo que se compara entre domingos; lo que dice si la iglesia está
        // creciendo o envejeciendo es el reparto, y eso vive aquí.
        if s.totalAsistencia > 0 {
            Text(L.t("ASISTENCIA", "ATTENDANCE"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            VStack(spacing: 0) {
                campo(L.t("Niños", "Children"), "\(s.ninos)")
                campo(L.t("Jóvenes", "Youth"), "\(s.jovenes)")
                campo(L.t("Adultos", "Adults"), "\(s.adultos)")
                campo(L.t("Total", "Total"), "\(s.totalAsistencia)",
                      tinta: Paleta.brand, ultimo: true)
            }
            .background(.quaternary.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 8)
        }

        if !s.visitantes.isEmpty {
            Text(L.t("VISITANTES", "VISITORS"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            ForEach(s.visitantes) { v in
                HStack(spacing: 8) {
                    Text(v.nombre).font(.system(size: 12.5))
                    // Quien viene por primera vez es a quien hay que llamar
                    // esta semana. Se marca.
                    if v.primeraVisita {
                        Text(L.t("Primera visita", "First visit"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Paleta.brand)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Paleta.brandFill,
                                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 6)
            }
        }

        if !s.puestos.isEmpty {
            Text(L.t("EQUIPO", "TEAM"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            VStack(spacing: 0) {
                ForEach(Array(s.puestos.enumerated()), id: \.element.id) { i, p in
                    campo(p.etiqueta, p.asignado ? p.nombre : L.t("Sin asignar", "Unassigned"),
                          tinta: p.asignado ? nil : Paleta.aviso,
                          ultimo: i == s.puestos.count - 1)
                }
            }
            .background(.quaternary.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 8)
        }

        if !s.orden.isEmpty {
            Text(L.t("ORDEN DEL CULTO", "ORDER OF SERVICE"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            ForEach(s.orden.sorted { $0.posicion < $1.posicion }) { p in
                HStack(alignment: .top, spacing: 10) {
                    Text(p.hora.isEmpty ? "—" : p.hora)
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.titulo).font(.system(size: 12, weight: .medium))
                        if !p.encargado.isEmpty {
                            Text(p.encargado)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Un aportante

    @ViewBuilder
    private func fichaAportante(_ a: Aportante, anio: Int) -> some View {
        encabezado(L.t("APORTANTE", "CONTRIBUTOR"), a.nombre, a.estado.etiqueta)

        VStack(spacing: 0) {
            campo(L.t("Acumulado \(anio)", "\(anio) total"), Money.fmt(a.total(anio: anio)),
                  tinta: Paleta.brand)
            campo(L.t("Frecuencia", "Frequency"), a.frecuencia.etiqueta)
            campo(L.t("Último aporte", "Last gift"),
                  a.ultimoAporte.map { $0.formatted(.dateTime.day().month(.abbreviated).year()) } ?? "—")
            campo(L.t("Congrega desde", "Attending since"),
                  a.congregaDesde.isEmpty ? "—" : a.congregaDesde, ultimo: true)
        }
        .background(.quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 14)

        contacto(telefono: a.telefono, correo: a.correo, direccion: a.direccion)
    }

    // MARK: - Un miembro

    @ViewBuilder
    private func fichaMiembro(_ m: Miembro) -> some View {
        encabezado(L.t("MIEMBRO", "MEMBER"), m.nombre, m.estado.etiqueta)

        VStack(spacing: 0) {
            campo(L.t("Ministerio", "Ministry"), m.ministerioLegible)
            campo(L.t("Asistencia", "Attendance"),
                  m.asistenciaResumen == nil ? L.t("Sin listas", "No lists")
                                             : "\(m.asistenciaPct)%",
                  tinta: m.asistenciaResumen == nil ? nil : m.tintaDeAsistencia)
            campo(L.t("Ingreso", "Joined"),
                  m.fechaIngreso.isEmpty ? "—" : Fechas.diaLegible(m.fechaIngreso))
            campo(L.t("Bautizado", "Baptized"),
                  m.bautizadoAgua ? L.t("Sí", "Yes") : L.t("No", "No"), ultimo: true)
        }
        .background(.quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 14)

        contacto(telefono: m.telefono, correo: m.correo, direccion: m.direccion)
    }

    // MARK: - Un corte

    @ViewBuilder
    private func fichaCorte(_ c: Corte) -> some View {
        Text(L.t("CORTE", "CUT"))
            .font(.system(size: 11, weight: .bold))
            .kerning(0.55)
            .foregroundStyle(.secondary)
        Text(Money.fmt(c.suma))
            .font(.system(size: 22, weight: .bold))
            .monospacedDigit()
            .padding(.top, 4)
        Text(c.titulo.isEmpty ? c.registro.cuenta : c.titulo)
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)
            .padding(.top, 2)

        VStack(spacing: 0) {
            campo(L.t("Cuenta", "Account"),
                  c.registro.cuenta.isEmpty ? "—" : c.registro.cuenta)
            campo(L.t("Fecha", "Date"),
                  c.registro.fecha.isEmpty ? "—" : Fechas.diaLegible(c.registro.fecha))
            campo(L.t("Folios", "Folios"), c.rangoDeFolios)
            campo(L.t("Movimientos", "Items"), "\(c.cuantosMovimientos)")
            campo(L.t("Estado", "Status"), c.pastilla.0, tinta: c.pastilla.1, ultimo: true)
        }
        .background(.quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 14)

        // **Lo que hay dentro del corte, movimiento a movimiento.** Es lo que
        // se cuadra contra el talonario, y en el iPad hay que entrar a otra
        // pantalla para verlo.
        if !c.movimientos.isEmpty {
            Text(L.t("LO QUE LLEVA", "WHAT IT HOLDS"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            VStack(spacing: 0) {
                ForEach(Array(c.movimientos.enumerated()), id: \.element.id) { i, m in
                    campo("\(m.folio) · \(m.categoria)", Money.fmt(m.monto),
                          ultimo: i == c.movimientos.count - 1)
                }
            }
            .background(.quaternary.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 8)
        }
    }

    // MARK: - Piezas compartidas

    @ViewBuilder
    private func encabezado(_ antetitulo: String, _ nombre: String, _ estado: String) -> some View {
        Text(antetitulo)
            .font(.system(size: 11, weight: .bold))
            .kerning(0.55)
            .foregroundStyle(.secondary)
        Text(nombre)
            .font(.system(size: 19, weight: .bold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 5)
        Text(estado)
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
    }

    /// **Solo si hay algo.** Un bloque de contacto con tres guiones ocupa el
    /// mismo sitio que uno con datos y no dice nada.
    @ViewBuilder
    private func contacto(telefono: String, correo: String, direccion: String) -> some View {
        let hay = ![telefono, correo, direccion]
            .allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        if hay {
            Text(L.t("CONTACTO", "CONTACT"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            VStack(spacing: 0) {
                if !telefono.isEmpty { campo(L.t("Teléfono", "Phone"), telefono) }
                if !correo.isEmpty { campo(L.t("Correo", "Email"), correo) }
                if !direccion.isEmpty { campo(L.t("Dirección", "Address"), direccion) }
            }
            .background(.quaternary.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 8)
        }
    }

    // MARK: - Sin nada seleccionado

    @ViewBuilder
    private var vacio: some View {
        Text(antetitulo)
            .font(.system(size: 11, weight: .bold))
            .kerning(0.55)
            .foregroundStyle(.secondary)
        Text(L.t("Nada seleccionado", "Nothing selected"))
            .font(.system(size: 19, weight: .bold))
            .padding(.top, 5)
        Text(subtituloVacio)
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
    }

    private var antetitulo: String {
        switch seccion {
        case .porRevisar: return L.t("BANDEJA", "TRAY")
        case .reportes:   return L.t("REPORTE", "REPORT")
        case .config:     return L.t("CONFIGURACIÓN", "SETTINGS")
        case .registro:   return L.t("REGISTRO", "LOG")
        case .servicios:  return L.t("SERVICIOS", "SERVICES")
        default:          return seccion.titulo.uppercased()
        }
    }

    private var subtituloVacio: String {
        switch seccion {
        case .config:
            return L.t("La configuración se edita en el panel de la izquierda",
                       "Settings are edited in the panel on the left")
        case .ingresos, .gastos, .registro, .servicios, .miembros, .membresia, .depositos:
            return L.t("Elige una fila para ver su ficha aquí",
                       "Pick a row to see its details here")
        default:
            return L.t("Esta pantalla todavía no alimenta el inspector",
                       "This screen does not feed the inspector yet")
        }
    }
}
