import PencilKit
import PhotosUI
import SwiftUI

/// **Firmar en pantalla, con el dedo o con el Apple Pencil.**
///
/// Es lo que la app de escritorio no puede ofrecer: allí la firma se elige como
/// archivo PNG, y para eso alguien tiene que tener ya un PNG de su firma, con
/// fondo transparente, que es algo que un pastor no tiene. Aquí firma y ya.
///
/// Subir una imagen se queda como alternativa —una foto de la firma en papel, o
/// el mismo PNG que use en el Mac—, no como camino principal.
struct HojaFirma: View {
    let firmante: FirmasLocales.Firmante
    @Environment(\.dismiss) private var dismiss
    @State private var firmas = FirmasLocales.compartidas

    @State private var lienzo = PKCanvasView()
    /// Sube en cada trazo para que el botón de guardar se entere de que ya hay
    /// algo dibujado: `PKCanvasView` no es observable.
    @State private var trazos = 0
    @State private var fotoElegida: PhotosPickerItem?
    @State private var mostrarArchivos = false
    @State private var error: String?

    private var vacio: Bool { lienzo.drawing.strokes.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: Esp.pantalla) {
                Text(L.t("Firma dentro del recuadro, con el dedo o con el Apple Pencil.",
                         "Sign inside the box, with your finger or an Apple Pencil."))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Esp.pantalla)

                ZStack(alignment: .bottom) {
                    LienzoFirma(lienzo: lienzo) { trazos += 1 }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        // El recuadro tiene que VERSE: sobre el fondo de la
                        // hoja, en claro, el gris del lienzo es el mismo blanco
                        // y el texto de arriba señalaba una caja invisible.
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(.separator), lineWidth: 1)
                        }
                    // La raya de guía, como en el papel: sin ella la firma sale
                    // flotando a media altura y con una inclinación distinta
                    // cada vez.
                    Rectangle().fill(.secondary.opacity(0.35))
                        .frame(height: 1)
                        .padding(.horizontal, Esp.panel)
                        .padding(.bottom, 44)
                        .allowsHitTesting(false)
                }
                .frame(minHeight: 220)
                .padding(.horizontal, Esp.pantalla)

                if let error {
                    Text(error).font(.footnote).foregroundStyle(Paleta.negativo)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Esp.pantalla)
                }

                HStack(spacing: Esp.chip) {
                    Button {
                        lienzo.drawing = PKDrawing()
                        trazos += 1
                    } label: {
                        Text(L.t("Borrar", "Clear")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .disabled(vacio)

                    PhotosPicker(selection: $fotoElegida, matching: .images) {
                        Text(L.t("Subir imagen", "Upload image")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.horizontal, Esp.pantalla)

                Button { mostrarArchivos = true } label: {
                    Text(L.t("Elegir un archivo…", "Choose a file…")).font(.footnote)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Paleta.enlace)

                Text(L.t("La firma se queda en este aparato: no se sincroniza ni sale en los documentos que se generen desde otro.",
                         "The signature stays on this device: it isn't synced and won't appear on documents generated elsewhere."))
                    .font(.caption).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Esp.panel)
                    .padding(.bottom, Esp.hueco)
            }
            .padding(.top, Esp.pantalla)
            .navigationTitle(firmante.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar", "Save")) { guardarDibujo() }
                        .disabled(vacio)
                }
            }
            .fileImporter(isPresented: $mostrarArchivos,
                          allowedContentTypes: [.image]) { resultado in
                if case .success(let url) = resultado { importar(url) }
            }
            .onChange(of: fotoElegida) { _, nuevo in
                guard let nuevo else { return }
                Task { await importar(nuevo) }
            }
        }
    }

    // MARK: - Guardar

    private func guardarDibujo() {
        let dibujo = lienzo.drawing
        guard !dibujo.strokes.isEmpty else { return }
        // Se renderiza SOLO el área dibujada y a escala 3: el lienzo entero
        // saldría casi vacío, y una firma a escala 1 se ve pixelada en un PDF,
        // que se imprime a bastante más resolución que la pantalla.
        let imagen = dibujo.image(from: dibujo.bounds, scale: 3)
        guardar(FirmasLocales.recortada(imagen))
    }

    private func importar(_ url: URL) {
        let concedido = url.startAccessingSecurityScopedResource()
        defer { if concedido { url.stopAccessingSecurityScopedResource() } }
        guard let datos = try? Data(contentsOf: url), let imagen = UIImage(data: datos) else {
            error = L.t("No se pudo leer esa imagen.", "That image couldn't be read.")
            return
        }
        guardar(FirmasLocales.sinFondo(imagen))
    }

    private func importar(_ item: PhotosPickerItem) async {
        guard let datos = try? await item.loadTransferable(type: Data.self),
              let imagen = UIImage(data: datos) else {
            error = L.t("No se pudo leer esa imagen.", "That image couldn't be read.")
            return
        }
        guardar(FirmasLocales.sinFondo(imagen))
    }

    private func guardar(_ imagen: UIImage) {
        do {
            try firmas.guardar(imagen, para: firmante)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// `PKCanvasView` para SwiftUI.
private struct LienzoFirma: UIViewRepresentable {
    let lienzo: PKCanvasView
    let alDibujar: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        // `.anyInput` y no el valor por omisión: con `.default`, en cuanto hay
        // un Apple Pencil emparejado el lienzo DEJA DE ACEPTAR EL DEDO. Quien
        // tiene Pencil en la oficina no siempre lo lleva encima, y la firma
        // dejaría de funcionar sin decir por qué.
        lienzo.drawingPolicy = .anyInput
        lienzo.tool = PKInkingTool(.pen, color: .label, width: 4)
        // Fondo transparente: el PNG que se guarda no debe traer el color del
        // recuadro pegado detrás del trazo.
        lienzo.backgroundColor = .clear
        lienzo.isOpaque = false
        lienzo.delegate = context.coordinator
        return lienzo
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador(alDibujar: alDibujar) }

    final class Coordinador: NSObject, PKCanvasViewDelegate {
        let alDibujar: () -> Void
        init(alDibujar: @escaping () -> Void) { self.alDibujar = alDibujar }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { alDibujar() }
    }
}
