import SwiftUI

/// Previsualización de la importación del historial de aportes.
struct ImportarAportesView: View {
    let analisis: ImportadorAportes.Analisis
    let onConfirmar: ([String: [Aporte]]) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Suma de lo que se va a añadir. Es la cifra que de verdad quiere ver
    /// quien importa dinero: "287 aportes" no dice si el archivo es el bueno,
    /// pero el total sí se compara de un vistazo con lo que uno esperaba.
    private var totalNuevo: Centavos {
        analisis.filas.reduce(0) { suma, fila in
            if case .nuevo = fila.destino, let ap = fila.aporte { return suma + ap.monto }
            return suma
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !analisis.columnasFaltantes.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L.t("Falta la columna «\(analisis.columnasFaltantes.joined(separator: ", "))»",
                                     "Missing column «\(analisis.columnasFaltantes.joined(separator: ", "))»"))
                                .font(.subheadline.weight(.semibold))
                            Text(L.t("Exporta primero tus aportes para ver el formato esperado.",
                                     "Export your gifts first to see the expected format."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        fila(icono: "plus.circle.fill", color: Paleta.brand,
                             valor: "\(analisis.nuevos)",
                             texto: L.t("aportes nuevos", "new gifts"))
                        fila(icono: "banknote", color: Paleta.brand,
                             valor: Money.fmt(totalNuevo),
                             texto: L.t("suman en total", "total amount"))
                        if analisis.duplicados > 0 {
                            fila(icono: "equal.circle.fill", color: Paleta.enlace,
                                 valor: "\(analisis.duplicados)",
                                 texto: L.t("ya estaban registrados, se omiten",
                                            "already recorded, will be skipped"))
                        }
                        if !analisis.errores.isEmpty {
                            fila(icono: "exclamationmark.triangle.fill", color: Paleta.aviso,
                                 valor: "\(analisis.errores.count)",
                                 texto: L.t("filas con problemas", "rows with problems"))
                        }
                    } header: {
                        Text(L.t("QUÉ VA A PASAR", "WHAT WILL HAPPEN")).textCase(nil)
                    }

                    if !analisis.errores.isEmpty {
                        Section {
                            ForEach(analisis.errores) { f in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L.t("Línea \(f.linea) · \(f.aportante)",
                                             "Row \(f.linea) · \(f.aportante)"))
                                        .font(.subheadline.weight(.medium))
                                    if case .error(let motivo) = f.destino {
                                        Text("\(motivo) — \(f.fecha) \(f.monto)")
                                            .font(.caption).foregroundStyle(Paleta.negativo)
                                    }
                                }
                            }
                        } header: {
                            Text(L.t("FILAS QUE SE OMITEN", "SKIPPED ROWS")).textCase(nil)
                        }
                    }

                    Section {
                        ForEach(analisis.filas.prefix(50)) { f in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.aportante).font(.subheadline)
                                    Text("\(f.fecha) · \(f.concepto)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(f.monto).font(.subheadline.weight(.medium)).monospacedDigit()
                                marca(f.destino)
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
            .navigationTitle(L.t("Importar aportes", "Import gifts"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Importar \(analisis.aplicables)", "Import \(analisis.aplicables)")) {
                        onConfirmar(analisis.porAportante)
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
    private func marca(_ destino: ImportadorAportes.Destino) -> some View {
        switch destino {
        case .nuevo:
            Image(systemName: "plus.circle.fill").foregroundStyle(Paleta.brand)
        case .duplicado:
            Image(systemName: "equal.circle.fill").foregroundStyle(Paleta.enlace)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Paleta.aviso)
        }
    }

    private func fila(icono: String, color: Color, valor: String, texto: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icono).foregroundStyle(color)
            Text(valor).font(.title3.weight(.bold)).monospacedDigit()
            Text(texto).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
    }
}
