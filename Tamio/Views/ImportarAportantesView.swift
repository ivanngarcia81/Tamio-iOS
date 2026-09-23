import SwiftUI
import UniformTypeIdentifiers

// MARK: - «Trae tus datos» en el iPhone y el iPad
//
// Del handoff «Trae tus datos» (I1–I10 en el iPhone, P1–P5 en el iPad). El
// Mac tiene lo mismo con su propia forma en `TamioMac/TablaAportantes.swift`:
// son apps distintas, no copias. Lo que comparten es lo que decide —
// `ImportadorAportantes`, `ImportadorAportes`, `CSVLector`,
// `PlantillaImportar` y `MiembrosViewModel.importar…`—.
//
// Sustituye a las dos hojas seguidas que había aquí (`MapearColumnasView` e
// `ImportarAportantesView`): el handoff las rehace con el botón principal
// abajo, al alcance del pulgar, y con el «Hecho» dentro de la misma hoja.

// MARK: - La invitación (I1 · P1)

/// **La invitación, una sola vez por aparato**, después de la primera bajada
/// y solo con el padrón vacío (lo decide `TamioApp`). En el iPhone es una
/// página más de la bienvenida, con las tres salidas en el tercio de abajo; en
/// el iPad, el porqué a la izquierda y las salidas a la derecha.
struct TraerDatosView: View {
    let importar: () -> Void
    let despues: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var compacto: Bool { sizeClass == .compact }

    private var titulo: String { L.t("Trae a tu gente", "Bring your people") }
    private var cuerpo: String {
        L.t("Si ya tienes a las personas de la iglesia en un Excel, una hoja de Google u otro sistema, pásalas a Tamio de una vez. No se guarda nada hasta que lo revises.",
            "If your church’s people are already in Excel, a Google Sheet or another system, bring them into Tamio in one go. Nothing is saved until you review it.")
    }
    private var formato: String {
        L.t("Sirve un archivo CSV. En Excel: Archivo › Guardar como › CSV.",
            "Use a CSV file. In Excel: File › Save As › CSV.")
    }
    private var donde: String {
        L.t("Lo encontrarás después en Ajustes › Datos.", "You’ll find it later in Settings › Data.")
    }

    var body: some View {
        if compacto { telefono } else { tableta }
    }

    private var logo: some View {
        Image("LogoTamio")
            .resizable()
            .scaledToFit()
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }

