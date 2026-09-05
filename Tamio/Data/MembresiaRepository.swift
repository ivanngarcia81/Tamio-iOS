import Foundation
import GRDB

protocol MembresiaRepository {
    func lista() async throws -> [Miembro]
    func resumen() async -> MembresiaResumen
    func asistenciaResumen() async -> AsistenciaResumen
    /// Alta o edición: la misma función, como en el web. Lo que llega es la
    /// ficha entera; el repositorio decide si inserta o actualiza.
    func guardar(_ m: Miembro) async throws
    func agregarPariente(miembroId: String, _ p: Pariente) async throws
    func quitarPariente(id: String) async throws
}

/// Datos falsos que reproducen la pantalla de Membresía del handoff.
struct MockMembresiaRepository: MembresiaRepository {
    /// Cifras del padrón completo de la congregación. El hub de Secretaría las
    /// lee de aquí en vez de llevar su propio número: antes anunciaba "14
    /// personas" mientras esta misma pantalla encabezaba 248 / 236.
    /// 236 + 6 + 6 = 248, el total que ya encabezaba la pantalla.
    static let resumenPadron = MembresiaResumen(
        activos: 236, inactivos: 6, bajas: 6,
        nuevos: 14, recibidos: 3, trasladados: 5,
        ausencias: 9, incompletos: 21)

    func resumen() async -> MembresiaResumen { Self.resumenPadron }

