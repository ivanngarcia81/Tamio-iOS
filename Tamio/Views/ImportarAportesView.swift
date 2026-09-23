import SwiftUI

// La hoja de revisar aportes que vivía aquí se rehízo dentro de
// `HojaImportarIOS` (ImportarAportantesView.swift), con el dinero delante como
// pide el handoff «Trae tus datos» (I7 · P4). Quedan aquí las dos piezas de
// ese handoff que no son la hoja.

// MARK: - Ajustes › Datos, en el iPhone (P5)

/// **La casa fija de «Trae tus datos»** en el teléfono: importar personas,
/// importar aportes y las plantillas. Los aportes, solo a quien además ve
/// Tesorería: son dinero. El iPad tiene la suya en `ConfiguracionView`.
struct AjustesDatosView: View {
    @Environment(Navegacion.self) private var navegacion
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    var body: some View {
        let p = Permisos.vigentes(sesion)
        List {
            Section {
                fila(L.t("Importar personas…", "Import people…"), icono: "arrow.down") {
                    navegacion.pidiendoImportar = .personas
                }
                if p.ve(.tesoreria) {
                    fila(L.t("Importar aportes…", "Import gifts…"), icono: "dollarsign") {
                        navegacion.pidiendoImportar = .aportes
                    }
                }
                BotonPlantilla(tipo: .personas, estilo: .fila)
                if p.ve(.tesoreria) { BotonPlantilla(tipo: .aportes, estilo: .fila) }
            } header: {
                Text(L.t("Datos", "Data")).textCase(nil)
            } footer: {
                Text(L.t("Desde un CSV de Excel, de Google o de otro sistema. Si importas el mismo archivo dos veces, no se duplica nadie. Los aportes, siempre después de las personas.",
                         "From a CSV from Excel, Google or another system. Importing the same file twice won’t duplicate anyone. Gifts always go after people."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Datos", "Data"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fila(_ titulo: String, icono: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 12) {
                Image(systemName: icono)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(titulo).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - El padrón vacío (I8)

/// **«Aún no hay nadie en el padrón»**, con la salida a la importación. Es
/// donde busca quien se saltó la invitación: la casa fija es Ajustes › Datos,
/// pero aquí es donde se nota que falta la gente.
struct PadronVacioView: View {
    /// Quien no puede dar de alta ve solo el aviso.
    let puedeDarDeAlta: Bool
    let agregar: () -> Void

    @Environment(Navegacion.self) private var navegacion

    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: "arrow.down")
                .font(.title2)
                .foregroundStyle(Paleta.brand)
                .frame(width: 56, height: 56)
                .background(Paleta.brandFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(L.t("Aún no hay nadie en el padrón", "No one on the roll yet"))
                .font(.title3.bold())
            Text(L.t("Trae tu lista de un Excel o agrega a las personas una por una.",
                     "Bring in your list from Excel or add people one by one."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if puedeDarDeAlta {
                VStack(spacing: 10) {
                    Button {
                        navegacion.pidiendoImportar = .personas
                    } label: {
                        Text(L.t("Importar una lista…", "Import a list…"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .tint(Paleta.brand)
                    Button(action: agregar) {
                        Text(L.t("Agregar persona", "Add person"))
                            .font(.headline)
                            .foregroundStyle(Paleta.brand)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Paleta.brandFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 420)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
