import PhotosUI
import SwiftUI

/// **La fila del logo de Ajustes · Iglesia**, la misma en el teléfono y en el
/// iPad.
///
/// Es una vista y no dos porque el logo tiene tres estados —no hay, está
/// subiendo, ya está— y cada uno dice algo distinto. Escrita dos veces, la
/// segunda copia se queda con dos de los tres: es exactamente lo que había
/// pasado con el hueco de "Próximamente", que en el iPad prometía una pantalla
/// que no existía y en el teléfono no.
///
/// La ruta es un `Binding` a `ConfiguracionIglesia.logoPath` para que quien
/// escriba ese campo siga siendo su dueño —el guardado automático se dispara
/// solo al cambiarlo—, mientras que los BYTES los administra `LogoIglesia`.
struct SelectorLogo: View {
    @Binding var ruta: String
    /// El teléfono lo pinta dentro de una `List` con su propio fondo; el iPad,
    /// dentro de un `GrupoConf`. Solo cambia el relleno.
    var enLista = true

    @State private var logo = LogoIglesia.compartido
    @State private var seleccion: PhotosPickerItem?
    @State private var error: String?
    @State private var confirmarQuitar = false

    private var iniciales: String {
        ConfiguracionIglesiaViewModel.compartido.config.iniciales
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("Logo", "Logo"))
                        .font(enLista ? .subheadline : .system(size: 16, weight: .semibold))
                    Text(L.t("Sale en el membrete de cartas, actas y reportes.",
                             "Appears on the letterhead of letters, minutes, and reports."))
                        .font(enLista ? .caption : .system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if logo.trabajando {
                    ProgressView()
                }
                // Elegir y reemplazar son el mismo gesto, así que son el mismo
                // control: tocar la imagen abre el carrete.
                PhotosPicker(selection: $seleccion, matching: .images,
                             photoLibrary: .shared()) {
                    vistaPrevia
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: enLista ? 0 : 64)
            .padding(.horizontal, enLista ? 0 : Esp.pantalla)
            .padding(.vertical, enLista ? 6 : 0)

            if logo.imagen != nil {
                Button(role: .destructive) { confirmarQuitar = true } label: {
                    Text(L.t("Quitar logo", "Remove logo"))
                        .font(.subheadline).foregroundStyle(Paleta.negativo)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, enLista ? 0 : Esp.pantalla)
                .padding(.bottom, enLista ? 4 : 12)
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(Paleta.negativo)
                    .padding(.horizontal, enLista ? 0 : Esp.pantalla)
                    .padding(.bottom, enLista ? 4 : 12)
            }
        }
        .onChange(of: seleccion) { _, nuevo in
            guard let nuevo else { return }
            Task { await tomar(nuevo) }
        }
        .alert(L.t("¿Quitar el logo?", "Remove the logo?"), isPresented: $confirmarQuitar) {
            Button(L.t("Cancelar", "Cancel"), role: .cancel) {}
            Button(L.t("Quitar", "Remove"), role: .destructive) {
                Task { await quitar() }
            }
        } message: {
            Text(L.t("Los documentos volverán a salir sin logo, en todos los aparatos de la iglesia.",
                     "Documents will print without a logo again, on every device in the church."))
        }
    }

    /// Con logo, el logo. Sin él, las iniciales de la IGLESIA —no las de la
    /// persona, que es lo que decía este hueco antes— sobre el verde de marca,
    /// que es lo que va a salir en el papel mientras no haya imagen.
    @ViewBuilder
    private var vistaPrevia: some View {
        if let imagen = logo.imagen {
            Image(uiImage: imagen)
                .resizable().scaledToFit()
                .frame(width: 46, height: 46)
                .padding(4)
                .background(Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Text(iniciales)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Paleta.brand,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func tomar(_ item: PhotosPickerItem) async {
        error = nil
        seleccion = nil
        guard let datos = try? await item.loadTransferable(type: Data.self),
              let imagen = UIImage(data: datos) else {
            error = L.t("No se pudo leer esa imagen.", "That image couldn't be read.")
            return
        }
        do {
            // La ruta se escribe DESPUÉS de que la subida salga bien: guardarla
            // antes dejaría a los demás aparatos buscando un archivo que no
            // llegó a existir, y ellos no tienen forma de saberlo.
            ruta = try await logo.poner(imagen)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func quitar() async {
        await logo.quitar(rutaAnterior: ruta)
        ruta = ""
    }
}