    func asistenciaResumen() async -> AsistenciaResumen {
        AsistenciaResumen(
            promedioPct: 74,
            serviciosPeriodo: 27,
            presentesPromedio: 186,
            mejorServicio: L.t("214 · 23 ago", "214 · Aug 23"),
            meses: [
                MesAsistenciaCongregacion(mes: L.t("Ene","Jan"), presentes: 168, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Feb","Feb"), presentes: 182, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Mar","Mar"), presentes: 164, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Abr","Apr"), presentes: 196, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("May","May"), presentes: 176, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Jun","Jun"), presentes: 204, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Jul","Jul"), presentes: 158, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Ago","Aug"), presentes: 214, enRoster: 230),
            ],
            porTipo: [
                TipoAsistencia(tipo: L.t("Culto matutino",    "Morning service"),  promedio: 186),
                TipoAsistencia(tipo: L.t("Culto vespertino",  "Evening service"),  promedio: 108),
                TipoAsistencia(tipo: L.t("Reunión de oración","Prayer meeting"),   promedio: 74),
                TipoAsistencia(tipo: L.t("Escuela bíblica",   "Bible school"),     promedio: 62),
            ]
        )
    }

    /// Almacén ESTÁTICO para que el CRUD persista durante la sesión, como
    /// hace `MockMiembrosRepository`.
    private static var almacen: [Miembro] = MockMembresiaRepository.miembros

    func lista() async throws -> [Miembro] {
        try? await Task.sleep(nanoseconds: 120_000_000)
        return Self.almacen
    }

    func guardar(_ m: Miembro) async throws {
        if let i = Self.almacen.firstIndex(where: { $0.id == m.id }) { Self.almacen[i] = m }
        else { Self.almacen.insert(m, at: 0) }
    }

    func agregarPariente(miembroId: String, _ p: Pariente) async throws {
        guard let i = Self.almacen.firstIndex(where: { $0.id == miembroId }) else { return }
        Self.almacen[i].familia.append(p)
    }

    func quitarPariente(id: String) async throws {
        for i in Self.almacen.indices { Self.almacen[i].familia.removeAll { $0.id == id } }
    }

    private static func serie(_ base: Double) -> [MesAsistencia] {
        let et = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago"].map(L.mes)
        let vals = [0.7, 0.85, 0.6, 0.9, 0.8, 0.95, 0.88, base]
        return zip(et, vals).map { MesAsistencia(mes: $0.0, valor: $0.1) }
    }

    /// Los mismos ocho de siempre, ya con forma de fila: las claves del web,
    /// las fechas "YYYY-MM-DD" y sin un solo texto de pantalla guardado —eso
    /// lo calcula `Miembro`—. La asistencia sigue siendo inventada hasta la
    /// v16.
    private static var miembros: [Miembro] {
        var m1 = Miembro(id: "1", nombre: "María Hernández Ríos")
        m1.telefono = "81 1234 5678"; m1.correo = "maria.hernandez@correo.mx"
        m1.direccion = "Av. Constitución 123"; m1.estadoCivil = "casado"; m1.nacimiento = "1978-03-14"
        m1.fechaIngreso = "2014-03-14"; m1.fechaCongregacion = "2012-06-01"
        m1.bautizadoAgua = true; m1.fechaBautismoAgua = "2014-04-12"
        m1.ministerios = ["ensenanza", "ninos"]; m1.cargos = ["maestro"]; m1.instrumentos = ["voz"]
        m1.asistenciaPct = 96; m1.asistencia = serie(0.96)
        m1.enRoster = L.t("26 de 27", "26 of 27"); m1.rachaSinAsistir = L.t("0 servicios", "0 services")
        m1.ultimaVisita = L.fecha("23 ago")

        var m2 = Miembro(id: "2", nombre: "Lucía Márquez Peña")
        m2.telefono = "81 5555 6666"; m2.correo = "lucia.marquez@correo.mx"
        m2.fechaIngreso = "2019-02-08"; m2.fechaCongregacion = "2018-10-01"
        m2.bautizadoAgua = true; m2.fechaBautismoAgua = "2019-03-15"
        m2.ministerios = ["musica"]; m2.cargos = ["Coordinadora escuela bíblica"]
        m2.asistenciaPct = 92; m2.asistencia = serie(0.92)
        m2.enRoster = L.t("25 de 27", "25 of 27"); m2.rachaSinAsistir = L.t("0 servicios", "0 services")
        m2.ultimaVisita = L.fecha("23 ago")

        var m3 = Miembro(id: "3", nombre: "Pedro Salas Aguirre")
        m3.telefono = "81 7777 8888"; m3.correo = "pedro.salas@correo.mx"; m3.direccion = "Calle Hidalgo 45"
        m3.estadoCivil = "casado"; m3.nacimiento = "1985-09-02"
        m3.fechaIngreso = "2021-06-12"; m3.fechaCongregacion = "2021-01-10"
        m3.bautizadoAgua = true; m3.fechaBautismoAgua = "2021-08-01"
        m3.ministerios = ["ujieres"]; m3.habilidades = ["electricidad"]
        m3.asistenciaPct = 88; m3.asistencia = serie(0.88)
        m3.enRoster = L.t("24 de 27", "24 of 27"); m3.rachaSinAsistir = L.t("0 servicios", "0 services")
        m3.ultimaVisita = L.fecha("23 ago")

        // Traslado EN CURSO: sigue activo hasta que se cierre. El expediente
        // vivirá en `traslados_salida`; mientras, aquí no se ve.
        var m4 = Miembro(id: "4", nombre: "Javier Medina Cruz")
        m4.telefono = "81 8899 1020"; m4.correo = "jmedina@outlook.com"
        m4.fechaIngreso = "2016-05-20"; m4.bautizadoAgua = true
        m4.asistenciaPct = 41; m4.asistencia = serie(0.41)
        m4.enRoster = L.t("11 de 27", "11 of 27"); m4.rachaSinAsistir = L.t("4 servicios", "4 services")
        m4.ultimaVisita = L.fecha("26 jul")
        m4.seguimientoRazon = L.t("Cuatro servicios sin asistir · traslado en curso", "Four services missed · transfer in progress")
        m4.ausenciaNota = L.t(" · traslado", " · transfer")

        var m5 = Miembro(id: "5", nombre: "Ana Lucía Torres")
        m5.telefono = "81 1010 2020"; m5.correo = "ana.torres@correo.mx"; m5.estadoCivil = "casado"
        m5.fechaIngreso = "2016-08-14"; m5.bautizadoAgua = true; m5.fechaBautismoAgua = "2016-09-04"
        m5.ministerios = ["intercesion"]
        m5.asistenciaPct = 62; m5.asistencia = serie(0.62)
        m5.enRoster = L.t("17 de 27", "17 of 27"); m5.rachaSinAsistir = L.t("2 servicios", "2 services")
        m5.ultimaVisita = L.fecha("9 ago")
        m5.seguimientoRazon = L.t("Dos servicios sin asistir", "Two services missed")
        m5.ausenciaNota = L.t(" · enfermedad", " · illness")

        var m6 = Miembro(id: "6", nombre: "Familia Ruvalcaba")
        m6.telefono = "81 3030 4040"; m6.fechaIngreso = "2015-11-01"
        m6.ministerios = ["cocina"]; m6.notas = L.t("Cuatro miembros · diezman juntos", "Four members · tithe together")
        m6.asistenciaPct = 84; m6.asistencia = serie(0.84)
        m6.enRoster = L.t("23 de 27", "23 of 27"); m6.rachaSinAsistir = L.t("0 servicios", "0 services")
        m6.ultimaVisita = L.fecha("23 ago")

        // Recibido por traslado ESTE año: nuevo y recibido a la vez, que es
        // lo que el enum viejo no dejaba ser.
        var m7 = Miembro(id: "7", nombre: "Daniel Guerra Salinas")
        m7.telefono = "81 6060 7070"; m7.correo = "daniel.guerra@correo.mx"
        m7.fechaIngreso = Fechas.claveDia(); m7.iglesiaAnterior = "Iglesia Bautista Getsemaní, Saltillo"
        m7.bautizadoAgua = true; m7.fechaBautismoAgua = "2011-05-22"; m7.ministerios = ["medios"]
        m7.asistenciaPct = 78; m7.asistencia = serie(0.78)
        m7.enRoster = L.t("7 de 9", "7 of 9"); m7.rachaSinAsistir = L.t("0 servicios", "0 services")
        m7.ultimaVisita = L.fecha("23 ago")
        m7.seguimientoRazon = L.t("Nuevo en el periodo", "New in the period")

        var m8 = Miembro(id: "8", nombre: "Rosa Elena Vega")
        m8.telefono = "81 9090 0101"; m8.fechaIngreso = "2013-08-11"
        m8.estado = .baja("2026-03-14", "traslado")
        m8.historialEstados = [CambioEstado(de: "activo", a: "trasladado", fecha: "2026-03-14")]
        m8.bautizadoAgua = true; m8.fechaBautismoAgua = "2013-09-01"
        m8.asistencia = serie(0)
        m8.enRoster = L.t("0 de 27", "0 of 27"); m8.rachaSinAsistir = L.t("27 servicios", "27 services")
        m8.ultimaVisita = L.fecha("14 mar")

        return [m1, m2, m3, m4, m5, m6, m7, m8]
    }
}


