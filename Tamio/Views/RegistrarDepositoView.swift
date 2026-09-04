import SwiftUI
import PhotosUI
import UIKit

/// **Registrar el depósito: el momento en que el dinero llega al banco.**
///
/// Antes esto era un `confirmationDialog` de dos botones que solo cambiaba un
/// estado. No había dónde guardar el recibo, ni la fecha real en que se fue al
/// banco, ni la referencia de la ventanilla — y la tarjeta "Ficha del banco"
/// apuntaba el NOMBRE del archivo elegido y tiraba el archivo.
///
/// Depositar y tener el recibo son el mismo momento en la vida real, así que
/// son el mismo paso aquí: esta hoja crea la fila de `depositos_bancarios` con
/// su comprobante dentro.
struct RegistrarDepositoView: View {
    @Environment(\.dismiss) private var dismiss

    let corte: Corte
    let onRegistrar: (DepositoBancario) -> Void

    @State private var fecha = Date()
    @State private var periodo: String
    @State private var referencia = ""
    /// El nombre del archivo YA COPIADO dentro de la app. Se escribe en cuanto
    /// se elige la foto, no al pulsar Registrar: si la hoja se cierra sola o la
    /// app se cae, el recibo ya está a salvo.
    @State private var archivo: String?
    @State private var vistaPrevia: UIImage?
    @State private var error: String?

    @State private var mostrarArchivos = false
    @State private var mostrarCamara = false
    @State private var fotoElegida: PhotosPickerItem?

    init(corte: Corte, onRegistrar: @escaping (DepositoBancario) -> Void) {
        self.corte = corte
        self.onRegistrar = onRegistrar
        _periodo = State(initialValue: corte.registro.periodo)
    }

