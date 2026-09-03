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
                                texto: L.t("aportantes nuevos", "new givers"))
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
            .navigationTitle(L.t("Importar aportantes", "Import givers"))
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
        .hojaGrande()
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
