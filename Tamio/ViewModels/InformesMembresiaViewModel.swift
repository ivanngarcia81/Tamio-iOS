import Foundation

// MARK: - Tipo de periodo para informes

enum PeriodoInforme: String, CaseIterable {
    case mes, trimestre, anio, rango, todo

    var etiqueta: String {
        switch self {
        case .mes:       return L.t("Mes", "Month")
        case .trimestre: return L.t("Trimestre", "Quarter")
        case .anio:      return L.t("Año", "Year")
        case .rango:     return L.t("Rango", "Range")
        case .todo:      return L.t("Todo", "All time")
        }
    }
}

// MARK: - ViewModel

@Observable
final class InformesMembresiaViewModel {

    // Selección de tipo de periodo
    var periodoTipo: PeriodoInforme = .anio

    // Sub-selectores según tipo
    var mesSeleccionado: Int = 8          // 1-12
    var trimestreSeleccionado: Int = 3    // 1-4
    var añoSeleccionado: Int = 2026
    var rangoDesde: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var rangoHasta: Date = Date()

    // Informe activo en la lista
    var informeSeleccionado = 0   // 0 General · 1 Miembros · 2 Asistencia · 3 Seguimiento

    // MARK: - Etiqueta del periodo seleccionado

    var etiquetaPeriodo: String {
        switch periodoTipo {
        case .mes:
            return "\(Self.nombreMes(mesSeleccionado)) \(String(añoSeleccionado))"
        case .trimestre:
            let mesesQ = Self.mesesDelTrimestre(trimestreSeleccionado)
            return "Q\(trimestreSeleccionado) \(String(añoSeleccionado)) · \(mesesQ)"
        case .anio:
            return L.t("Año \(String(añoSeleccionado))", "Year \(String(añoSeleccionado))")
        case .rango:
            return "\(Self.fmtCorto.string(from: rangoDesde)) – \(Self.fmtCorto.string(from: rangoHasta))"
        case .todo:
            return L.t("Todo el historial", "All time")
        }
    }

    // MARK: - Resumen según periodo activo

    var resumen: InformeResumen {
        switch periodoTipo {
        case .mes:       return Self.resumenMes(mes: mesSeleccionado, año: añoSeleccionado)
        case .trimestre: return Self.resumenTrimestre(q: trimestreSeleccionado, año: añoSeleccionado)
        case .anio:      return Self.resumenAnio(año: añoSeleccionado)
        case .rango:     return Self.resumenRango
        case .todo:      return Self.resumenTodo
        }
    }

    // MARK: - Helpers de nombre

    static func nombreMes(_ m: Int) -> String {
        let cortos = L.t("Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic",
                         "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec")
            .split(separator: " ").map(String.init)
        return m >= 1 && m <= 12 ? cortos[m - 1] : "?"
    }

    static func mesesDelTrimestre(_ q: Int) -> String {
        switch q {
        case 1: return L.t("Ene–Mar", "Jan–Mar")
        case 2: return L.t("Abr–Jun", "Apr–Jun")
        case 3: return L.t("Jul–Sep", "Jul–Sep")
        case 4: return L.t("Oct–Dic", "Oct–Dec")
        default: return "Q\(q)"
        }
    }

