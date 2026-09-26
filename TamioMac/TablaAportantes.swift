import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// **Aportantes.** Las cinco columnas de la maqueta: Nombre, Miembro desde,
/// Frecuencia, Último aporte y Acumulado del año.
struct TablaAportantes: View {
    let vm: MiembrosViewModel
    @Environment(EstadoVentana.self) private var estado
    @Binding var seleccion: Set<Aportante.ID>
    @State private var orden = [KeyPathComparator(\Aportante.nombre, order: .forward)]

    /// **Quién puede importar.** El mismo permiso que esconde "Importar
    /// aportantes…" en iOS (`administraPadron`): una importación crea y
    /// reescribe fichas en masa, y enseñarla a quien el servidor no deja
    /// escribir haría que las fichas volvieran atrás a la siguiente
    /// sincronización sin que nadie supiera por qué.
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    private var puedeImportar: Bool { Permisos.vigentes(sesion).administraPadron }

    private var filas: [Aportante] { vm.itemsFiltrados.sorted(using: orden) }
    private var anio: Int { vm.anio }

    /// **A media pantalla la tabla suelta una columna y estrecha el resto**
    /// (handoff 9: «a 900 pt cada tabla suelta la columna que ya está en el
    /// inspector»). `Table` nace en el ancho ideal de sus columnas y no las
    /// encoge, así que por debajo de esa suma las últimas quedaban fuera de la
    /// vista. `ViewThatFits` y no medir el ancho, como en `TablaMovimientos`.
    private static let anchoCompleto: CGFloat = 260 + 120 + 124 + 120 + 140 + 5 * 17 + 20

    var body: some View {
        ViewThatFits(in: .horizontal) {
            tabla(estrecha: false)
                .frame(minWidth: 0, idealWidth: Self.anchoCompleto, maxWidth: .infinity, maxHeight: .infinity)
            tabla(estrecha: true)
        }
    }