    /// I1: la franja verde arriba y las tres salidas abajo.
    private var telefono: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                logo.frame(width: 52, height: 52).padding(.top, 40)
                Text(titulo)
                    .font(.largeTitle.bold())
                    .padding(.top, 22)
                Text(cuerpo)
                    .font(.body)
                    .opacity(0.92)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.bottom, 30)
            .background(Paleta.brand.ignoresSafeArea(edges: .top))

            VStack(spacing: 12) {
                Text(formato)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                Spacer(minLength: 0)
                Button(action: importar) {
                    Text(L.t("Importar mi lista de personas", "Import my list of people"))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .tint(Paleta.brand)
                BotonPlantilla(tipo: .personas, estilo: .relleno)
                Button(L.t("Lo haré después", "I’ll do it later"), action: despues)
                    .font(.body)
                    .foregroundStyle(Paleta.brand)
                    .frame(minHeight: 44)
                Text(donde)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    /// P1: dos mitades.
    private var tableta: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                logo.frame(width: 64, height: 64)
                Text(titulo)
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-1)
                    .padding(.top, 28)
                Text(cuerpo)
                    .font(.title3)
                    .opacity(0.92)
                    .frame(maxWidth: 440, alignment: .leading)
                    .padding(.top, 16)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Paleta.brand.ignoresSafeArea())

            VStack(spacing: 14) {
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        icono("arrow.down")
                        Text(L.t("Importar mi lista de personas", "Import my list of people"))
                            .font(.title3.weight(.semibold))
                    }
                    Text(L.t("Eliges el archivo, dices qué columna es cuál y ves qué va a pasar antes de guardar.",
                             "Choose the file, say which column is which, and see what will happen before saving."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formato)
                        .font(.subheadline)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Button(action: importar) {
                        Text(L.t("Elegir archivo…", "Choose file…"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .tint(Paleta.brand)
                    .padding(.top, 4)
                }
                .padding(22)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                BotonPlantilla(tipo: .personas, estilo: .tarjeta)

                Spacer()
                VStack(spacing: 6) {
                    Button(L.t("Lo haré después", "I’ll do it later"), action: despues)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Paleta.brand)
                        .padding(12)
                    Text(donde)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func icono(_ nombre: String) -> some View {
        Image(systemName: nombre)
            .font(.body.weight(.semibold))
            .foregroundStyle(Paleta.brand)
            .frame(width: 36, height: 36)
            .background(Paleta.brandFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// **«Descargar la plantilla»**, que en iOS es compartirla: la hoja del
/// sistema deja guardarla en Archivos, mandarla por correo o abrirla en Excel.
struct BotonPlantilla: View {
    enum Estilo { case relleno, tarjeta, enlace, fila }
    let tipo: PlantillaImportar
    var estilo: Estilo = .enlace

    private var titulo: String {
        tipo == .personas ? L.t("Descargar la plantilla", "Download the template")
                          : L.t("Descargar la plantilla de aportes", "Download the gifts template")
    }

    var body: some View {
        if let url = tipo.archivoTemporal {
            ShareLink(item: url) { etiqueta }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var etiqueta: some View {
        switch estilo {
        case .relleno:
            Text(titulo)
                .font(.headline)
                .foregroundStyle(Paleta.brand)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Paleta.brandFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .tarjeta:
            HStack(spacing: 12) {
                Image(systemName: "doc.plaintext")
                    .foregroundStyle(Paleta.brand)
                    .frame(width: 36, height: 36)
                    .background(Paleta.brandFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo).font(.body).foregroundStyle(.primary)
                    Text(L.t("¿No tienes nada ordenado? Rellena esta hoja con las columnas ya puestas y vuelve.",
                             "Nothing organized yet? Fill in this sheet with the columns already set, then come back."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 22).padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .enlace:
            Text(titulo)
                .font(.subheadline)
                .foregroundStyle(Paleta.brand)
                .frame(minHeight: 32)
        case .fila:
            HStack {
                Text(titulo).foregroundStyle(Paleta.brand)
                Spacer()
            }
            .contentShape(Rectangle())
        }
    }
}

// MARK: - El importador, colgado de la raíz

/// El CSV leído, esperando a que se revise.
private struct PorImportar: Identifiable {
    let id = UUID()
    let documento: CSVLector.Documento
    let archivo: String
    let tipo: PlantillaImportar
}

/// Por qué no se pudo leer, con el nombre del archivo (I9).
private enum FalloDeLectura: Identifiable {
    case formato(String), vacio(String)
    var id: String {
        switch self { case .formato(let n): return "f\(n)"; case .vacio(let n): return "v\(n)" }
    }
    var mensaje: String {
        switch self {
        case .formato(let n):
            return L.t("«\(n)» no es un CSV. En Excel: Archivo › Guardar como › CSV, y vuelve a elegirlo.",
                       "“\(n)” isn’t a CSV. In Excel: File › Save As › CSV, then choose it again.")
        case .vacio(let n):
            return L.t("«\(n)» está vacío: no tiene ninguna fila debajo de los encabezados.",
                       "“\(n)” is empty: there are no rows under the headers.")
        }
    }
}

/// **Importar, desde cualquier sitio.** Lo piden la invitación, Ajustes ›
/// Datos, Membresía vacía y Aportantes, dejando el testigo en
/// `Navegacion.pidiendoImportar`. Cuelga de la raíz y no de una pantalla: en
/// iOS varias presentaciones sobre la MISMA vista no conviven (ver
/// `MiembrosView.HojaAportante`), así que esto vive aparte de las hojas de
/// cada pantalla.
struct ImportarDatosIOS: ViewModifier {
    @Environment(Navegacion.self) private var navegacion
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    @State private var eligiendo = false
    @State private var tipo: PlantillaImportar = .personas
    @State private var porImportar: PorImportar?
    @State private var fallo: FalloDeLectura?
    @State private var vm = MiembrosViewModel()

    private var permisos: Permisos { Permisos.vigentes(sesion) }
    private func puede(_ t: PlantillaImportar) -> Bool {
        t == .personas ? permisos.administraPadron
                       : permisos.administraPadron && permisos.ve(.tesoreria)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: navegacion.pidiendoImportar, initial: true) { _, pedido in
                guard let pedido else { return }
                navegacion.pidiendoImportar = nil
                guard puede(pedido) else { return }
                tipo = pedido
                eligiendo = true
            }
            .fileImporter(isPresented: $eligiendo,
                          allowedContentTypes: [.commaSeparatedText, .plainText, .text, .data],
                          allowsMultipleSelection: false) { resultado in
                guard let url = try? resultado.get().first else { return }
                abrir(url)
            }
            .sheet(item: $porImportar) { p in
                HojaImportarIOS(documento: p.documento, archivo: p.archivo, tipo: p.tipo, vm: vm,
                                puedeAportes: puede(.aportes),
                                cambiarArchivo: { eligiendo = true })
            }
            .alert(L.t("No se pudo leer el archivo", "Couldn’t read the file"),
                   isPresented: Binding(get: { fallo != nil }, set: { if !$0 { fallo = nil } }),
                   presenting: fallo) { _ in
                Button(L.t("Elegir otro archivo", "Choose another file")) {
                    fallo = nil
                    eligiendo = true
                }
                if let url = tipo.archivoTemporal {
                    ShareLink(item: url) {
                        Text(L.t("Descargar la plantilla", "Download the template"))
                    }
                }
                Button(L.t("Cancelar", "Cancel"), role: .cancel) { fallo = nil }
            } message: { f in
                Text(f.mensaje)
            }
            .task { await vm.cargar() }
    }

    private func abrir(_ url: URL) {
        let nombre = url.lastPathComponent
        // Un Excel o un PDF se «leerían» como texto: el lector cae a Latin-1,
        // que acepta cualquier byte. Por la extensión se sabe antes.
        guard ["csv", "txt", "tsv"].contains(url.pathExtension.lowercased()) else {
            fallo = .formato(nombre); return
        }
        do {
            let doc = try CSVLector.leer(url)
            Task { @MainActor in
                // La lista al día antes de analizar: decide quién ya existe.
                await vm.cargar()
                porImportar = PorImportar(documento: doc, archivo: nombre, tipo: tipo)
            }
        } catch CSVLector.Fallo.vacio {
            fallo = .vacio(nombre)
        } catch {
            fallo = .formato(nombre)
        }
    }
}

// MARK: - La hoja

/// **Importar personas o aportes** (I2–I7, I10 · P2a, P3, P4).
///
/// - **iPhone:** dos pantallas seguidas —Columnas y Revisar— con el botón
///   principal siempre abajo, al alcance del pulgar.
/// - **iPad:** P2a, que eligió Iván: las columnas a la izquierda y lo que va
///   a pasar a la derecha, en vivo. Es lo mismo que el Mac.
///
/// El «Hecho» va dentro de la misma hoja, que no se cierra: así el paso de
/// aportes queda a un toque. Nada se escribe hasta confirmar.
private struct HojaImportarIOS: View {
    let documento: CSVLector.Documento
    let archivo: String
    let tipo: PlantillaImportar
    let vm: MiembrosViewModel
    let puedeAportes: Bool
    let cambiarArchivo: () -> Void

    @Environment(\.dismiss) private var cerrar
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(Navegacion.self) private var navegacion
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    private enum Paso: Equatable {
        case columnas, revisar
        case importando(hechas: Int, de: Int)
        case hecho(cuantos: Int, sinConexion: Bool)
    }

    @State private var paso: Paso = .columnas
    @State private var mapeo: [String: String] = [:]
    @State private var preparado = false
    @State private var motivo: String?
    @State private var viendoOmitidas = false
    /// Lo que se omitió y lo que se sumó, en el momento de importar: después la
    /// lista cambia y el análisis ya no diría lo mismo.
    @State private var omitidasAlImportar = 0
    @State private var totalAlImportar: Centavos = 0
    @State private var aniosAlImportar: [Int] = []

    private var compacto: Bool { sizeClass == .compact }
    private var esPersonas: Bool { tipo == .personas }
    private var campos: [CSVLector.Campo] {
        esPersonas ? ImportadorAportantes.campos : ImportadorAportes.campos
    }

    // MARK: Los dos análisis

    private var mapeado: CSVLector.Documento { CSVLector.aplicar(mapeo, a: documento, campos: campos) }
    private var analisisPersonas: ImportadorAportantes.Analisis? {
        esPersonas ? try? ImportadorAportantes.analizar(mapeado, existentes: vm.items) : nil
    }
    private var analisisAportes: ImportadorAportes.Analisis? {
        esPersonas ? nil : try? ImportadorAportes.analizar(mapeado, existentes: vm.items)
    }

    private var personasAplicables: [Aportante] {
        (analisisPersonas?.filas ?? []).compactMap { f in
            switch f.destino { case .nuevo, .actualiza: return f.aportante; case .error: return nil }
        }
    }
    private var aportesNuevos: [Aporte] {
        (analisisAportes?.filas ?? []).compactMap { f in
            if case .nuevo = f.destino { return f.aporte }
            return nil
        }
    }
    private var cuantos: Int { esPersonas ? personasAplicables.count : aportesNuevos.count }
    private var total: Centavos { aportesNuevos.reduce(0) { $0 + $1.monto } }

    /// Las omitidas de cualquiera de los dos, con lo que cada una enseña.
    private struct Omitida: Identifiable {
        let id: UUID
        let linea: Int
        let nombre: String
        let detalle: String?
        let motivo: String
    }
    private var omitidas: [Omitida] {
        if let a = analisisPersonas {
            return a.errores.map { f in
                var m = ""
                if case .error(let t) = f.destino { m = t }
                return Omitida(id: f.id, linea: f.linea,
                               nombre: f.nombre == "—" ? "" : f.nombre, detalle: nil, motivo: m)
            }
        }
        if let a = analisisAportes {
            return a.errores.map { f in
                var m = ""
                if case .error(let t) = f.destino { m = t }
                return Omitida(id: f.id, linea: f.linea, nombre: f.aportante,
                               detalle: "\(f.fecha) · \(f.monto)", motivo: m)
            }
        }
        return []
    }

    private var faltaObligatorio: Bool { !CSVLector.faltantes(mapeo, campos: campos).isEmpty }

    private var porAnio: [(anio: Int, cuantos: Int, monto: Centavos)] {
        let cal = Calendar.current
        let g = Dictionary(grouping: aportesNuevos) { cal.component(.year, from: $0.fecha) }
        return g.keys.sorted().map { a in
            let l = g[a] ?? []
            return (a, l.count, l.reduce(0) { $0 + $1.monto })
        }
    }

    private var importando: Bool {
        if case .importando = paso { return true }
        return false
    }

    private var titulo: String {
        esPersonas ? L.t("Importar personas", "Import people") : L.t("Importar aportes", "Import gifts")
    }
    private var filasDelArchivo: String {
        documento.filas.count == 1 ? L.t("1 fila", "1 row")
                                   : L.t("\(documento.filas.count) filas", "\(documento.filas.count) rows")
    }

    /// Adónde se va al terminar: Membresía, o Aportantes en el plan solo
    /// Tesorería. Los aportes, a Inicio.
    private var vePadron: Bool { Permisos.vigentes(sesion).vePadron }

    // MARK: Cuerpo

    var body: some View {
        NavigationStack {
            Group {
                if case .hecho(let n, let sinConexion) = paso {
                    hecho(n, sinConexion)
                } else if compacto {
                    if paso == .columnas { listaColumnas } else { listaRevisar }
                } else {
                    dosColumnas
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barra }
            .safeAreaInset(edge: .bottom) { pie }
        }
        .interactiveDismissDisabled(importando)
        .presentationSizing(.page)
        .onAppear {
            guard !preparado else { return }
            preparado = true
            mapeo = CSVLector.mapeoSugerido(documento, campos: campos)
            // En el iPad no hay dos pasos: columnas y resumen van juntos.
            if !compacto { paso = .revisar }
        }
    }

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(tituloBarra).font(.headline)
                if !compacto, case .hecho = paso {} else if !compacto {
                    Text("\(archivo) · \(filasDelArchivo)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        switch paso {
        case .columnas:
            ToolbarItem(placement: .cancellationAction) {
                Button(L.t("Cancelar", "Cancel")) { cerrar() }
            }
        case .revisar:
            ToolbarItem(placement: .cancellationAction) {
                if compacto {
                    Button { paso = .columnas } label: {
                        Label(L.t("Columnas", "Columns"), systemImage: "chevron.left").labelStyle(.titleAndIcon)
                    }
                } else {
                    Button(L.t("Cancelar", "Cancel")) { cerrar() }
                }
            }
            // P2a lleva «Importar 48» arriba; P4, el de aportes, abajo con la
            // cifra: allí el botón tiene que repetir el dinero.
            if !compacto && esPersonas && cuantos > 0 {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Importar \(cuantos)", "Import \(cuantos)"), action: importar)
                        .fontWeight(.semibold)
                        .tint(Paleta.brand)
                }
            }
        case .importando:
            ToolbarItem(placement: .cancellationAction) {
                Text(L.t("Columnas", "Columns")).foregroundStyle(.tertiary)
            }
        case .hecho:
            ToolbarItem(placement: .confirmationAction) {
                Button(L.t("Listo", "Done")) { cerrar() }.fontWeight(.semibold)
            }
        }
    }

    private var tituloBarra: String {
        switch paso {
        case .columnas: return compacto ? L.t("Columnas", "Columns") : titulo
        case .revisar, .importando:
            return compacto ? (esPersonas ? L.t("Revisar", "Review") : titulo) : titulo
        case .hecho: return ""
        }
    }

    // MARK: Paso 1 (I2)

    private var listaColumnas: some View {
        List {
            Section { progreso(1) }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            Section {
                HStack(spacing: 12) {
                    Text("CSV")
                        .font(.caption2.bold())
                        .foregroundStyle(Paleta.brand)
                        .frame(width: 32, height: 32)
                        .background(Paleta.brandFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(archivo).font(.subheadline.weight(.medium)).lineLimit(1)
                        Text(filasDelArchivo).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L.t("Cambiar", "Change")) {
                        cerrar()
                        cambiarArchivo()
                    }
                    .foregroundStyle(Paleta.brand)
                }
            }
            seccionColumnas
        }
        .listStyle(.insetGrouped)
    }

    private func progreso(_ en: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Capsule().fill(Paleta.brand).frame(height: 4)
                Capsule().fill(en >= 2 ? Paleta.brand : Color(.tertiarySystemFill)).frame(height: 4)
            }
            Text(en == 1 ? L.t("Paso 1 de 2", "Step 1 of 2") : L.t("Paso 2 de 2", "Step 2 of 2"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var seccionColumnas: some View {
        Section {
            ForEach(campos) { campo in
                Picker(selection: Binding(
                    get: { mapeo[campo.clave] ?? "" },
                    set: { nueva in
                        // Una columna del archivo no alimenta dos campos.
                        if !nueva.isEmpty {
                            for (k, v) in mapeo where v == nueva && k != campo.clave { mapeo[k] = nil }
                        }
                        mapeo[campo.clave] = nueva.isEmpty ? nil : nueva
                    })) {
                    Text(L.t("— No importar —", "— Don’t import —")).tag("")
                    ForEach(documento.encabezados.filter { !$0.isEmpty }, id: \.self) { Text($0).tag($0) }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(campo.rotulo)
                        if campo.obligatorio {
                            Text(L.t("obligatorio", "required"))
                                .font(.caption)
                                .foregroundStyle(mapeo[campo.clave] == nil ? Paleta.negativo : .secondary)
                        }
                    }
                }
                .pickerStyle(.menu)
                .tint(mapeo[campo.clave] == nil ? .secondary : .primary)
            }
        } header: {
            Text(L.t("Qué columna es cuál", "Which column is which")).textCase(nil)
        } footer: {
            Text(esPersonas
                 ? L.t("Lo que dejes sin columna se queda vacío y se puede completar después en cada ficha.",
                       "Anything left unmapped stays empty and can be filled in later on each record.")
                 : L.t("Cada aporte se apunta a una persona que ya esté en Tamio, por su id o por su nombre.",
                       "Each gift is linked to a person already in Tamio, by id or by name."))
        }
    }

    // MARK: Paso 2 (I3, I4, I7, I10)

    private var listaRevisar: some View {
        List {
            if compacto {
                Section { progreso(2) }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }
            contenidoRevisar
        }
        .listStyle(.insetGrouped)
        .disabled(importando)
        .opacity(importando ? 0.45 : 1)
    }

    @ViewBuilder
    private var contenidoRevisar: some View {
        if cuantos == 0 { avisoNada }
        if esPersonas { resumenPersonas } else { resumenAportes }
        if !omitidas.isEmpty { seccionOmitidas }
    }

    /// I10: nada que importar, y por qué. Casi siempre, que la columna del
    /// nombre no es la que se eligió.
    private var avisoNada: some View {
        let n = documento.filas.count
        let sinNombre = esPersonas && (faltaObligatorio || omitidas.allSatisfy { $0.nombre.isEmpty })
        // Reimportar el mismo archivo de aportes: no hay nada malo, es que ya
        // están. Decir «revisa las omitidas» mandaba a buscar un fallo.
        let yaEstaban = !esPersonas && (analisisAportes?.duplicados ?? 0) > 0
        return Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("Ninguna fila se puede importar", "No row can be imported"))
                    .font(.headline)
                Text(sinNombre
                     ? L.t("Ninguna de las \(n) filas tiene nombre. Revisa qué columna es la del nombre.",
                           "None of the \(n) rows has a name. Check which column holds the name.")
                     : yaEstaban
                     ? L.t("Los aportes de este archivo ya estaban registrados: no se suma nada dos veces.",
                           "The gifts in this file were already recorded: nothing is added twice.")
                     : L.t("Revisa las filas que se omiten, más abajo.", "Check the skipped rows below."))
                    .font(.subheadline)
                if compacto {
                    Button {
                        paso = .columnas
                    } label: {
                        Label(L.t("Columnas", "Columns"), systemImage: "chevron.left")
                    }
                    .foregroundStyle(Paleta.brand)
                    .padding(.top, 6)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Paleta.aviso.opacity(0.13))
        }
    }

    private var resumenPersonas: some View {
        let a = analisisPersonas
        return Section {
            filaResumen("plus.circle.fill", Paleta.brand, a?.nuevos ?? 0, L.t("personas nuevas", "new people"))
            filaResumen("arrow.triangle.2.circlepath", Paleta.enlace, a?.actualizados ?? 0,
                        L.t("ya existen y se actualizarán", "already exist, will be updated"))
            filaResumen("exclamationmark.triangle.fill", Paleta.aviso, omitidas.count,
                        L.t("filas con problemas, se omitirán", "rows with problems, will be skipped"))
        } header: {
            Text(L.t("Qué va a pasar", "What will happen")).textCase(nil)
        } footer: {
            Text(L.t("Se reconocen por id, identificación fiscal o nombre. Si importas el mismo archivo otra vez, no se duplica nadie.",
                     "Matched by id, tax ID or name. Importing the same file again won’t duplicate anyone."))
        }
    }

    /// I7 · P4: el dinero, lo más grande de la pantalla.
    private var resumenAportes: some View {
        let anios = porAnio
        let mayor = anios.map(\.monto).max() ?? 1
        return Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(L.t("Se va a sumar", "Will be added"))
                    .font(.footnote).foregroundStyle(.secondary)
                Text(Money.fmt(total))
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.6)
                    .monospacedDigit()
                    .foregroundStyle(aportesNuevos.isEmpty ? .tertiary : .primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(aportesNuevos.count == 1 ? L.t("1 aporte nuevo", "1 new gift")
                                              : L.t("\(aportesNuevos.count) aportes nuevos", "\(aportesNuevos.count) new gifts"))
                    .font(.subheadline).foregroundStyle(.secondary)
                ForEach(anios, id: \.anio) { a in
                    HStack(spacing: 10) {
                        Text(String(a.anio)).font(.subheadline).monospacedDigit()
                            .foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Paleta.brandFill)
                                Capsule().fill(Paleta.brand)
                                    .frame(width: g.size.width * CGFloat(a.monto) / CGFloat(max(mayor, 1)))
                            }
                        }
                        .frame(height: 8)
                        Text(Money.fmt(a.monto)).font(.subheadline.weight(.semibold)).monospacedDigit()
                            .frame(minWidth: 96, alignment: .trailing)
                    }
                }
                if !aportesNuevos.isEmpty {
                    Divider()
                    Text(avisoDinero).font(.footnote)
                }
            }
            .padding(.vertical, 6)
            filaResumen("equal.circle.fill", Paleta.enlace, analisisAportes?.duplicados ?? 0,
                        L.t("ya estaban registrados, se omiten", "already recorded, will be skipped"))
            filaResumen("exclamationmark.triangle.fill", Paleta.aviso, omitidas.count,
                        L.t("filas con problemas, se omiten", "rows with problems, will be skipped"))
        }
    }

    private var aniosLegibles: String {
        let a = porAnio.map { String($0.anio) }
        guard a.count > 1 else { return a.first ?? "" }
        return a.dropLast().joined(separator: ", ") + L.t(" y ", " and ") + a.last!
    }

    private var avisoDinero: String {
        L.t("Se sumarán \(Money.fmt(total)) a los informes y constancias de \(aniosLegibles). Comprueba que el total coincida con tus registros.",
            "\(Money.fmt(total)) will be added to the reports and statements for \(aniosLegibles). Check that the total matches your records.")
    }

    private func filaResumen(_ icono: String, _ tinta: Color, _ n: Int, _ texto: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icono).foregroundStyle(tinta).font(.title3)
            Text("\(n)").font(.title3.weight(.bold)).monospacedDigit()
                .foregroundStyle(n == 0 ? .tertiary : .primary)
            Text(texto).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    /// Cada omitida en dos renglones (línea y nombre; el motivo en rojo
    /// debajo) para que en pantalla estrecha no se corten. Con más de diez,
    /// un filtro por motivo (I4); se ven cincuenta y luego «y N más…».
    private var seccionOmitidas: some View {
        let todas = omitidas
        let motivos = Array(Set(todas.map(\.motivo))).sorted()
        let filtradas = motivo.map { m in todas.filter { $0.motivo == m } } ?? todas
        return Section {
            if todas.count > 10 && motivos.count > 1 {
                Picker("", selection: $motivo) {
                    Text(L.t("Todas \(todas.count)", "All \(todas.count)")).tag(String?.none)
                    ForEach(motivos, id: \.self) { m in
                        Text("\(m) \(todas.filter { $0.motivo == m }.count)").tag(String?.some(m))
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            ForEach(filtradas.prefix(50)) { o in
                VStack(alignment: .leading, spacing: 1) {
                    (Text(L.t("Línea \(o.linea) · ", "Row \(o.linea) · ")).foregroundColor(.secondary)
                     + Text(o.nombre.isEmpty ? L.t("(sin nombre)", "(no name)") : o.nombre)
                        .foregroundColor(o.nombre.isEmpty ? .secondary : .primary)
                        .fontWeight(.medium))
                        .font(.body)
                    Text(o.motivo).font(.subheadline).foregroundStyle(Paleta.negativo)
                    if let d = o.detalle {
                        Text(d).font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            if filtradas.count > 50 {
                Text(L.t("y \(filtradas.count - 50) más…", "and \(filtradas.count - 50) more…"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text(L.t("Filas que se omiten", "Skipped rows")).textCase(nil)
        } footer: {
            Text(esPersonas
                 ? L.t("Arregla estas filas en tu archivo y vuelve a importarlo: las que ya entraron no se duplican.",
                       "Fix these rows in your file and import it again: the ones already in won’t be duplicated.")
                 : L.t("Arregla estas filas en tu archivo y vuelve a importarlo: los aportes que ya entraron no se duplican.",
                       "Fix these rows in your file and import it again: gifts already in won’t be duplicated."))
        }
    }

    // MARK: iPad (P2a · P4)

    private var dosColumnas: some View {
        HStack(spacing: 0) {
            List { seccionColumnas }
                .listStyle(.insetGrouped)
                .frame(maxWidth: .infinity)
                .disabled(importando)
            Divider()
            List { contenidoRevisar }
                .listStyle(.insetGrouped)
                .frame(maxWidth: .infinity)
                .opacity(importando ? 0.45 : 1)
        }
    }

    // MARK: Pie

    @ViewBuilder
    private var pie: some View {
        switch paso {
        case .columnas:
            VStack(spacing: 8) {
                botonGrande(L.t("Continuar", "Continue"), activo: !faltaObligatorio) { paso = .revisar }
                BotonPlantilla(tipo: tipo, estilo: .enlace)
            }
            .barraInferiorImportar()
        case .revisar:
            // En el iPad las personas se importan desde la barra (P2a); los
            // aportes, abajo y con la cifra (P4).
            if compacto || !esPersonas {
                Group {
                    if cuantos == 0 {
                        botonGrande(L.t("Nada que importar", "Nothing to import"), activo: false) {}
                    } else {
                        botonGrande(rotuloImportar, activo: true, accion: importar)
                    }
                }
                .frame(maxWidth: compacto ? .infinity : 400)
                .frame(maxWidth: .infinity, alignment: compacto ? .center : .trailing)
                .barraInferiorImportar()
            }
        case .importando(let hechas, let de):
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(esPersonas
                         ? (de == 1 ? L.t("Importando 1 persona…", "Importing 1 person…")
                                    : L.t("Importando \(de) personas…", "Importing \(de) people…"))
                         : (de == 1 ? L.t("Importando 1 aporte…", "Importing 1 gift…")
                                    : L.t("Importando \(de) aportes…", "Importing \(de) gifts…")))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(hechas) / \(de)").font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                }
                ProgressView(value: Double(hechas), total: Double(max(de, 1)))
                    .tint(Paleta.brand)
                Text(L.t("Tarda unos segundos.", "This takes a few seconds."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .barraInferiorImportar()
        case .hecho:
            VStack(spacing: 10) {
                if esPersonas && puedeAportes {
                    Button {
                        cerrar()
                        navegacion.pidiendoImportar = .aportes
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.t("Opcional", "Optional"))
                                    .font(.caption.weight(.semibold)).foregroundStyle(Paleta.brand)
                                Text(L.t("Trae también los aportes de años anteriores",
                                         "Also bring in gifts from past years"))
                                    .font(.body.weight(.semibold)).foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                if !compacto {
                                    Text(L.t("Así los informes y las constancias anuales salen completos desde hoy.",
                                             "So reports and annual statements are complete from today."))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                botonGrande(destinoRotulo, activo: true) {
                    irAlDestino()
                    cerrar()
                }
            }
            .frame(maxWidth: compacto ? .infinity : 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var rotuloImportar: String {
        if esPersonas { return L.t("Importar \(cuantos)", "Import \(cuantos)") }
        if !compacto {
            return L.t("Importar \(cuantos) · \(Money.fmt(total))", "Import \(cuantos) · \(Money.fmt(total))")
        }
        return cuantos == 1 ? L.t("Importar 1 aporte", "Import 1 gift")
                            : L.t("Importar \(cuantos) aportes", "Import \(cuantos) gifts")
    }

    private var destinoRotulo: String {
        if !esPersonas { return L.t("Ir al Inicio", "Go to Home") }
        return vePadron ? L.t("Ir a Membresía", "Go to Membership") : L.t("Ir a Aportantes", "Go to Contributors")
    }

    private func irAlDestino() {
        let seccion = !esPersonas ? "inicio" : (vePadron ? "membresia" : "miembros")
        navegacion.seccion = seccion
        navegacion.pestana = Navegacion.pestana(de: seccion)
    }

    @ViewBuilder
    private func botonGrande(_ titulo: String, activo: Bool, accion: @escaping () -> Void) -> some View {
        if activo {
            Button(action: accion) {
                Text(titulo)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(Paleta.brand)
        } else {
            // **Apagado pero legible**, como «Nada que importar» del handoff:
            // `.disabled` sobre el botón verde lo dejaba casi en blanco sobre
            // la barra, y ese texto es justo lo que explica por qué no se puede.
            Text(titulo)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityAddTraits(.isButton)
                .accessibilityRemoveTraits(.isStaticText)
        }
    }

    // MARK: Hecho (I6 · P3)

    private func hecho(_ n: Int, _ sinConexion: Bool) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Paleta.brand, in: Circle())
                Text(tituloHecho(n))
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.4)
                Text(cuerpoHecho)
                    .font(.body)
                    .foregroundStyle(.secondary)
                if omitidasAlImportar > 0 && esPersonas {
                    Button(omitidasAlImportar == 1
                           ? L.t("Ver la fila omitida", "See the skipped row")
                           : L.t("Ver las \(omitidasAlImportar) filas omitidas",
                                 "See the \(omitidasAlImportar) skipped rows")) {
                        viendoOmitidas.toggle()
                    }
                    .foregroundStyle(Paleta.brand)
                }
                if sinConexion {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "icloud").foregroundStyle(.secondary)
                        (Text(aparato).bold()
                         + Text(" · ")
                         + Text(L.t("Ahora no hay internet. Ya están en Tamio y subirán solas cuando vuelva la conexión.",
                                    "There’s no internet right now. They’re already in Tamio and will upload on their own when you’re back online."))
                            .foregroundColor(.secondary))
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 6)
                }
                if viendoOmitidas {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(omitidas.prefix(50)) { o in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L.t("Línea \(o.linea) · ", "Row \(o.linea) · ")
                                     + (o.nombre.isEmpty ? L.t("(sin nombre)", "(no name)") : o.nombre))
                                Text(o.motivo).font(.subheadline).foregroundStyle(Paleta.negativo)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 36)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var aparato: String {
        UIDevice.current.userInterfaceIdiom == .pad ? L.t("Guardado en este iPad", "Saved on this iPad")
                                                    : L.t("Guardado en este iPhone", "Saved on this iPhone")
    }

    private func tituloHecho(_ n: Int) -> String {
        if esPersonas {
            return n == 1 ? L.t("1 persona ya está en Tamio", "1 person is now in Tamio")
                          : L.t("\(n) personas ya están en Tamio", "\(n) people are now in Tamio")
        }
        return n == 1 ? L.t("1 aporte registrado", "1 gift recorded")
                      : L.t("\(n) aportes registrados", "\(n) gifts recorded")
    }

    private var cuerpoHecho: String {
        if !esPersonas {
            let rango: String
            if let a = aniosAlImportar.first, let b = aniosAlImportar.last, a != b {
                rango = L.t("entre \(a) y \(b)", "across \(a)–\(b)")
            } else {
                rango = L.t("en \(aniosAlImportar.first.map(String.init) ?? "")",
                            "in \(aniosAlImportar.first.map(String.init) ?? "")")
            }
            return L.t("Suman \(Money.fmt(totalAlImportar)) \(rango). Los informes y las constancias de esos años ya los incluyen.",
                       "They total \(Money.fmt(totalAlImportar)) \(rango). Reports and statements for those years already include them.")
        }
        let donde = vePadron ? L.t("Las encontrarás en Membresía.", "You’ll find them in Membership.")
                             : L.t("Las encontrarás en Aportantes.", "You’ll find them in Contributors.")
        guard omitidasAlImportar > 0 else { return donde }
        return donde + " " + (omitidasAlImportar == 1
            ? L.t("1 fila se quedó fuera: arréglala en el archivo e impórtalo otra vez.",
                  "1 row was left out: fix it in the file and import it again.")
            : L.t("\(omitidasAlImportar) filas se quedaron fuera: arréglalas en el archivo e impórtalo otra vez.",
                  "\(omitidasAlImportar) rows were left out: fix them in the file and import it again."))
    }

    // MARK: Importar

    private func importar() {
        let n = cuantos
        guard n > 0 else { return }
        omitidasAlImportar = omitidas.count
        totalAlImportar = total
        aniosAlImportar = porAnio.map(\.anio)
        let personas = personasAplicables
        let lote = analisisAportes?.porAportante ?? [:]
        paso = .importando(hechas: 0, de: n)
        Task { @MainActor in
            if esPersonas {
                await vm.importar(personas) { k in paso = .importando(hechas: k, de: n) }
            } else {
                await vm.importarAportes(lote, archivo: archivo, autor: sesion?.perfil.firma ?? "") { k in
                    paso = .importando(hechas: k, de: n)
                }
            }
            await MotorSincronizacion.compartido.sincronizar()
            let motor = MotorSincronizacion.compartido
            paso = .hecho(cuantos: n, sinConexion: motor.haFallado || motor.pendientes > 0)
        }
    }
}

private extension View {
    /// La barra de abajo de la hoja: fondo de barra y el botón a una mano.
    func barraInferiorImportar() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
    }
}
