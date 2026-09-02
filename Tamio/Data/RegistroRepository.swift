import Foundation

protocol RegistroRepository {
    func apuntes() async -> [Apunte]
    func escribirNota(_ apunte: Apunte) async
}

/// Datos falsos que reproducen el Registro del handoff (13 apuntes). Almacén
/// estático mutable para que "Escribir una nota" persista mientras vive la app.
struct MockRegistroRepository: RegistroRepository {
    private static var almacen: [Apunte] = semilla

    func apuntes() async -> [Apunte] {
        try? await Task.sleep(nanoseconds: 120_000_000)
        return Self.almacen
    }

    func escribirNota(_ apunte: Apunte) async {
        Self.almacen.insert(apunte, at: 0)
    }

    private static var semilla: [Apunte] {
        [
            // HOY
            Apunte(id: 1, area: .secretaria,
                   texto: L.t("El pastor pidió que el corte del domingo se deposite el lunes temprano: en la tarde cierran la sucursal.",
                              "The pastor asked to deposit Sunday's cut early Monday: the branch closes in the afternoon."),
                   autor: "Rocío Ibarra", hora: "12:40", grupo: L.t("HOY", "TODAY"),
                   fecha: L.t("Hoy · 30 de agosto", "Today · Aug 30"), esNota: true),
            Apunte(id: 2, area: .tesoreria,
                   texto: L.t("El corte «Domingo 23 de agosto» llegó al banco", "The «Sunday Aug 23» cut reached the bank"),
                   autor: "Tamio", hora: "11:05", grupo: L.t("HOY", "TODAY"),
                   fecha: L.t("Hoy · 30 de agosto", "Today · Aug 30")),
            Apunte(id: 3, area: .tesoreria,
                   texto: L.t("Marta Solís dio la segunda firma del corte «Domingo 23 de agosto» (conteo)",
                              "Marta Solís gave the second signature of the «Sunday Aug 23» cut (count)"),
                   autor: "Tamio", hora: "10:52", grupo: L.t("HOY", "TODAY"),
                   fecha: L.t("Hoy · 30 de agosto", "Today · Aug 30")),
            Apunte(id: 4, area: .secretaria,
                   texto: L.t("Se emitió la carta CAR‑2026‑0031 a Javier Medina Rojas", "Letter CAR‑2026‑0031 issued to Javier Medina Rojas"),
                   autor: "Tamio", hora: "09:34", grupo: L.t("HOY", "TODAY"),
                   fecha: L.t("Hoy · 30 de agosto", "Today · Aug 30"), folio: "CAR‑2026‑0031"),
            Apunte(id: 5, area: .tesoreria,
                   texto: L.t("Salió de la caja el corte «Domingo 23 de agosto», con 18 movimiento(s)",
                              "The «Sunday Aug 23» cut left the cash box, with 18 entries"),
                   autor: "Tamio", hora: "09:02", grupo: L.t("HOY", "TODAY"),
                   fecha: L.t("Hoy · 30 de agosto", "Today · Aug 30")),
            // AYER
            Apunte(id: 6, area: .tesoreria,
                   texto: L.t("El corte «Miércoles 19 de agosto» NO cuadró: se contaron $4,180.00 y no coincide con lo registrado",
                              "The «Wednesday Aug 19» cut did NOT match: $4,180.00 counted, doesn't match records"),
                   autor: "Tamio", hora: "19:22", grupo: L.t("AYER", "YESTERDAY"),
                   fecha: L.t("Ayer · 29 de agosto", "Yesterday · Aug 29"), esAlerta: true),
            Apunte(id: 7, area: .secretaria,
                   texto: L.t("Se cerró el acta «Junta ordinaria de agosto» (ACT‑2026‑0004)", "Minutes «August ordinary meeting» closed (ACT‑2026‑0004)"),
                   autor: "Tamio", hora: "18:40", grupo: L.t("AYER", "YESTERDAY"),
                   fecha: L.t("Ayer · 29 de agosto", "Yesterday · Aug 29"), folio: "ACT‑2026‑0004"),
            Apunte(id: 8, area: .tesoreria,
                   texto: L.t("Faltó el comprobante del gasto de mantenimiento. Rubén lo trae el domingo.",
                              "The maintenance expense receipt was missing. Rubén brings it Sunday."),
                   autor: "Luis Aguilar", hora: "17:15", grupo: L.t("AYER", "YESTERDAY"),
                   fecha: L.t("Ayer · 29 de agosto", "Yesterday · Aug 29"), esNota: true),
            Apunte(id: 9, area: .secretaria,
                   texto: L.t("Ana Beltrán Ríos pasó de Visitante a Miembro", "Ana Beltrán Ríos went from Visitor to Member"),
                   autor: "Tamio", hora: "12:03", grupo: L.t("AYER", "YESTERDAY"),
                   fecha: L.t("Ayer · 29 de agosto", "Yesterday · Aug 29")),
            Apunte(id: 10, area: .tesoreria,
                   texto: L.t("Se eliminó el movimiento «Ofrenda misionera» de $1,250.00 (folio 2026‑0042)",
                              "The «Mission offering» entry of $1,250.00 was deleted (folio 2026‑0042)"),
                   autor: "Tamio", hora: "10:18", grupo: L.t("AYER", "YESTERDAY"),
                   fecha: L.t("Ayer · 29 de agosto", "Yesterday · Aug 29"), folio: "2026‑0042"),
            // 22 AGO 2026
            Apunte(id: 11, area: .secretaria,
                   texto: L.t("Carmen Ortiz Salinas se dio de baja del padrón (traslado a otra iglesia)",
                              "Carmen Ortiz Salinas was removed from the roll (transfer to another church)"),
                   autor: "Tamio", hora: "20:10", grupo: "22 AGO 2026",
                   fecha: L.t("22 de agosto", "Aug 22")),
            Apunte(id: 12, area: .secretaria,
                   texto: L.t("Se emitió la carta CAR‑2026‑0029 a Carmen Ortiz Salinas", "Letter CAR‑2026‑0029 issued to Carmen Ortiz Salinas"),
                   autor: "Tamio", hora: "19:55", grupo: "22 AGO 2026",
                   fecha: L.t("22 de agosto", "Aug 22"), folio: "CAR‑2026‑0029"),
            Apunte(id: 13, area: .tesoreria,
                   texto: L.t("El corte «Domingo 16 de agosto» llegó al banco", "The «Sunday Aug 16» cut reached the bank"),
                   autor: "Tamio", hora: "13:20", grupo: "22 AGO 2026",
                   fecha: L.t("22 de agosto", "Aug 22")),
        ]
    }
}