// MARK: - El repositorio de verdad

/// El padrón desde la base del teléfono: la fila de `aportante` leída por su
/// otra cara, `MiembroFila`, y los parentescos de `parentesco` resueltos por
/// los dos extremos.
///
/// **Los ocho indicadores se cuentan, no se escriben.** La maqueta tenía
/// `resumenPadron` como constante y el hub de Secretaría la copiaba; aquí
/// salen de las filas, con el mismo criterio que `membresiaStats` en el web:
/// activos son `activo = 1` con registro "activo", las altas son las de
/// `fecha_ingreso` en el año, las bajas las de `fecha_baja` en el año.
///
/// La asistencia todavía no tiene de dónde salir —`servicios` llega con la
/// v16—, así que aquí es un resumen vacío y en la ficha las cadenas quedan en
/// blanco. Mejor un hueco que un número inventado.
struct OfflineMembresiaRepository: MembresiaRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func lista() async throws -> [Miembro] {
        try await cola.read { db in try Self.leer(db) }
    }

    private static func leer(_ db: Database) throws -> [Miembro] {
        let filas = try MiembroFila
            .filter(Column("borrado") == false)
            .order(Column("nombre"))
            .fetchAll(db)
        let nombres = Dictionary(filas.map { ($0.id, $0.nombre) }, uniquingKeysWith: { a, _ in a })
        let parentescos = try ParentescoFila.filter(Column("borrado") == false).fetchAll(db)

        // Una fila por relación, leída desde los dos lados: la de "Ana es
        // hermana de María" se le enseña a María tal cual y a Ana con el
        // inverso. Si el otro extremo no ha bajado todavía, la relación se
        // salta entera —media relación no es una relación—.
        var familia: [String: [Pariente]] = [:]
        for p in parentescos {
            guard let n1 = nombres[p.parienteId], let n2 = nombres[p.miembroId] else { continue }
            familia[p.miembroId, default: []].append(
                Pariente(id: p.id, tipo: p.tipo, parienteId: p.parienteId, nombre: n1))
            familia[p.parienteId, default: []].append(
                Pariente(id: p.id, tipo: Parentescos.inverso[p.tipo] ?? p.tipo,
                         parienteId: p.miembroId, nombre: n2))
        }
        return filas.map { $0.miembro(familia: familia[$0.id] ?? []) }
    }

    func resumen() async -> MembresiaResumen {
        let miembros = (try? await lista()) ?? []
        let año = Calendar.current.component(.year, from: Date())
        let vivos = miembros.filter { !$0.estado.esBaja }
        return MembresiaResumen(
            activos: vivos.filter { $0.estado.registro == .activo }.count,
            inactivos: vivos.filter { $0.estado.registro != .activo }.count,
            bajas: miembros.filter { $0.estado.esBaja }.count,
            nuevos: miembros.filter { $0.esNuevo(en: año) }.count,
            recibidos: miembros.filter { $0.esNuevo(en: año) && $0.esRecibido }.count,
            trasladados: miembros.filter { $0.estado.baja?.motivo == "traslado"
                                            && Int($0.estado.baja?.fecha.prefix(4) ?? "") == año }.count,
            ausencias: 0,
            incompletos: vivos.filter { !$0.expedienteCompleto }.count)
    }

    func asistenciaResumen() async -> AsistenciaResumen {
        AsistenciaResumen(promedioPct: 0, serviciosPeriodo: 0, presentesPromedio: 0,
                          mejorServicio: "—", meses: [], porTipo: [])
    }

    func guardar(_ m: Miembro) async throws {
        try await cola.write { db in
            let previa = try MiembroFila.fetchOne(db, key: m.id)
            try MiembroFila(m, actualizadoEn: previa?.actualizadoEn).save(db)
            try Self.encolar(db, entidad: "miembro", id: m.id,
                             operacion: previa == nil ? .crear : .actualizar)
        }
    }

    func agregarPariente(miembroId: String, _ p: Pariente) async throws {
        try await cola.write { db in
            try ParentescoFila(id: p.id, miembroId: miembroId, parienteId: p.parienteId,
                               tipo: p.tipo, actualizadoEn: nil, borrado: false).insert(db)
            try Self.encolar(db, entidad: "parentesco", id: p.id, operacion: .crear)
        }
    }

    func quitarPariente(id: String) async throws {
        try await cola.write { db in
            guard var fila = try ParentescoFila.fetchOne(db, key: id) else { return }
            fila.borrado = true
            try fila.update(db)
            try Self.encolar(db, entidad: "parentesco", id: id, operacion: .eliminar)
        }
    }

    /// Igual que en los demás repositorios: una sola operación pendiente por
    /// registro, y crear + actualizar sigue siendo crear.
    private static func encolar(_ db: Database, entidad: String, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        let previa = try OperacionPendiente
            .filter(Column("entidad") == entidad && Column("registroId") == id)
            .fetchOne(db)
        let efectiva: OperacionPendiente.Operacion =
            (previa?.operacion == OperacionPendiente.Operacion.crear.rawValue
             && operacion == .actualizar) ? .crear : operacion
        try OperacionPendiente
            .filter(Column("entidad") == entidad && Column("registroId") == id)
            .deleteAll(db)
        var nueva = OperacionPendiente(id: nil, entidad: entidad, registroId: id,
                                       operacion: efectiva.rawValue,
                                       creadoEn: Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}

func repositorioMembresia() -> MembresiaRepository {
    ModoRevision.sinLogin ? MockMembresiaRepository() : OfflineMembresiaRepository()
}

// MARK: - Las familias, para tomar lista sin ir una por una

/// **Una familia es un grupo derivado, no una tabla.**
///
/// Sale de `parentescos`, que ya existe: los enlaces de cónyuge y de
/// padre/hijo dicen quién vive con quién. Guardarla aparte sería un tercer
/// sitio donde la misma verdad puede discrepar — y el web tampoco la tiene.
///
/// **El grupo es la componente conectada sobre `conyuge` y `padre`/`hijo`, y
/// nada más.** Hermanos, abuelos, tíos y primos NO forman grupo por su cuenta:
/// dos hermanos adultos con casas distintas llegan al culto por separado. Los
/// hermanos que sí viven juntos quedan unidos igual, por sus padres, que es el
/// camino correcto.
///
/// **Lo que esto no resuelve, y conviene saberlo:** si el padrón enlaza tres
/// generaciones —la abuela como madre del padre—, las tres salen como una sola
/// familia. Puede ser verdad (viven juntos) o no. Por eso la lista deja
/// desmarcar a cualquiera después: el grupo es un atajo, no una afirmación.
enum Familias {

    /// Los tipos de parentesco que hacen hogar.
    static let deHogar: Set<String> = ["conyuge", "padre", "hijo"]

    /// Reparte a la gente en familias. Quien no tiene parentescos de hogar
    /// sale en un grupo de uno: la lista los trata igual y no hay que
    /// distinguir dos casos al pintarla.
    ///
    /// El apellido del grupo es el más repetido entre sus miembros —el último
    /// del nombre completo—, que es como se llama a una familia en voz alta.
    /// Con empate manda el de la persona de nombre más antiguo en la lista, no
    /// se inventa nada.
    static func agrupar(_ miembros: [Miembro]) -> [Familia] {
        let porId = Dictionary(miembros.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        // Conjuntos disjuntos: unir es barato y el orden de las aristas da
        // igual, que es lo que se quiere de un grafo que llega desordenado.
        var padre: [String: String] = [:]
        func raiz(_ x: String) -> String {
            var r = x
            while let p = padre[r], p != r { r = p }
            var c = x
            while let p = padre[c], p != r { padre[c] = r; c = p }
            return r
        }
        func unir(_ a: String, _ b: String) {
            let (ra, rb) = (raiz(a), raiz(b))
            if ra != rb { padre[ra] = rb }
        }
        for m in miembros { padre[m.id] = m.id }
        for m in miembros {
            for p in m.familia where deHogar.contains(p.tipo) {
                if porId[p.parienteId] != nil { unir(m.id, p.parienteId) }
            }
        }

        var grupos: [String: [Miembro]] = [:]
        for m in miembros { grupos[raiz(m.id), default: []].append(m) }

        return grupos.values
            .map { integrantes in
                Familia(id: integrantes.map(\.id).sorted().joined(separator: "+"),
                        apellido: apellidoComun(integrantes),
                        integrantes: integrantes.sorted { $0.nombre < $1.nombre })
            }
            .sorted { $0.apellido.localizedCompare($1.apellido) == .orderedAscending }
    }

    private static func apellidoComun(_ integrantes: [Miembro]) -> String {
        var cuenta: [String: Int] = [:]
        for m in integrantes {
            guard let ap = m.nombre.split(separator: " ").last.map(String.init) else { continue }
            cuenta[ap, default: 0] += 1
        }
        guard let mayor = cuenta.values.max() else { return "" }
        // Empate: el del primero de la lista, para que no baile entre pasadas.
        for m in integrantes {
            if let ap = m.nombre.split(separator: " ").last.map(String.init), cuenta[ap] == mayor {
                return ap
            }
        }
        return ""
    }
}

/// Un grupo de personas que llega junto al culto. `integrantes` nunca está
/// vacío: quien no tiene parentescos es una familia de uno.
struct Familia: Identifiable, Hashable {
    let id: String
    let apellido: String
    let integrantes: [Miembro]

    var esIndividual: Bool { integrantes.count == 1 }

    /// "Rodríguez · 5", o el nombre a secas cuando va solo.
    var titulo: String {
        esIndividual ? integrantes[0].nombre : "\(apellido) · \(integrantes.count)"
    }
}