    private static let fmtCorto: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yy"; f.locale = Locale(identifier: "es_MX"); return f
    }()

    // MARK: - Mock data por periodo

    private static func resumenMes(mes: Int, año: Int) -> InformeResumen {
        let altas = [3, 1, 2, 4, 2, 1, 5, 3, 0, 0, 0, 0]
        let n = nombreMes(mes)
        return InformeResumen(
            totalMiembros: 248,
            periodo: "\(n) \(año)",
            porEstado: [
                (L.t("Activo", "Active"), 236),
                (L.t("Nuevo", "New"), 7),
                (L.t("Traslado", "Transfer"), 2),
                (L.t("Inactivo", "Inactive"), 3),
            ],
            porMinisterio: [
                (L.t("Enseñanza", "Teaching"), 46),
                (L.t("Música", "Music"), 38),
                (L.t("Ujieres", "Ushers"), 24),
                (L.t("Niños", "Children"), 22),
            ],
            expedienteCompleto: 227, expedienteIncompleto: 21,
            altasPorMes: [MesAlta(id: 1, mes: n, altas: mes <= 12 ? altas[mes - 1] : 0)],
            traslados: [trasladoJavier]
        )
    }

    private static func resumenTrimestre(q: Int, año: Int) -> InformeResumen {
        let grupos: [[Int]] = [[1,2,3],[4,5,6],[7,8,9],[10,11,12]]
        let meses = grupos[min(q - 1, 3)]
        let altasData = [3, 1, 2, 4, 2, 1, 5, 3, 0, 0, 0, 0]
        return InformeResumen(
            totalMiembros: 248,
            periodo: "Q\(q) \(año) · \(mesesDelTrimestre(q))",
            porEstado: [
                (L.t("Activo", "Active"), 236),
                (L.t("Nuevo", "New"), 9),
                (L.t("Traslado", "Transfer"), 2),
                (L.t("Inactivo", "Inactive"), 1),
            ],
            porMinisterio: [
                (L.t("Enseñanza", "Teaching"), 46),
                (L.t("Música", "Music"), 38),
                (L.t("Ujieres", "Ushers"), 24),
                (L.t("Niños", "Children"), 22),
                (L.t("Medios", "Media"), 14),
            ],
            expedienteCompleto: 240, expedienteIncompleto: 8,
            altasPorMes: meses.enumerated().map { idx, m in
                MesAlta(id: idx + 1, mes: nombreMes(m), altas: altasData[m - 1])
            },
            traslados: [trasladoJavier, trasladoDaniel]
        )
    }

    private static func resumenAnio(año: Int) -> InformeResumen {
        InformeResumen(
            totalMiembros: 262,
            periodo: L.t("Año \(año)", "Year \(año)"),
            porEstado: [
                (L.t("Activo", "Active"), 248),
                (L.t("Inactivo", "Inactive"), 6),
                (L.t("Visitante", "Visitor"), 4),
                (L.t("En proceso", "In process"), 2),
                (L.t("Trasladado", "Transferred"), 2),
            ],
            porMinisterio: [
                (L.t("Enseñanza", "Teaching"), 46),
                (L.t("Música", "Music"), 38),
                (L.t("Ujieres", "Ushers"), 24),
                (L.t("Niños", "Children"), 22),
                (L.t("Medios", "Media"), 14),
                (L.t("Cocina", "Kitchen"), 12),
            ],
            expedienteCompleto: 250, expedienteIncompleto: 12,
            altasPorMes: [
                MesAlta(id: 1,  mes: L.t("ene","jan"), altas: 3),
                MesAlta(id: 2,  mes: L.t("feb","feb"), altas: 1),
                MesAlta(id: 3,  mes: L.t("mar","mar"), altas: 2),
                MesAlta(id: 4,  mes: L.t("abr","apr"), altas: 4),
                MesAlta(id: 5,  mes: L.t("may","may"), altas: 2),
                MesAlta(id: 6,  mes: L.t("jun","jun"), altas: 1),
                MesAlta(id: 7,  mes: L.t("jul","jul"), altas: 5),
                MesAlta(id: 8,  mes: L.t("ago","aug"), altas: 3),
            ],
            traslados: [trasladoJavier, trasladoDaniel, trasladoRosa]
        )
    }

    private static let resumenRango = InformeResumen(
        totalMiembros: 248,
        periodo: L.t("Rango personalizado", "Custom range"),
        porEstado: [
            (L.t("Activo", "Active"), 236),
            (L.t("Nuevo", "New"), 5),
            (L.t("Traslado", "Transfer"), 2),
        ],
        porMinisterio: [
            (L.t("Enseñanza", "Teaching"), 44),
            (L.t("Música", "Music"), 36),
            (L.t("Ujieres", "Ushers"), 22),
        ],
        expedienteCompleto: 235, expedienteIncompleto: 13,
        altasPorMes: [
            MesAlta(id: 1, mes: L.t("jul","jul"), altas: 2),
            MesAlta(id: 2, mes: L.t("ago","aug"), altas: 3),
        ],
        traslados: [trasladoJavier, trasladoDaniel]
    )

    private static let resumenTodo = InformeResumen(
        totalMiembros: 280,
        periodo: L.t("Todo el historial", "All time"),
        porEstado: [
            (L.t("Activo", "Active"), 248),
            (L.t("Inactivo", "Inactive"), 12),
            (L.t("Visitante", "Visitor"), 8),
            (L.t("Trasladado", "Transferred"), 10),
            (L.t("Baja", "Removed"), 2),
        ],
        porMinisterio: [
            (L.t("Enseñanza", "Teaching"), 52),
            (L.t("Música", "Music"), 44),
            (L.t("Ujieres", "Ushers"), 30),
            (L.t("Niños", "Children"), 28),
            (L.t("Medios", "Media"), 18),
            (L.t("Cocina", "Kitchen"), 14),
        ],
        expedienteCompleto: 265, expedienteIncompleto: 15,
        altasPorMes: [
            MesAlta(id: 1,  mes: "2024", altas: 18),
            MesAlta(id: 2,  mes: "2025", altas: 22),
            MesAlta(id: 3,  mes: "2026", altas: 21),
        ],
        traslados: [trasladoJavier, trasladoDaniel, trasladoRosa]
    )

    // MARK: - Exportación

    var csvExportString: String {
        let r = resumen
        var lines: [String] = []
        lines.append(L.t("Informe de Membresía", "Membership Report") + ",\(r.periodo)")
        lines.append(L.t("Total de miembros", "Total members") + ",\(r.totalMiembros)")
        lines.append("")
        lines.append(L.t("Por Estado", "By Status"))
        lines.append(L.t("Estado,Cantidad", "Status,Count"))
        r.porEstado.forEach { lines.append("\($0.0),\($0.1)") }
        lines.append("")
        lines.append(L.t("Por Ministerio", "By Ministry"))
        lines.append(L.t("Ministerio,Cantidad", "Ministry,Count"))
        r.porMinisterio.forEach { lines.append("\($0.0),\($0.1)") }
        lines.append("")
        lines.append(L.t("Altas por mes", "New per month"))
        lines.append(L.t("Mes,Altas", "Month,New"))
        r.altasPorMes.forEach { lines.append("\($0.mes),\($0.altas)") }
        lines.append("")
        lines.append(L.t("Expediente completo,Expediente incompleto",
                         "File complete,File incomplete"))
        lines.append("\(r.expedienteCompleto),\(r.expedienteIncompleto)")
        lines.append("")
        lines.append(L.t("Movimientos de traslado", "Transfer movements"))
        lines.append(L.t("Folio,Tipo,Persona,Iglesia,Fecha,Estado",
                         "Folio,Type,Person,Church,Date,Status"))
        r.traslados.forEach { t in
            lines.append([t.folio, t.tipoTraslado, t.persona, t.iglesia, t.fecha, t.estado]
                .map { "\"\($0)\"" }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    var textoInforme: String {
        let r = resumen
        var t = ""
        t += L.t("INFORME DE MEMBRESÍA", "MEMBERSHIP REPORT") + "\n"
        t += r.periodo + "\n"
        t += String(repeating: "─", count: 40) + "\n\n"
        t += L.t("Total de miembros: \(r.totalMiembros)", "Total members: \(r.totalMiembros)") + "\n\n"
        t += L.t("MIEMBROS POR ESTADO", "MEMBERS BY STATUS") + "\n"
        r.porEstado.forEach { t += "  \($0.0): \($0.1)\n" }
        t += "\n" + L.t("MIEMBROS POR MINISTERIO", "MEMBERS BY MINISTRY") + "\n"
        r.porMinisterio.forEach { t += "  \($0.0): \($0.1)\n" }
        t += "\n" + L.t("ALTAS POR MES", "NEW PER MONTH") + "\n"
        r.altasPorMes.forEach { t += "  \($0.mes): \($0.altas)\n" }
        t += "\n" + L.t("ESTADO DEL EXPEDIENTE", "FILE STATUS") + "\n"
        t += "  " + L.t("Completo: \(r.expedienteCompleto)", "Complete: \(r.expedienteCompleto)") + "\n"
        t += "  " + L.t("Incompleto: \(r.expedienteIncompleto)", "Incomplete: \(r.expedienteIncompleto)") + "\n"
        t += "\n" + L.t("MOVIMIENTOS DE TRASLADO", "TRANSFER MOVEMENTS") + "\n"
        r.traslados.forEach { t += "  \($0.folio) · \($0.tipoTraslado) · \($0.persona) · \($0.estado)\n" }
        return t
    }

    // MARK: - Traslados mock compartidos

    private static let trasladoJavier = MovimientoTraslado(
        id: 1, folio: "TS-2026-014", tipoTraslado: L.t("Enviado","Sent"),
        persona: "Javier Medina Cruz",
        iglesia: L.t("Iglesia Betel · Saltillo","Iglesia Betel · Saltillo"),
        fecha: "12 ago 2026", estado: L.t("Pendiente de firma","Awaiting signature"))

    private static let trasladoDaniel = MovimientoTraslado(
        id: 2, folio: "TE-2026-007", tipoTraslado: L.t("Recibido","Received"),
        persona: "Daniel Guerra Salinas",
        iglesia: L.t("Iglesia Emanuel · Torreón","Iglesia Emanuel · Torreón"),
        fecha: "6 jul 2026", estado: L.t("Completado","Completed"))

    private static let trasladoRosa = MovimientoTraslado(
        id: 3, folio: "TS-2026-011", tipoTraslado: L.t("Enviado","Sent"),
        persona: "Rosa Elena Vega",
        iglesia: L.t("Iglesia Getsemaní · Reynosa","Iglesia Getsemaní · Reynosa"),
        fecha: "14 mar 2026", estado: L.t("Entregado","Delivered"))
}
