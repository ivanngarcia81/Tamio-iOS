import SwiftUI

/// Previsualización de una importación. Enseña **qué va a pasar** y no toca
/// nada hasta que se confirma.
///
/// Sin este paso, un archivo con la columna del nombre mal puesta crearía
/// trescientos aportantes basura, y no habría forma cómoda de deshacerlo.
struct ImportarAportantesView: View {
    let analisis: ImportadorAportantes.Analisis
    let onConfirmar: ([Aportante]) -> Void

    @Environment(\.dismiss) private var dismiss

    private var aplicables: [Aportante] {
        analisis.filas.compactMap { fila in
            switch fila.destino {
            case .nuevo, .actualiza: return fila.aportante
            case .error: return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !analisis.columnasFaltantes.isEmpty {
                    Section {
                        etiqueta(icono: "xmark.octagon.fill", color: Paleta.negativo,
                                 titulo: L.t("Falta la columna «\(analisis.columnasFaltantes.joined(separator: ", "))»",
                                             "Missing column «\(analisis.columnasFaltantes.joined(separator: ", "))»"),
                                 detalle: L.t("Descarga la plantilla desde Exportar y vuelve a intentarlo.",
                                              "Download the template from Export and try again."))
                    }
                } else {
                    Section {
                        resumen(icono: "plus.circle.fill", color: Paleta.brand,
                                n: analisis.nuevos,
                                texto: L.t("aportantes nuevos", "new contributors"))
                        resumen(icono: "arrow.triangle.2.circlepath", color: Paleta.enlace,
                                n: analisis.actualizados,
                                texto: L.t("ya existen y se actualizarán", "already exist, will be updated"))
                        if !analisis.errores.isEmpty {
                            resumen(icono: "exclamationmark.triangle.fill", color: Paleta.aviso,
                                    n: analisis.errores.count,
                                    texto: L.t("filas con problemas, se omitirán", "rows with problems, will be skipped"))
                        }
                    } header: {
                        Text(L.t("QUÉ VA A PASAR", "WHAT WILL HAPPEN")).textCase(nil)
                    }

                    if !analisis.errores.isEmpty {
                        Section {
                            // Se listan una a una con su número de línea: decir
                            // "hay 3 errores" sin decir dónde no sirve de nada.
                            ForEach(analisis.errores) { fila in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L.t("Línea \(fila.linea) · \(fila.nombre)",
                                             "Row \(fila.linea) · \(fila.nombre)"))
                                        .font(.subheadline.weight(.medium))
                                    if case .error(let motivo) = fila.destino {
                                        Text(motivo).font(.caption).foregroundStyle(Paleta.negativo)
                                    }
                                }
                            }
                        } header: {
                            Text(L.t("FILAS QUE SE OMITEN", "SKIPPED ROWS")).textCase(nil)
                        }
                    }

                    Section {
                        ForEach(analisis.filas.prefix(50)) { fila in
                            HStack {
                                Text(fila.nombre).font(.subheadline)
                                Spacer()
                                marca(fila.destino)
                            }
                        }
                        if analisis.filas.count > 50 {
                            Text(L.t("y \(analisis.filas.count - 50) más…",
                                     "and \(analisis.filas.count - 50) more…"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } header: {
                        Text(L.t("DETALLE", "DETAIL")).textCase(nil)
                    }
                }
            }
            .navigationTitle(L.t("Importar aportantes", "Import contributors"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Importar \(analisis.aplicables)", "Import \(analisis.aplicables)")) {
                        onConfirmar(aplicables)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Paleta.brand)
                    .disabled(analisis.aplicables == 0)
                }
            }
        }
        .hojaFormulario()
    }

    @ViewBuilder
    private func marca(_ destino: ImportadorAportantes.Destino) -> some View {
        switch destino {
        case .nuevo:
            Text(L.t("Nuevo", "New")).font(.caption.weight(.semibold))
                .foregroundStyle(Paleta.brand)
        case .actualiza:
            Text(L.t("Actualiza", "Update")).font(.caption.weight(.semibold))
                .foregroundStyle(Paleta.enlace)
        case .error:
            Text(L.t("Se omite", "Skipped")).font(.caption.weight(.semibold))
                .foregroundStyle(Paleta.aviso)
        }
    }