    /// Solo hay cámara donde hay cámara: en el simulador y en un Mac no la hay,
    /// y ofrecer un botón que no abre nada es peor que no ofrecerlo.
    private var hayCamara: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    filaResumen(L.t("Cuenta", "Account"), corte.registro.cuenta)
                    DatePicker(L.t("Fecha del depósito", "Deposit date"),
                               selection: $fecha, displayedComponents: .date)
                    Picker(L.t("Periodo", "Period"), selection: $periodo) {
                        ForEach(DepositosViewModel.periodosCercanos, id: \.self) {
                            Text(Fechas.periodoLegible($0)).tag($0)
                        }
                    }
                    filaResumen(L.t("Monto", "Amount"), Money.fmt(corte.montoTotal), fuerte: true)
                } header: {
                    Text(L.t("SE REGISTRA ASÍ", "RECORDED AS"))
                } footer: {
                    Text(L.t("El monto es la suma de los movimientos del corte; no se teclea.",
                             "The amount is the sum of the cut's entries; it isn't typed."))
                }

                Section {
                    TextField(L.t("Número de operación o folio", "Operation or slip number"),
                              text: $referencia)
                } header: {
                    Text(L.t("REFERENCIA DEL BANCO", "BANK REFERENCE"))
                } footer: {
                    Text(L.t("Opcional. Es lo que permite encontrar el movimiento en el estado de cuenta.",
                             "Optional. It's what lets you find the entry on the bank statement."))
                }

                seccionRecibo
            }
            .navigationTitle(L.t("Registrar depósito", "Record deposit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Registrar", "Record")) { registrar() }
                        .fontWeight(.semibold).tint(Paleta.brand)
                }
            }
            .fileImporter(isPresented: $mostrarArchivos,
                          allowedContentTypes: [.image, .pdf],
                          allowsMultipleSelection: false) { resultado in
                switch resultado {
                case .success(let urls):
                    if let url = urls.first { guardarArchivo(url) }
                case .failure(let e):
                    error = e.localizedDescription
                }
            }
            .fullScreenCover(isPresented: $mostrarCamara) {
                CamaraRecibo { imagen in guardarImagen(imagen) }
                    .ignoresSafeArea()
            }
            .onChange(of: fotoElegida) { _, nuevo in
                guard let nuevo else { return }
                Task {
                    if let datos = try? await nuevo.loadTransferable(type: Data.self),
                       let imagen = UIImage(data: datos) {
                        guardarImagen(imagen)
                    }
                    fotoElegida = nil
                }
            }
        }
        .hojaGrande()
    }

    // MARK: - Recibo

    private var seccionRecibo: some View {
        Section {
            if archivo != nil {
                HStack(spacing: 10) {
                    if let vistaPrevia {
                        Image(uiImage: vistaPrevia)
                            .resizable().scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Image(systemName: "doc.fill").foregroundStyle(Paleta.brand)
                    }
                    Text(L.t("Recibo guardado", "Receipt saved"))
                        .font(.subheadline)
                    Spacer()
                    Button(L.t("Quitar", "Remove"), role: .destructive) {
                        if let archivo { RecibosLocales.borrar(archivo) }
                        archivo = nil
                        vistaPrevia = nil
                    }
                    .font(.caption)
                }
            } else {
                if hayCamara {
                    Button { mostrarCamara = true } label: {
                        Label(L.t("Tomar foto del recibo", "Take a photo of the receipt"),
                              systemImage: "camera.fill")
                    }
                }
                PhotosPicker(selection: $fotoElegida, matching: .images) {
                    Label(L.t("Elegir del carrete", "Choose from the library"),
                          systemImage: "photo.on.rectangle")
                }
                Button { mostrarArchivos = true } label: {
                    Label(L.t("Buscar en Archivos", "Browse Files"), systemImage: "folder")
                }
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(Paleta.negativo)
            }
        } header: {
            Text(L.t("RECIBO DEL BANCO", "BANK RECEIPT"))
        } footer: {
            Text(L.t("Se guarda en el teléfono al instante y sube cuando haya señal. La foto se hace en el banco, que es donde peor cobertura hay, y el papel no se puede volver a pedir.",
                     "It's saved on the phone right away and uploads when there's signal. The photo is taken at the bank, where coverage is worst, and the paper can't be asked for twice."))
        }
    }

    private func filaResumen(_ etiqueta: String, _ valor: String,
                             fuerte: Bool = false) -> some View {
        HStack {
            Text(etiqueta).foregroundStyle(.secondary)
            Spacer()
            Text(valor).fontWeight(fuerte ? .bold : .regular).monospacedDigit()
        }
    }

    // MARK: - Guardar

    private func guardarArchivo(_ url: URL) {
        do {
            let nombre = try RecibosLocales.guardar(desde: url)
            archivo = nombre
            if let datos = try? Data(contentsOf: RecibosLocales.url(nombre) ?? url) {
                vistaPrevia = UIImage(data: datos)
            }
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func guardarImagen(_ imagen: UIImage) {
        do {
            archivo = try RecibosLocales.guardar(imagen: imagen)
            vistaPrevia = imagen
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func registrar() {
        onRegistrar(DepositoBancario(
            id: UUID().uuidString,
            fecha: DepositosViewModel.textoFecha(fecha),
            periodo: periodo,
            monto: corte.montoTotal,
            cuenta: corte.registro.cuenta,
            referencia: referencia.trimmingCharacters(in: .whitespacesAndNewlines),
            archivoLocal: archivo))
        dismiss()
    }
}

/// La cámara, envuelta para SwiftUI. `UIImagePickerController` y no
/// `.camera` de PhotosPicker porque PhotosPicker solo lee del carrete: para
/// fotografiar el recibo en la ventanilla hace falta abrir la cámara.
struct CamaraRecibo: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onFoto: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador(self) }

    final class Coordinador: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        private let padre: CamaraRecibo
        init(_ padre: CamaraRecibo) { self.padre = padre }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info:
                                   [UIImagePickerController.InfoKey: Any]) {
            if let imagen = info[.originalImage] as? UIImage { padre.onFoto(imagen) }
            padre.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            padre.dismiss()
        }
    }
}
