import Foundation

enum FiltroMiembro { case activos, bajas, todos }

protocol MiembrosRepository {
    func lista(filtro: FiltroMiembro) async throws -> [Aportante]
    func crear(_ a: Aportante) async throws
    func actualizar(_ a: Aportante) async throws
    func eliminar(id: String) async throws
}

/// Datos falsos que reproducen la pantalla Aportantes del handoff. Struct con
/// almacén ESTÁTICO para que el CRUD persista durante la sesión.
struct MockMiembrosRepository: MiembrosRepository {
    private static var almacen: [Aportante] = MockMiembrosRepository.todos

    /// Aportantes activos, los que lista la pantalla por defecto. La sidebar
    /// del iPad lo lee para su badge, que antes era un 248 escrito a mano.
    static var activosCount: Int { almacen.filter { $0.estado != .baja }.count }

    func lista(filtro: FiltroMiembro) async throws -> [Aportante] {
        try? await Task.sleep(nanoseconds: 120_000_000)
        switch filtro {
        case .activos: return Self.almacen.filter { $0.estado != .baja }
        case .bajas: return Self.almacen.filter { $0.estado == .baja }
        case .todos: return Self.almacen
        }
    }

    func crear(_ a: Aportante) async throws {
        var nuevo = a
        if nuevo.id.isEmpty { nuevo.id = UUID().uuidString }
        Self.almacen.append(nuevo)
    }
    func actualizar(_ a: Aportante) async throws {
        if let i = Self.almacen.firstIndex(where: { $0.id == a.id }) { Self.almacen[i] = a }
    }
    func eliminar(id: String) async throws {
        Self.almacen.removeAll { $0.id == id }
    }

    private static func serie(_ base: Int) -> [MesAporte] {
        // Las etiquetas iban sin `L.mes`: la gráfica de asistencia de
        // Secretaría (MembresiaRepository) sí lo hacía, así que en inglés una
        // decía "Jan Feb Mar" y esta "Ene Feb Mar" en la misma app.
        let et = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago"].map(L.mes)
        let vals = [3_000_00, 3_200_00, 3_600_00, 3_100_00, 3_300_00, 3_600_00, 3_300_00, base]
        return zip(et, vals).map { MesAporte(mes: $0.0, monto: $0.1) }
    }

    /// Historial de aportes hacia atrás desde hace `diasDesdeUltimo`, uno cada
    /// `cada` días. Las fechas son relativas a hoy a propósito: con fechas
    /// fijas, la constancia de todo el mundo se pudriría con el paso del tiempo.
    private static func historial(diasDesdeUltimo: Int, cada: Int, montos: [Centavos]) -> [Aporte] {
        let cal = Calendar.current
        return montos.enumerated().compactMap { i, monto in
            guard let f = cal.date(byAdding: .day, value: -(diasDesdeUltimo + cada * i), to: Date())
            else { return nil }
            return Aporte(id: "\(i)", concepto: L.t("Diezmo", "Tithe"), fecha: f, monto: monto)
        }
    }

    private static var todos: [Aportante] {
        func mk(_ id: String, _ nombre: String, _ estado: EstadoMiembro, _ rol: String, _ desde: String,
                _ tel: String, _ correo: String, _ total: Centavos, _ idf: String,
                _ frecuencia: FrecuenciaAporte = .semanal,
                _ diasDesdeUltimo: Int = 4) -> Aportante {
            Aportante(
                id: id, nombre: nombre, estado: estado, rol: rol, miembroDesde: desde,
                telefono: tel, correo: correo,
                nacimiento: L.t("20 sep 1987", "Sep 20, 1987"),
                direccion: L.t("Priv. Los Encinos 8, Guadalupe", "8 Los Encinos, Guadalupe"),
                estadoCivil: L.t("Casado", "Married"),
                idFiscal: idf, congregaDesde: "2016",
                frecuencia: frecuencia,
                aportesTotal: total,
                aportesPromedio: L.t("Promedio $3,275.00 en 8 meses con aporte", "Avg $3,275.00 over 8 months"),
                aportesSerie: serie(3_200_00),
                aportes: historial(diasDesdeUltimo: diasDesdeUltimo,
                                   cada: frecuencia.dias ?? 30,
                                   montos: [3_200_00, 3_200_00, 3_600_00, 3_200_00,
                                            3_400_00, 3_200_00, 3_200_00]),
                familia: [
                    Pariente(id: "1", relacion: L.t("Cónyuge", "Spouse"), nombre: "Ana Lucía Torres"),
                    Pariente(id: "2", relacion: L.t("Hijo", "Son"), nombre: "Diego Medina Torres"),
                ]
            )
        }
        // Los `diasDesdeUltimo` están repartidos a propósito para que se vean
        // los tres casos: al día, con un retraso pequeño, y ya pasado el aviso.
        return [
            mk("1", "Ana Lucía Torres Beltrán", .activo, L.t("diezmo", "tithe"), "2018", "81 1010 2020", "ana.torres@correo.mx", 19_600_00, "TOBA880101AB1", .semanal, 3),
            mk("2", "Javier Medina Cruz", .traslado, L.t("diezmo", "tithe"), "2016", "81 8899 1020", "jmedina@outlook.com", 26_200_00, "MECJ870920K44", .semanal, 26),
            mk("3", "Jorge Hernández Ríos", .activo, L.t("diezmo", "tithe"), "2014", "81 1234 0000", "jorge.hernandez@correo.mx", 4_050_00, "HERJ840505CD2", .mensual, 12),
            mk("4", "Karla Villalobos Ruiz", .activo, L.t("diezmo", "tithe"), "2018", "81 4444 5555", "karla.villalobos@correo.mx", 34_200_00, "VIRK900303EF3", .semanal, 5),
            mk("5", "Lucía Márquez Peña", .activo, L.t("donador", "donor"), "2019", "81 5555 6666", "lucia.marquez@correo.mx", 5_300_00, "MAPL910707GH4", .ocasional, 60),
            mk("6", "María Hernández Ríos", .activo, L.t("diezmo", "tithe"), "2014", "81 1234 5678", "maria.hernandez@correo.mx", 31_000_00, "HERM780314IJ5", .semanal, 2),
            mk("7", "Pedro Salas Aguirre", .activo, L.t("diezmo", "tithe"), "2016", "81 8888 9999", "pedro.salas@correo.mx", 42_200_00, "SAAP850808KL6", .quincenal, 9),
            mk("8", "Rubén Cázares Ortiz", .activo, L.t("diezmo", "tithe"), "2017", "81 7070 8080", "ruben.cazares@correo.mx", 8_400_00, "CAOR820202MN7", .semanal, 24),
            mk("9", "Sofía Nájera Ríos", .activo, L.t("donador", "donor"), "2020", "81 9090 1010", "sofia.najera@correo.mx", 10_100_00, "NARS930909OP8", .mensual, 95),
            mk("10", "Tomás Robles Leal", .baja, L.t("baja", "removed"), "2013", "81 2323 4545", "tomas.robles@correo.mx", 6_800_00, "ROLT800606QR9", .ocasional, 200),
            mk("11", "Verónica Ibarra Sosa", .baja, L.t("baja", "removed"), "2015", "81 6767 8989", "veronica.ibarra@correo.mx", 3_900_00, "IASV860404ST0", .ocasional, 300),
        ]
    }
}