    private func tabla(estrecha: Bool) -> some View {
        Table(filas, selection: $seleccion, sortOrder: $orden) {

            TableColumn(L.t("Nombre", "Name"), value: \.nombre) { a in
                HStack(spacing: 8) {
                    Text(a.nombre).fontWeight(.semibold).lineLimit(1)
                    // **Quién lleva tiempo sin aportar, marcado en la fila.**
                    // Es la pregunta que trae a alguien a esta pantalla, y
                    // enterrarla en una columna aparte la esconde.
                    if a.atrasadoEnAportes {
                        Text(L.t("Atrasado", "Behind"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Paleta.aviso)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Paleta.aviso.opacity(0.14),
                                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
                // El alto de fila se fija en la primera columna: `Table` no
                // tiene ajuste propio y la fila mide lo que su celda más alta.
                .frame(height: estado.altoDeFila)
            }
            .width(min: 140, ideal: estrecha ? 220 : 260)

            // Ya sale en el inspector: es la que se suelta.
            if !estrecha {
                TableColumn(L.t("Miembro desde", "Member since"), value: \.congregaDesde) { a in
                    Text(a.congregaDesde.isEmpty ? "—" : a.congregaDesde)
                        .foregroundStyle(.secondary)
                }
                .width(min: 100, ideal: 120, max: 170)
            }

            TableColumn(L.t("Frecuencia", "Frequency"), value: \.frecuencia.rawValue) { a in
                Text(a.frecuencia.etiqueta).foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: estrecha ? 104 : 124, max: 170)

            TableColumn(L.t("Último aporte", "Last gift"), value: \.ordenUltimoAporte) { a in
                Text(a.ultimoAporte.map {
                    $0.formatted(.dateTime.day().month(.abbreviated))
                } ?? "—")
                .foregroundStyle(a.ultimoAporte == nil ? .tertiary : .secondary)
            }
            .width(min: 80, ideal: estrecha ? 90 : 120, max: 170)

            TableColumn(L.t("Acumulado", "Year to date"), value: \.nombre) { a in
                let t = a.total(anio: anio)
                Text(t == 0 ? "—" : Money.fmt(t))
                    .monospacedDigit()
                    .fontWeight(t == 0 ? .regular : .semibold)
                    .foregroundStyle(t == 0 ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 100, ideal: estrecha ? 112 : 140, max: 190)
        }
        // **Sin rayas alternas.** `alternatesRowBackgrounds` las pinta en
        // TODO el alto de la tabla, también donde no hay datos: con dos filas
        // en pantalla la ventana se llenaba de renglones rayados vacíos.
        .tableStyle(.inset)
        // **Importar cuelga del menú contextual, también sobre el hueco.** Con
        // `forSelectionType` el menú sale igual al pulsar donde no hay filas
        // (`ids` vacío), que es justo donde se busca en una tabla vacía: la
        // primera importación es la de una iglesia que aún no tiene a nadie.
        .contextMenu(forSelectionType: Aportante.ID.self) { _ in
            if puedeImportar {
                Button(L.t("Importar personas…", "Import people…")) {
                    estado.pidiendoImportarAportantes = true
                }
            }
        }
    }
}

// MARK: - Importar personas · handoff «Trae tus datos»

/// La plantilla vive en `ImportadorAportantes.swift`, compartida con iOS;
/// aquí solo el «Guardar como» del Mac.
extension PlantillaImportar {
    /// Pregunta dónde guardarla, como cualquier «Guardar como» del Mac.
    @MainActor
    static func guardar(_ p: PlantillaImportar) {
        guard let temporal = p.archivoTemporal else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = p.nombreDeArchivo
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let destino = panel.url else { return }
        try? FileManager.default.removeItem(at: destino)
        try? FileManager.default.copyItem(at: temporal, to: destino)
    }

    /// Las dos de una vez, en la carpeta que se elija: la fila «Descargar las
    /// plantillas» de Configuración › Datos.
    @MainActor
    static func guardarAmbas() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L.t("Guardar aquí", "Save here")
        panel.message = L.t("Elige dónde guardar las dos plantillas.", "Choose where to save both templates.")
        guard panel.runModal() == .OK, let carpeta = panel.url else { return }
        for p in allCases {
            guard let temporal = p.archivoTemporal else { continue }
            let destino = carpeta.appendingPathComponent(p.nombreDeArchivo)
            try? FileManager.default.removeItem(at: destino)
            try? FileManager.default.copyItem(at: temporal, to: destino)
        }
    }
}

/// El CSV leído, esperando a que se revise. `Identifiable` para la hoja.
private struct DocumentoPorImportar: Identifiable {
    let id = UUID()
    let documento: CSVLector.Documento
    let archivo: String
    let tipo: PlantillaImportar
}

/// **Por qué no se pudo leer**, con el nombre del archivo: el aviso del
/// handoff (M7) nombra el archivo y dice qué hacer.
private enum FalloDeArchivo: Identifiable {
    case formato(String)
    case vacio(String)
    var id: String {
        switch self { case .formato(let n): return "f-\(n)"; case .vacio(let n): return "v-\(n)" }
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

/// **Importar personas, desde cualquier sitio.**
///
/// Vivía en la tabla de Aportantes, así que solo funcionaba estando ahí: el
/// menú cambiaba de sección para poder abrirlo. Ahora lo piden cuatro sitios
/// —Archivo, la invitación de «Trae tus datos», el estado vacío de Membresía y
/// Configuración › Datos— y todos encienden el mismo testigo; esto cuelga de
/// la ventana y lo recoge esté donde esté.
struct ImportarPersonasMac: ViewModifier {
    let vm: MiembrosViewModel
    @Environment(EstadoVentana.self) private var estado
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    @State private var eligiendo = false
    /// Qué se está eligiendo: el mismo selector sirve a personas y aportes.
    @State private var tipo: PlantillaImportar = .personas
    @State private var porImportar: DocumentoPorImportar?
    @State private var fallo: FalloDeArchivo?

    /// El mismo permiso que el alta: una importación crea y reescribe fichas
    /// en masa, y el servidor se las devolvería a quien no puede escribirlas.
    private var puede: Bool { Permisos.vigentes(sesion).administraPadron }
    private var puedeAportes: Bool {
        let p = Permisos.vigentes(sesion)
        return p.administraPadron && p.ve(.tesoreria)
    }

    func body(content: Content) -> some View {
        content
            // `initial` porque la invitación enciende el testigo justo antes
            // de que esta ventana vuelva a montarse.
            .onChange(of: estado.pidiendoImportarAportantes, initial: true) { _, pedido in
                guard pedido else { return }
                estado.pidiendoImportarAportantes = false
                if puede { tipo = .personas; eligiendo = true }
            }
            // Los aportes son dinero: los importa quien administra el padrón y
            // además ve Tesorería.
            .onChange(of: estado.pidiendoImportarAportes, initial: true) { _, pedido in
                guard pedido else { return }
                estado.pidiendoImportarAportes = false
                if puedeAportes { tipo = .aportes; eligiendo = true }
            }
            // Se deja elegir cualquier archivo para poder DECIR qué pasa con
            // un PDF o un Excel, en vez de enseñarlos apagados sin explicación.
            .fileImporter(isPresented: $eligiendo,
                          allowedContentTypes: [.commaSeparatedText, .plainText, .text, .data],
                          allowsMultipleSelection: false) { resultado in
                guard let url = try? resultado.get().first else { return }
                abrir(url)
            }
            .sheet(item: $porImportar) { p in
                switch p.tipo {
                case .personas:
                    HojaImportarPersonas(documento: p.documento, archivo: p.archivo, vm: vm,
                                         puedeAportes: puedeAportes,
                                         irAlPadron: { estado.seccion = $0 })
                case .aportes:
                    HojaImportarAportes(documento: p.documento, archivo: p.archivo, vm: vm,
                                        irA: { estado.seccion = $0 })
                }
            }
            .alert(L.t("No se pudo leer el archivo", "Couldn’t read the file"),
                   isPresented: Binding(get: { fallo != nil }, set: { if !$0 { fallo = nil } }),
                   presenting: fallo) { _ in
                Button(L.t("Elegir otro archivo", "Choose another file")) {
                    fallo = nil
                    eligiendo = true
                }
                Button(L.t("Descargar la plantilla", "Download the template")) {
                    fallo = nil
                    PlantillaImportar.guardar(tipo)
                }
                Button(L.t("Cancelar", "Cancel"), role: .cancel) { fallo = nil }
            } message: { f in
                Text(f.mensaje)
            }
    }

    private func abrir(_ url: URL) {
        let nombre = url.lastPathComponent
        // **Un Excel o un PDF se leerían como texto sin fallar**: el lector
        // cae a Latin-1, que acepta cualquier byte, y la hoja enseñaría
        // columnas de basura. Por la extensión se sabe antes y se dice.
        guard ["csv", "txt", "tsv"].contains(url.pathExtension.lowercased()) else {
            fallo = .formato(nombre)
            return
        }
        do {
            porImportar = DocumentoPorImportar(documento: try CSVLector.leer(url), archivo: nombre, tipo: tipo)
        } catch CSVLector.Fallo.vacio {
            fallo = .vacio(nombre)
        } catch {
            fallo = .formato(nombre)
        }
    }
}

/// **La hoja de importar personas** (handoff «Trae tus datos», M2 a M4, M8 y
/// M9). Las columnas y lo que va a pasar en UNA hoja, como antes, con lo que
/// pide el handoff:
///
/// - **El resumen, en una franja fija arriba.** Con trece campos quedaba fuera
///   de la vista, y la gracia de juntar las dos cosas es ver al momento
///   cuántas filas se caen al cambiar una columna.
/// - **El «Hecho» dentro de la misma hoja**, que no se cierra: así se ve qué
///   entró y qué no, y se va a Membresía con ↩.
/// - **Con más de diez filas con problema, se filtran por motivo.**
/// - **Importando, el pie es una barra** y la hoja no se puede cerrar.
///
/// Nada se escribe hasta pulsar «Importar»: es lo único de la app que puede
/// estropear fichas en masa.
private struct HojaImportarPersonas: View {
    let documento: CSVLector.Documento
    let archivo: String
    let vm: MiembrosViewModel
    /// Si quien importa puede traer también los aportes (M4).
    let puedeAportes: Bool
    let irAlPadron: (SeccionMac) -> Void

    @Environment(\.dismiss) private var cerrar
    @Environment(\.colorScheme) private var esquema
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @Environment(EstadoVentana.self) private var estado

    private enum Fase: Equatable {
        case revisar
        case importando(hechas: Int, de: Int)
        case hecho(importadas: Int, sinConexion: Bool)
    }

    @State private var mapeo: [String: String] = [:]
    @State private var sugerido: [String: String] = [:]
    @State private var preparado = false
    @State private var fase: Fase = .revisar
    @State private var motivo: String?
    /// Las omitidas en el momento de importar. Después la lista de personas
    /// cambia y el análisis ya no diría lo mismo.
    @State private var omitidasAlImportar: [ImportadorAportantes.FilaAnalizada] = []
    @State private var viendoOmitidas = false

    private var campos: [CSVLector.Campo] { ImportadorAportantes.campos }

    private var analisis: ImportadorAportantes.Analisis? {
        let mapeado = CSVLector.aplicar(mapeo, a: documento, campos: campos)
        return try? ImportadorAportantes.analizar(mapeado, existentes: vm.items)
    }

    private var aplicables: [Aportante] {
        (analisis?.filas ?? []).compactMap { f in
            switch f.destino {
            case .nuevo, .actualiza: return f.aportante
            case .error: return nil
            }
        }
    }

    private var errores: [ImportadorAportantes.FilaAnalizada] { analisis?.errores ?? [] }
    private var faltaElNombre: Bool { !CSVLector.faltantes(mapeo, campos: campos).isEmpty }
    private var nada: Bool { aplicables.isEmpty }

    /// Va a Membresía, o a Aportantes en el plan solo Tesorería, donde no hay
    /// Membresía que ver.
    private var destino: SeccionMac { Permisos.vigentes(sesion).vePadron ? .membresia : .miembros }

    private var importando: Bool {
        if case .importando = fase { return true }
        return false
    }

    // `--avisoFill` y `--suelo` del handoff.
    private var rellenoAviso: Color { Paleta.aviso.opacity(esquema == .dark ? 0.2 : 0.13) }
    private var suelo: Color { esquema == .dark ? Color(white: 0x1C / 255) : Color(red: 0xEA / 255, green: 0xEA / 255, blue: 0xEF / 255) }
    private var fondoFranja: Color { esquema == .dark ? Color(white: 0x2B / 255) : Color(white: 0xF6 / 255) }

    var body: some View {
        VStack(spacing: 0) {
            cabecera
            Divider()
            if case .hecho = fase {
                ScrollView { hecho.padding(18) }.frame(maxHeight: 560)
            } else {
                franja
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if nada { avisoNada }
                        seccionColumnas
                        if !nada { seccionQueVaAPasar }
                        if !errores.isEmpty { seccionOmitidas(errores) }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
                .frame(maxHeight: 560)
                .disabled(importando)
            }
            Divider()
            pie
        }
        .frame(width: 640)
        .interactiveDismissDisabled(importando)
        .onAppear {
            guard !preparado else { return }
            preparado = true
            sugerido = CSVLector.mapeoSugerido(documento, campos: campos)
            mapeo = sugerido
        }
    }

    // MARK: Cabecera y franja

    private var cabecera: some View {
        HStack(spacing: 10) {
            Text(L.t("Importar personas", "Import people"))
                .font(.system(size: 13.5, weight: .semibold))
            if case .hecho = fase {} else {
                Text("\(archivo) · " + (documento.filas.count == 1
                                         ? L.t("1 fila", "1 row")
                                         : L.t("\(documento.filas.count) filas", "\(documento.filas.count) rows")))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(suelo, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Spacer(minLength: 0)
            Button(L.t("Cerrar", "Close")) { cerrar() }
                .buttonStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(importando ? Color.secondary : Paleta.enlace)
                .disabled(importando)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    private var franja: some View {
        let a = analisis
        return HStack(spacing: 0) {
            celdaFranja(a?.nuevos ?? 0, L.t("personas nuevas", "new people"),
                        icono: "plus", tinta: Paleta.brand, redondo: true)
            Divider()
            celdaFranja(a?.actualizados ?? 0, L.t("se actualizan", "updated"),
                        icono: "arrow.clockwise", tinta: Paleta.enlace, redondo: true)
            Divider()
            celdaFranja(errores.count, L.t("se omiten", "skipped"),
                        icono: "exclamationmark", tinta: Paleta.aviso, redondo: false)
                .background(errores.isEmpty ? Color.clear : rellenoAviso)
        }
        .frame(height: 40)
        .background(fondoFranja)
    }

    private func celdaFranja(_ n: Int, _ texto: String, icono: String,
                             tinta: Color, redondo: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icono)
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(n == 0 ? Color.secondary.opacity(0.35) : tinta,
                            in: RoundedRectangle(cornerRadius: redondo ? 9 : 5, style: .continuous))
            Text("\(n)")
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(n == 0 ? .tertiary : .primary)
            Text(texto)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Contenido

    /// M8: ninguna fila se puede importar. Dice la causa probable —casi
    /// siempre, que el nombre se relacionó con la columna que no era—.
    private var avisoNada: some View {
        let sinNombre = faltaElNombre || errores.allSatisfy {
            if case .error(let m) = $0.destino { return m == L.t("Sin nombre", "No name") }
            return false
        }
        let n = documento.filas.count
        return HStack(alignment: .firstTextBaseline, spacing: 9) {
            Image(systemName: "info.circle").foregroundStyle(Paleta.aviso)
            (Text(L.t("Ninguna fila se puede importar. ", "No row can be imported. ")).bold()
             + Text(sinNombre
                    ? L.t("Ninguna de las \(n) filas tiene nombre. Revisa qué columna es la del nombre.",
                          "None of the \(n) rows has a name. Check which column holds the name.")
                    : L.t("Revisa las filas que se omiten, más abajo.",
                          "Check the skipped rows below.")))
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(rellenoAviso, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var opcionesDeColumna: [(valor: String, etiqueta: String)] {
        [(valor: "", etiqueta: L.t("— No importar —", "— Don’t import —"))]
            + documento.encabezados.filter { !$0.isEmpty }.map { (valor: $0, etiqueta: $0) }
    }

    private var seccionColumnas: some View {
        SeccionHoja(titulo: L.t("COLUMNAS DEL ARCHIVO", "FILE COLUMNS"),
                    nota: L.t("Las que se reconocieron por su nombre ya vienen elegidas. Solo el nombre es obligatorio; lo demás se completa luego en la ficha.",
                              "Columns recognized by name are already chosen. Only the name is required; the rest can be filled in later on the record.")) {
            ForEach(campos) { campo in filaColumna(campo) }
        }
    }

    private func filaColumna(_ campo: CSVLector.Campo) -> some View {
        let elegida = mapeo[campo.clave]
        let aMano = elegida != nil && elegida != sugerido[campo.clave]
        let marcar = nada && campo.obligatorio
        return ArmazonFila {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text(campo.rotulo)
                    if campo.obligatorio { Text("*").foregroundStyle(.primary) }
                }
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .frame(width: 200, alignment: .leading)
                Picker("", selection: Binding(
                    get: { mapeo[campo.clave] ?? "" },
                    set: { mapeo[campo.clave] = $0.isEmpty ? nil : $0 })) {
                    ForEach(opcionesDeColumna, id: \.valor) { o in Text(o.etiqueta).tag(o.valor) }
                }
                .labelsHidden()
                .frame(minWidth: 190, maxWidth: 240, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Paleta.aviso, lineWidth: marcar ? 1.5 : 0))
                .accessibilityLabel(campo.rotulo)
                if aMano {
                    Text(L.t("elegida a mano", "chosen by hand"))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var seccionQueVaAPasar: some View {
        let a = analisis
        return SeccionHoja(titulo: L.t("QUÉ VA A PASAR", "WHAT WILL HAPPEN"),
                           nota: L.t("Se reconocen por id, identificación fiscal o nombre. Si importas el mismo archivo otra vez, no se duplica nadie.",
                                     "Matched by id, tax ID or name. Importing the same file again won’t duplicate anyone.")) {
            filaResumen("plus.circle.fill", Paleta.brand, a?.nuevos ?? 0,
                        L.t("personas nuevas", "new people"))
            filaResumen("arrow.triangle.2.circlepath", Paleta.enlace, a?.actualizados ?? 0,
                        L.t("ya existen y se actualizarán", "already exist, will be updated"))
            filaResumen("exclamationmark.triangle.fill", Paleta.aviso, errores.count,
                        L.t("filas con problemas, se omitirán", "rows with problems, will be skipped"))
        }
    }

    private func filaResumen(_ icono: String, _ tinta: Color, _ n: Int, _ texto: String) -> some View {
        ArmazonFila {
            HStack(spacing: 10) {
                Image(systemName: icono).foregroundStyle(tinta)
                Text("\(n)").font(.system(size: 13, weight: .semibold)).monospacedDigit()
                Text(texto).font(.system(size: 12.5)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private func motivo(de f: ImportadorAportantes.FilaAnalizada) -> String {
        if case .error(let m) = f.destino { return m }
        return ""
    }

    /// Las omitidas, una por una con su línea. **Con más de diez se filtran
    /// por motivo**: cuarenta «Repetido» encima de los siete «Sin nombre» que
    /// sí hay que arreglar a mano los esconden. Se enseñan cincuenta y se dice
    /// cuántas más hay.
    private func seccionOmitidas(_ lista: [ImportadorAportantes.FilaAnalizada]) -> some View {
        let motivos = Array(Set(lista.map(motivo(de:)))).sorted()
        let filtradas = motivo.map { m in lista.filter { motivo(de: $0) == m } } ?? lista
        let visibles = filtradas.prefix(50)
        let conFiltro = lista.count > 10 && motivos.count > 1
        return VStack(alignment: .leading, spacing: 7) {
            if conFiltro {
                // Título, filtro y lista, en ese orden, como en el handoff (I4).
                Text(L.t("FILAS QUE SE OMITEN", "SKIPPED ROWS"))
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                Picker("", selection: $motivo) {
                    Text(L.t("Todas \(lista.count)", "All \(lista.count)")).tag(String?.none)
                    ForEach(motivos, id: \.self) { m in
                        Text("\(m) \(lista.filter { motivo(de: $0) == m }.count)").tag(String?.some(m))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            SeccionHoja(titulo: conFiltro ? "" : L.t("FILAS QUE SE OMITEN", "SKIPPED ROWS"),
                        nota: L.t("Arregla estas filas en tu archivo y vuelve a importarlo: las que ya entraron no se duplican.",
                                  "Fix these rows in your file and import it again: the ones already in won’t be duplicated.")) {
                ForEach(Array(visibles)) { f in
                    ArmazonFila {
                        HStack(spacing: 12) {
                            Text(L.t("Línea \(f.linea)", "Row \(f.linea)"))
                                .font(.system(size: 11.5))
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                                .frame(width: 62, alignment: .leading)
                            Text(f.nombre == "—" ? L.t("(sin nombre)", "(no name)") : f.nombre)
                                .font(.system(size: 12.5))
                                .foregroundStyle(f.nombre == "—" ? .tertiary : .primary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(motivo(de: f))
                                .font(.system(size: 11.5))
                                .foregroundStyle(Paleta.negativo)
                        }
                    }
                }
                if filtradas.count > visibles.count {
                    ArmazonFila {
                        Text(L.t("y \(filtradas.count - visibles.count) más…",
                                 "and \(filtradas.count - visibles.count) more…"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: Hecho (M4)

    @ViewBuilder
    private var hecho: some View {
        if case .hecho(let n, let sinConexion) = fase {
            let fuera = omitidasAlImportar.count
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Paleta.brand, in: Circle())
                    Text(n == 1 ? L.t("1 persona ya está en Tamio", "1 person is now in Tamio")
                                : L.t("\(n) personas ya están en Tamio", "\(n) people are now in Tamio"))
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.3)
                    Text(textoHecho(fuera))
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 440)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .padding(.bottom, 6)

                // **Los aportes, a un clic** (M4): la hoja no se cierra para
                // que este paso quede a mano. Solo a quien ve Tesorería.
                if puedeAportes {
                    HStack(spacing: 14) {
                        Image(systemName: "dollarsign")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Paleta.brand)
                            .frame(width: 30, height: 30)
                            .background(Paleta.brandFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("Trae también los aportes de años anteriores",
                                     "Also bring in gifts from past years"))
                                .font(.system(size: 13, weight: .semibold))
                            Text(L.t("Así los informes y las constancias anuales salen completos desde hoy.",
                                     "So reports and annual statements are complete from today."))
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button(L.t("Importar aportes…", "Import gifts…")) {
                            cerrar()
                            estado.pidiendoImportarAportes = true
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.tarjeta, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.quaternary, lineWidth: 0.5))
                }

                if sinConexion {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "icloud").foregroundStyle(.secondary)
                        (Text(L.t("Guardado en este Mac", "Saved on this Mac")).bold()
                         + Text(" · ")
                         + Text(L.t("Ahora no hay internet. Ya están en Tamio y subirán solas cuando vuelva la conexión.",
                                    "There’s no internet right now. They’re already in Tamio and will upload on their own when you’re back online."))
                            .foregroundColor(.secondary))
                            .font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(suelo, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                if viendoOmitidas && fuera > 0 {
                    seccionOmitidas(omitidasAlImportar)
                }
            }
        }
    }

    private func textoHecho(_ fuera: Int) -> String {
        let donde = destino == .membresia
            ? L.t("Las encontrarás en Membresía.", "You’ll find them in Membership.")
            : L.t("Las encontrarás en Aportantes.", "You’ll find them in Contributors.")
        guard fuera > 0 else { return donde }
        let quedaron = fuera == 1
            ? L.t("1 fila se quedó fuera: arréglala en el archivo e impórtalo otra vez.",
                  "1 row was left out: fix it in the file and import it again.")
            : L.t("\(fuera) filas se quedaron fuera: arréglalas en el archivo e impórtalo otra vez.",
                  "\(fuera) rows were left out: fix them in the file and import it again.")
        return donde + " " + quedaron
    }

    // MARK: Pie

    @ViewBuilder
    private var pie: some View {
        switch fase {
        case .revisar:
            HStack(spacing: 9) {
                Text(L.t("Esc cierra · ⌘S importa", "Esc closes · ⌘S imports"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Button(L.t("Cancelar", "Cancel")) { cerrar() }
                    .keyboardShortcut(.cancelAction)
                if nada {
                    Button(L.t("Nada que importar", "Nothing to import")) {}
                        .disabled(true)
                } else {
                    Button(action: importar) {
                        HStack(spacing: 6) {
                            Text(L.t("Importar \(aplicables.count)", "Import \(aplicables.count)"))
                            Text("⌘S").opacity(0.75)
                        }
                        .etiquetaSobreRelleno()
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(Paleta.brand)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)

        case .importando(let hechas, let de):
            HStack(spacing: 14) {
                Text(de == 1 ? L.t("Importando 1 persona…", "Importing 1 person…")
                             : L.t("Importando \(de) personas…", "Importing \(de) people…"))
                    .font(.system(size: 12.5))
                    .fixedSize()
                ProgressView(value: Double(hechas), total: Double(max(de, 1)))
                    .progressViewStyle(.linear)
                    .tint(Paleta.brand)
                Text("\(hechas) / \(de)")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)

        case .hecho:
            HStack(spacing: 9) {
                if !omitidasAlImportar.isEmpty && !viendoOmitidas {
                    Button(omitidasAlImportar.count == 1
                           ? L.t("Ver la fila omitida", "See the skipped row")
                           : L.t("Ver las \(omitidasAlImportar.count) filas omitidas",
                                 "See the \(omitidasAlImportar.count) skipped rows")) {
                        viendoOmitidas = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Paleta.enlace)
                }
                Spacer(minLength: 0)
                Button {
                    irAlPadron(destino)
                    cerrar()
                } label: {
                    HStack(spacing: 6) {
                        Text(destino == .membresia ? L.t("Ir a Membresía", "Go to Membership")
                                                   : L.t("Ir a Aportantes", "Go to Contributors"))
                        Text("↩").opacity(0.75)
                    }
                    .etiquetaSobreRelleno()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Paleta.brand)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
        }
    }

    private func importar() {
        let lista = aplicables
        guard !lista.isEmpty else { return }
        omitidasAlImportar = errores
        fase = .importando(hechas: 0, de: lista.count)
        Task { @MainActor in
            await vm.importar(lista) { n in fase = .importando(hechas: n, de: lista.count) }
            // Que suba ya: en el Mac la app no se va al fondo, y sin esto las
            // fichas se quedarían en la cola hasta el próximo arranque.
            await MotorSincronizacion.compartido.sincronizar()
            // Y que las demás pantallas relean: Membresía tiene su propio
            // ViewModel y, sin esto, «Ir a Membresía» llevaba a una lista
            // que aún no tenía a los que acababan de entrar (visto: «10
            // members» con 13 en la base).
            estado.recargar()
            let motor = MotorSincronizacion.compartido
            fase = .hecho(importadas: lista.count,
                          sinConexion: motor.haFallado || motor.pendientes > 0)
        }
    }
}

/// **La hoja de importar aportes** (handoff «Trae tus datos», M5). La misma
/// forma que la de personas, pero **la franja fija enseña el dinero**: el
/// total y su reparto por año van delante, y el botón repite la cifra. Es
/// dinero que acaba en constancias fiscales, y lo primero que hay que poder
/// comprobar es si cuadra con lo que la iglesia tiene apuntado.
///
/// Al importar, cada aporte es un ingreso ya cerrado dentro de un corte
/// depositado (`MiembrosViewModel.importarAportes`): suma en los informes y
/// constancias de su año y no en el efectivo de hoy.
private struct HojaImportarAportes: View {
    let documento: CSVLector.Documento
    let archivo: String
    let vm: MiembrosViewModel
    let irA: (SeccionMac) -> Void

    @Environment(\.dismiss) private var cerrar
    @Environment(\.colorScheme) private var esquema
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @Environment(EstadoVentana.self) private var estado

    private enum Fase: Equatable {
        case revisar
        case importando(hechas: Int, de: Int)
        case hecho(cuantos: Int, total: Centavos, anios: [Int], sinConexion: Bool)
    }

    @State private var mapeo: [String: String] = [:]
    @State private var preparado = false
    @State private var fase: Fase = .revisar

    private var campos: [CSVLector.Campo] { ImportadorAportes.campos }

    private var analisis: ImportadorAportes.Analisis? {
        let mapeado = CSVLector.aplicar(mapeo, a: documento, campos: campos)
        return try? ImportadorAportes.analizar(mapeado, existentes: vm.items)
    }

    private var nuevos: [Aporte] {
        (analisis?.filas ?? []).compactMap { f in
            if case .nuevo = f.destino { return f.aporte }
            return nil
        }
    }
    private var total: Centavos { nuevos.reduce(0) { $0 + $1.monto } }
    private var errores: [ImportadorAportes.FilaAnalizada] { analisis?.errores ?? [] }

    /// El reparto por año, del más antiguo al más reciente.
    private var porAnio: [(anio: Int, cuantos: Int, monto: Centavos)] {
        let cal = Calendar.current
        let grupos = Dictionary(grouping: nuevos) { cal.component(.year, from: $0.fecha) }
        return grupos.keys.sorted().map { a in
            let l = grupos[a] ?? []
            return (a, l.count, l.reduce(0) { $0 + $1.monto })
        }
    }

    private var importando: Bool {
        if case .importando = fase { return true }
        return false
    }

    private var suelo: Color { esquema == .dark ? Color(white: 0x1C / 255) : Color(red: 0xEA / 255, green: 0xEA / 255, blue: 0xEF / 255) }
    private var fondoFranja: Color { esquema == .dark ? Color(white: 0x2B / 255) : Color(white: 0xF6 / 255) }

    var body: some View {
        VStack(spacing: 0) {
            cabecera
            Divider()
            if case .hecho = fase {
                hecho.padding(18)
            } else {
                franja
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SeccionHoja(titulo: L.t("COLUMNAS DEL ARCHIVO", "FILE COLUMNS"),
                                    nota: L.t("Cada aporte se apunta a una persona que ya esté en Tamio, por su id o por su nombre.",
                                              "Each gift is linked to a person already in Tamio, by id or by name.")) {
                            ForEach(campos) { filaColumna($0) }
                        }
                        SeccionHoja(titulo: L.t("QUÉ VA A PASAR", "WHAT WILL HAPPEN"),
                                    nota: nuevos.isEmpty ? nil : avisoDinero) {
                            filaResumen("plus.circle.fill", Paleta.brand, nuevos.count,
                                        L.t("aportes nuevos", "new gifts"))
                            filaResumen("equal.circle.fill", Paleta.enlace, analisis?.duplicados ?? 0,
                                        L.t("ya estaban registrados, se omiten", "already recorded, will be skipped"))
                            filaResumen("exclamationmark.triangle.fill", Paleta.aviso, errores.count,
                                        L.t("filas con problemas, se omiten", "rows with problems, will be skipped"))
                        }
                        if !errores.isEmpty { omitidas }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
                .frame(maxHeight: 520)
                .disabled(importando)
            }
            Divider()
            pie
        }
        .frame(width: 640)
        .interactiveDismissDisabled(importando)
        .onAppear {
            guard !preparado else { return }
            preparado = true
            mapeo = CSVLector.mapeoSugerido(documento, campos: campos)
        }
    }

    private var cabecera: some View {
        HStack(spacing: 10) {
            Text(L.t("Importar aportes", "Import gifts"))
                .font(.system(size: 13.5, weight: .semibold))
            if case .hecho = fase {} else {
                Text("\(archivo) · " + (documento.filas.count == 1
                                         ? L.t("1 fila", "1 row")
                                         : L.t("\(documento.filas.count) filas", "\(documento.filas.count) rows")))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(suelo, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Spacer(minLength: 0)
            Button(L.t("Cerrar", "Close")) { cerrar() }
                .buttonStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(importando ? Color.secondary : Paleta.enlace)
                .disabled(importando)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    /// El total a la izquierda y el reparto por año a la derecha (M5).
    private var franja: some View {
        let anios = porAnio
        let mayor = anios.map(\.monto).max() ?? 1
        return HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("SE VA A SUMAR", "WILL BE ADDED"))
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(.secondary)
                Text(Money.fmt(total))
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)
                    .monospacedDigit()
                    .foregroundStyle(nuevos.isEmpty ? .tertiary : .primary)
                Text(nuevos.count == 1 ? L.t("1 aporte nuevo", "1 new gift")
                                       : L.t("\(nuevos.count) aportes nuevos", "\(nuevos.count) new gifts"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
            VStack(spacing: 6) {
                ForEach(anios, id: \.anio) { a in
                    HStack(spacing: 10) {
                        Text(String(a.anio))
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Paleta.brandFill)
                                Capsule().fill(Paleta.brand)
                                    .frame(width: g.size.width * CGFloat(a.monto) / CGFloat(max(mayor, 1)))
                            }
                        }
                        .frame(height: 6)
                        Text(Money.fmt(a.monto))
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                            .frame(width: 104, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(fondoFranja)
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

    private func filaColumna(_ campo: CSVLector.Campo) -> some View {
        ArmazonFila {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text(campo.rotulo)
                    if campo.obligatorio { Text("*").foregroundStyle(.primary) }
                }
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .frame(width: 200, alignment: .leading)
                Picker("", selection: Binding(
                    get: { mapeo[campo.clave] ?? "" },
                    set: { mapeo[campo.clave] = $0.isEmpty ? nil : $0 })) {
                    Text(L.t("— No importar —", "— Don’t import —")).tag("")
                    ForEach(documento.encabezados.filter { !$0.isEmpty }, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(minWidth: 190, maxWidth: 240, alignment: .leading)
                .accessibilityLabel(campo.rotulo)
                Spacer(minLength: 0)
            }
        }
    }

    private func filaResumen(_ icono: String, _ tinta: Color, _ n: Int, _ texto: String) -> some View {
        ArmazonFila {
            HStack(spacing: 10) {
                Image(systemName: icono).foregroundStyle(tinta)
                Text("\(n)").font(.system(size: 13, weight: .semibold)).monospacedDigit()
                Text(texto).font(.system(size: 12.5)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    /// Cada omitida con su fecha e importe, que es lo que permite encontrarla
    /// en el cuaderno de la tesorería.
    private var omitidas: some View {
        SeccionHoja(titulo: L.t("FILAS QUE SE OMITEN", "SKIPPED ROWS"),
                    nota: L.t("Arregla estas filas en tu archivo y vuelve a importarlo: los aportes que ya entraron no se duplican.",
                              "Fix these rows in your file and import it again: gifts already in won’t be duplicated.")) {
            ForEach(errores.prefix(50)) { f in
                ArmazonFila {
                    HStack(spacing: 12) {
                        Text(L.t("Línea \(f.linea)", "Row \(f.linea)"))
                            .font(.system(size: 11.5)).monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .frame(width: 62, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.aportante.isEmpty ? L.t("(sin nombre)", "(no name)") : f.aportante)
                                .font(.system(size: 12.5))
                                .lineLimit(1)
                            Text("\(f.fecha) · \(f.monto)")
                                .font(.system(size: 11)).monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if case .error(let m) = f.destino {
                            Text(m).font(.system(size: 11.5)).foregroundStyle(Paleta.negativo)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            if errores.count > 50 {
                ArmazonFila {
                    Text(L.t("y \(errores.count - 50) más…", "and \(errores.count - 50) more…"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var hecho: some View {
        if case .hecho(let n, let suma, let anios, let sinConexion) = fase {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Paleta.brand, in: Circle())
                    Text(n == 1 ? L.t("1 aporte registrado", "1 gift recorded")
                                : L.t("\(n) aportes registrados", "\(n) gifts recorded"))
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.3)
                    Text(textoHecho(suma, anios))
                        .font(.system(size: 13)).lineSpacing(3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 440)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12).padding(.bottom, 6)
                if sinConexion {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "icloud").foregroundStyle(.secondary)
                        (Text(L.t("Guardado en este Mac", "Saved on this Mac")).bold()
                         + Text(" · ")
                         + Text(L.t("Ahora no hay internet. Ya están en Tamio y subirán solas cuando vuelva la conexión.",
                                    "There’s no internet right now. They’re already in Tamio and will upload on their own when you’re back online."))
                            .foregroundColor(.secondary))
                            .font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(suelo, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }
        }
    }

    private func textoHecho(_ suma: Centavos, _ anios: [Int]) -> String {
        let rango: String
        if let a = anios.first, let b = anios.last, a != b {
            rango = L.t("entre \(a) y \(b)", "across \(a)–\(b)")
        } else {
            rango = L.t("en \(anios.first.map(String.init) ?? "")", "in \(anios.first.map(String.init) ?? "")")
        }
        return L.t("Suman \(Money.fmt(suma)) \(rango). Los informes y las constancias de esos años ya los incluyen.",
                   "They total \(Money.fmt(suma)) \(rango). Reports and statements for those years already include them.")
    }

    @ViewBuilder
    private var pie: some View {
        switch fase {
        case .revisar:
            HStack(spacing: 9) {
                Text(L.t("Esc cierra · ⌘S importa", "Esc closes · ⌘S imports"))
                    .font(.system(size: 11.5)).foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Button(L.t("Cancelar", "Cancel")) { cerrar() }
                    .keyboardShortcut(.cancelAction)
                if nuevos.isEmpty {
                    Button(L.t("Nada que importar", "Nothing to import")) {}
                        .disabled(true)
                } else {
                    Button(action: importar) {
                        HStack(spacing: 6) {
                            Text(L.t("Importar \(nuevos.count) · \(Money.fmt(total))",
                                     "Import \(nuevos.count) · \(Money.fmt(total))"))
                            Text("⌘S").opacity(0.75)
                        }
                        .etiquetaSobreRelleno()
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(Paleta.brand)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)

        case .importando(let hechas, let de):
            HStack(spacing: 14) {
                Text(de == 1 ? L.t("Importando 1 aporte…", "Importing 1 gift…")
                             : L.t("Importando \(de) aportes…", "Importing \(de) gifts…"))
                    .font(.system(size: 12.5))
                    .fixedSize()
                ProgressView(value: Double(hechas), total: Double(max(de, 1)))
                    .progressViewStyle(.linear)
                    .tint(Paleta.brand)
                Text("\(hechas) / \(de)")
                    .font(.system(size: 12)).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)

        case .hecho:
            HStack(spacing: 9) {
                Spacer(minLength: 0)
                Button {
                    irA(.inicio)
                    cerrar()
                } label: {
                    HStack(spacing: 6) {
                        Text(L.t("Ir al Inicio", "Go to Home"))
                        Text("↩").opacity(0.75)
                    }
                    .etiquetaSobreRelleno()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Paleta.brand)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
        }
    }

    private func importar() {
        guard let a = analisis, !nuevos.isEmpty else { return }
        let lote = a.porAportante
        let cuantos = nuevos.count
        let suma = total
        let anios = porAnio.map(\.anio)
        fase = .importando(hechas: 0, de: cuantos)
        Task { @MainActor in
            await vm.importarAportes(lote, archivo: archivo,
                                     autor: sesion?.perfil.firma ?? "") { n in
                fase = .importando(hechas: n, de: cuantos)
            }
            await MotorSincronizacion.compartido.sincronizar()
            estado.recargar()
            let motor = MotorSincronizacion.compartido
            fase = .hecho(cuantos: cuantos, total: suma, anios: anios,
                          sinConexion: motor.haFallado || motor.pendientes > 0)
        }
    }
}

extension Aportante {
    /// Para ordenar por "último aporte" sin perder a quien no tiene ninguno.
    /// **Los que nunca aportaron van al final**, no al principio: `Date?` nulo
    /// ordenado como fecha cero los pondría arriba, que es justo al revés de
    /// lo que se busca al ordenar por esta columna.
    var ordenUltimoAporte: Date { ultimoAporte ?? .distantPast }
}