    private func resumen(icono: String, color: Color, n: Int, texto: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icono).foregroundStyle(color)
            Text("\(n)").font(.title3.weight(.bold)).monospacedDigit()
            Text(texto).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func etiqueta(icono: String, color: Color, titulo: String, detalle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icono).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo).font(.subheadline.weight(.semibold))
                Text(detalle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Decir qué columna es cuál

/// **El paso que faltaba: mapear las columnas.**
///
/// Los dos importadores exigían los nombres de columna exactos —`nombre`,
/// `fecha`, `monto`— y, si no venían, avisaban de cuáles faltaban y no dejaban
/// seguir. Eso funciona con un archivo que salió de la propia exportación de
/// Tamio y falla con cualquier otro: nadie tiene un Excel cuya primera fila
/// diga exactamente eso. El app web lo resolvió preguntando
/// (`GenericCsvImportModal`), y esto lo refleja.
///
/// **Sale ya relleno con la sugerencia.** Un archivo exportado por Tamio se
/// reconoce entero y el usuario solo pulsa Continuar, que es como se comportaba
/// antes. Lo que cambia es que ahora un archivo distinto TAMBIÉN se puede
/// importar, corrigiendo el mapeo.
struct MapearColumnasView: View {
    let documento: CSVLector.Documento
    let campos: [CSVLector.Campo]
    /// Se llama con el documento ya reescrito con las claves de la app.
    let alContinuar: (CSVLector.Documento) -> Void

    @Environment(\.dismiss) private var cerrar
    @State private var mapeo: [String: String] = [:]

    /// El centinela de "esta columna no está en mi archivo". Un `Picker` no
    /// admite `nil` como etiqueta, y usar la cadena vacía la confundiría con
    /// una columna que de verdad se llame "".
    private static let ninguna = "\u{0}ninguna"

    private var faltantes: [CSVLector.Campo] {
        CSVLector.faltantes(mapeo, campos: campos)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(campos) { campo in fila(campo) }
                } header: {
                    Text(L.t("Qué columna es cuál", "Which column is which")).textCase(nil)
                } footer: {
                    if faltantes.isEmpty {
                        Text(L.t("Lo que dejes sin columna se queda vacío y se puede completar después en cada ficha.",
                                 "Anything left unmapped stays empty and can be filled in later on each record."))
                    } else {
                        Text(L.t("Falta por decir de dónde sale: \(faltantes.map(\.rotulo).joined(separator: ", ")).",
                                 "Still missing: \(faltantes.map(\.rotulo).joined(separator: ", "))."))
                            .foregroundStyle(Paleta.negativo)
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }
            .listStyle(.insetGrouped)
            // Corto porque en el teléfono se cortaba: "Columnas del…". El
            // subtítulo de la sección ya dice de qué va.
            .navigationTitle(L.t("Columnas", "Columns"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Continuar", "Continue")) {
                        alContinuar(CSVLector.aplicar(mapeo, a: documento, campos: campos))
                        cerrar()
                    }
                    .disabled(!faltantes.isEmpty)
                }
            }
            // La sugerencia se calcula una vez, al abrir: recalcularla en cada
            // dibujado pisaría lo que el usuario acabe de corregir.
            .task { mapeo = CSVLector.mapeoSugerido(documento, campos: campos) }
        }
    }

    private func fila(_ campo: CSVLector.Campo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(campo.rotulo).font(.subheadline)
                if campo.obligatorio {
                    Text(L.t("obligatorio", "required"))
                        .font(.caption)
                        .foregroundStyle(mapeo[campo.clave] == nil ? Paleta.negativo : .secondary)
                }
            }
            Spacer()
            Picker("", selection: Binding(
                get: { mapeo[campo.clave] ?? Self.ninguna },
                set: { nueva in
                    if nueva == Self.ninguna { mapeo[campo.clave] = nil }
                    else {
                        // Una columna del archivo no puede alimentar dos campos:
                        // se le quita a quien la tuviera.
                        for (k, v) in mapeo where v == nueva && k != campo.clave {
                            mapeo[k] = nil
                        }
                        mapeo[campo.clave] = nueva
                    }
                })) {
                Text(L.t("— ninguna —", "— none —")).tag(Self.ninguna)
                ForEach(documento.encabezados, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
        }
    }
}
