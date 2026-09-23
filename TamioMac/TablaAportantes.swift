import SwiftUI
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

    @State private var eligiendoArchivo = false
    @State private var porImportar: DocumentoPorImportar?
    @State private var falloDeLectura: String?

    private var filas: [Aportante] { vm.itemsFiltrados.sorted(using: orden) }
    private var anio: Int { vm.anio }

    var body: some View {
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
            .width(min: 160, ideal: 260)

            TableColumn(L.t("Miembro desde", "Member since"), value: \.congregaDesde) { a in
                Text(a.congregaDesde.isEmpty ? "—" : a.congregaDesde)
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 120, max: 170)

            TableColumn(L.t("Frecuencia", "Frequency"), value: \.frecuencia.rawValue) { a in
                Text(a.frecuencia.etiqueta).foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 124, max: 170)

            TableColumn(L.t("Último aporte", "Last gift"), value: \.ordenUltimoAporte) { a in
                Text(a.ultimoAporte.map {
                    $0.formatted(.dateTime.day().month(.abbreviated))
                } ?? "—")
                .foregroundStyle(a.ultimoAporte == nil ? .tertiary : .secondary)
            }
            .width(min: 100, ideal: 120, max: 170)

            TableColumn(L.t("Acumulado", "Year to date"), value: \.nombre) { a in
                let t = a.total(anio: anio)
                Text(t == 0 ? "—" : Money.fmt(t))
                    .monospacedDigit()
                    .fontWeight(t == 0 ? .regular : .semibold)
                    .foregroundStyle(t == 0 ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 110, ideal: 140, max: 190)
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
                Button(L.t("Importar aportantes… (CSV)", "Import contributors… (CSV)")) {
                    eligiendoArchivo = true
                }
            }
        }
        // La misma orden desde Archivo › Importar aportantes…. El menú es otra
        // escena y no alcanza el `@State` de esta tabla: deja el testigo en
        // `EstadoVentana` y aquí se apaga al recogerlo, como `pidiendoAlta`.
        // `initial` porque el menú cambia de sección y enciende el testigo a
        // la vez: si se pide desde otra pantalla, esta tabla nace con él ya
        // encendido y un `onChange` normal no lo vería nunca.
        .onChange(of: estado.pidiendoImportarAportantes, initial: true) { _, pedido in
            guard pedido else { return }
            estado.pidiendoImportarAportantes = false
            if puedeImportar { eligiendoArchivo = true }
        }
        .fileImporter(isPresented: $eligiendoArchivo,
                      allowedContentTypes: [.commaSeparatedText, .plainText, .text],
                      allowsMultipleSelection: false) { resultado in
            do {
                guard let url = try resultado.get().first else { return }
                // El mismo lector que usa el iPhone: detecta coma o punto y
                // coma, quita el BOM y desambigua cabeceras repetidas.
                porImportar = DocumentoPorImportar(documento: try CSVLector.leer(url))
            } catch {
                falloDeLectura = error.localizedDescription
            }
        }
        .sheet(item: $porImportar) { p in
            HojaImportarAportantes(documento: p.documento, existentes: vm.items) { lista in
                Task {
                    await vm.importar(lista)
                    // Que la importación SALGA ya, por lo mismo que la captura
                    // rápida: en el Mac la app no se va al fondo, y sin esto
                    // las fichas se quedarían en la cola hasta el próximo
                    // arranque.
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
        .alert(L.t("No se pudo leer el archivo", "Couldn't read the file"),
               isPresented: Binding(get: { falloDeLectura != nil },
                                    set: { if !$0 { falloDeLectura = nil } })) {
            Button(L.t("Aceptar", "OK"), role: .cancel) { falloDeLectura = nil }
        } message: {
            Text(falloDeLectura ?? "")
        }
    }
}

/// El CSV leído, esperando a que se mapee. `Identifiable` para la hoja.
private struct DocumentoPorImportar: Identifiable {
    let id = UUID()
    let documento: CSVLector.Documento
}

/// **Importar aportantes, en una sola hoja: mapear y ver qué va a pasar.**
///
/// En iOS son dos hojas seguidas (`MapearColumnasView` y
/// `ImportarAportantesView`), pero viven en `Tamio/Views` y el Mac no las
/// compila. Lo que sí es compartido es lo que importa —`CSVLector` para leer
/// y mapear, `ImportadorAportantes` para decidir fila a fila y
/// `MiembrosViewModel.importar` para escribir—, así que aquí solo se dibuja.
///
/// **En una hoja y no en dos porque en el Mac cabe.** Con el resumen al lado
/// del mapeo, cambiar una columna enseña al momento cuántas filas se caen, que
/// es la pregunta que se hace quien mapea; en dos hojas había que ir y volver.
///
/// Nada se escribe hasta pulsar "Importar": la importación es lo único de la
/// app que puede estropear fichas en masa.
private struct HojaImportarAportantes: View {
    let documento: CSVLector.Documento
    let existentes: [Aportante]
    let alConfirmar: ([Aportante]) -> Void

    @State private var mapeo: [String: String] = [:]
    @State private var intentoGuardar = false
    @State private var sugerido = false

    private var campos: [CSVLector.Campo] { ImportadorAportantes.campos }

    /// Se recalcula con cada cambio de columna. Un CSV de padrón son cientos
    /// de filas, no millones: rehacerlo entero es más simple que cachearlo y
    /// no se nota.
    private var analisis: ImportadorAportantes.Analisis? {
        let mapeado = CSVLector.aplicar(mapeo, a: documento, campos: campos)
        return try? ImportadorAportantes.analizar(mapeado, existentes: existentes)
    }

    private var aplicables: [Aportante] {
        (analisis?.filas ?? []).compactMap { fila in
            switch fila.destino {
            case .nuevo, .actualiza: return fila.aportante
            case .error: return nil
            }
        }
    }

    private var faltan: [String] {
        let sinColumna = CSVLector.faltantes(mapeo, campos: campos)
            .map { L.t("la columna de «\($0.rotulo)»", "the «\($0.rotulo)» column") }
        if !sinColumna.isEmpty { return sinColumna }
        return aplicables.isEmpty
            ? [L.t("alguna fila que se pueda importar", "a row that can be imported")] : []
    }

    /// Las columnas del archivo, más "no importar". Las cabeceras vacías se
    /// quitan: no se pueden nombrar en un menú y repetirían la etiqueta del
    /// "no importar", que también es la cadena vacía.
    private var opcionesDeColumna: [(valor: String, etiqueta: String)] {
        [(valor: "", etiqueta: L.t("— No importar —", "— Don't import —"))]
            + documento.encabezados.filter { !$0.isEmpty }
                .map { (valor: $0, etiqueta: $0) }
    }

    var body: some View {
        HojaMac(titulo: L.t("Importar aportantes", "Import contributors"),
                rotuloGuardar: L.t("Importar \(aplicables.count)", "Import \(aplicables.count)"),
                faltan: faltan,
                intentoGuardar: intentoGuardar,
                alGuardar: guardar) {
            SeccionHoja(titulo: L.t("COLUMNAS DEL ARCHIVO", "FILE COLUMNS"),
                        nota: L.t("Las que se reconocieron por su nombre ya vienen elegidas. Solo el nombre es obligatorio; lo demás se completa luego en la ficha.",
                                  "Columns recognized by name are already chosen. Only the name is required; the rest can be filled in later on the record.")) {
                ForEach(campos) { campo in
                    FilaSelector(rotulo: campo.obligatorio ? "\(campo.rotulo) *" : campo.rotulo,
                                 valor: Binding(
                                    get: { mapeo[campo.clave] ?? "" },
                                    set: { mapeo[campo.clave] = $0.isEmpty ? nil : $0 }),
                                 opciones: opcionesDeColumna)
                }
            }
            if let a = analisis { resumen(a) }
        }
        .onAppear {
            // Una sola vez: si no, volver a la hoja pisaría lo que se corrigió.
            guard !sugerido else { return }
            sugerido = true
            mapeo = CSVLector.mapeoSugerido(documento, campos: campos)
        }
    }

    @ViewBuilder
    private func resumen(_ a: ImportadorAportantes.Analisis) -> some View {
        SeccionHoja(titulo: L.t("QUÉ VA A PASAR", "WHAT WILL HAPPEN")) {
            filaResumen("plus.circle.fill", Paleta.brand, a.nuevos,
                        L.t("aportantes nuevos", "new contributors"))
            filaResumen("arrow.triangle.2.circlepath", Paleta.enlace, a.actualizados,
                        L.t("ya existen y se actualizarán", "already exist, will be updated"))
            if !a.errores.isEmpty {
                filaResumen("exclamationmark.triangle.fill", Paleta.aviso, a.errores.count,
                            L.t("filas con problemas, se omitirán", "rows with problems, will be skipped"))
            }
        }
        if !a.errores.isEmpty {
            // Una a una y con su línea: "hay 3 errores" sin decir dónde no
            // deja arreglar el archivo.
            SeccionHoja(titulo: L.t("FILAS QUE SE OMITEN", "SKIPPED ROWS")) {
                ForEach(a.errores.prefix(50)) { fila in
                    ArmazonFila {
                        HStack(spacing: 12) {
                            Text(L.t("Línea \(fila.linea) · \(fila.nombre)",
                                     "Row \(fila.linea) · \(fila.nombre)"))
                                .font(.system(size: 12.5))
                            Spacer(minLength: 0)
                            if case .error(let motivo) = fila.destino {
                                Text(motivo)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Paleta.negativo)
                            }
                        }
                    }
                }
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

    /// Devuelve si se importó, que es lo que cierra la hoja (`HojaMac`).
    private func guardar() -> Bool {
        intentoGuardar = true
        guard faltan.isEmpty else { return false }
        alConfirmar(aplicables)
        return true
    }
}

extension Aportante {
    /// Para ordenar por "último aporte" sin perder a quien no tiene ninguno.
    /// **Los que nunca aportaron van al final**, no al principio: `Date?` nulo
    /// ordenado como fecha cero los pondría arriba, que es justo al revés de
    /// lo que se busca al ordenar por esta columna.
    var ordenUltimoAporte: Date { ultimoAporte ?? .distantPast }
}
