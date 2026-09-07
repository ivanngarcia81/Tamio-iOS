import Observation
import Supabase
import SwiftUI
import UIKit

/// **El logo de la iglesia: en Storage, cacheado en el aparato.**
///
/// Es el contrario deliberado de `FirmasLocales`, y conviene leer los dos
/// juntos. La firma NO se sincroniza porque una firma que viaja a todos los
/// aparatos es un sello que cualquiera puede estampar en cualquier documento.
/// El logo sí viaja, por el motivo opuesto: no autoriza nada, identifica a la
/// congregación, y un membrete que cambia según desde qué aparato se imprima no
/// es un membrete. Quien configura la iglesia en el iPad de la oficina espera
/// que la constancia salga igual desde el teléfono de la tesorera.
///
/// **La ruta es el identificador de versión.** En `iglesias.logo_path` viaja
/// `<church_id>/logo/<uuid>.png`, y el archivo local se llama igual que su
/// último segmento. Así "¿tengo yo este logo?" es "¿existe ese archivo?", sin
/// marcas de tiempo ni banderas que se puedan desincronizar. Cambiar el logo
/// estrena UUID, y por eso el aparato de al lado se entera.
///
/// **Va en el bucket `comprobantes`** y no en uno propio: sus tres políticas ya
/// aíslan por `church_id` mirando el primer segmento de la ruta, que es
/// exactamente el aislamiento que hace falta aquí. Crear un bucket `logos` sería
/// escribir esas mismas tres políticas otra vez para no ganar nada. El segundo
/// segmento, `logo/`, es lo que lo separa de los recibos ahí dentro.
///
/// **No entra en el respaldo**, y es la otra diferencia con las firmas: la
/// firma solo existe en el aparato, así que dejarla fuera del paquete deja
/// documentos sin firmar al restaurar. El logo está en el servidor y vuelve
/// solo con la siguiente sincronización.
@Observable
@MainActor
final class LogoIglesia {

    static let compartido = LogoIglesia()

    /// Cargado en memoria porque lo lee el membrete de CADA página de CADA PDF.
    private(set) var imagen: UIImage?

    /// Mientras sube o baja. La pantalla de Ajustes lo enseña: una imagen que
    /// tarda en aparecer sin decir nada parece que se perdió.
    private(set) var trabajando = false

    private let almacen = almacenLogo()

    private init() {
        if let url = Self.archivoLocal(), let datos = try? Data(contentsOf: url) {
            imagen = UIImage(data: datos)
        }
    }

    // MARK: - Carpeta

    private static var carpeta: URL? {
        let fm = FileManager.default
        guard let base = try? fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil, create: true) else { return nil }
        let dir = base.appendingPathComponent("logo", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// El único archivo que debería haber en la carpeta. Se busca en vez de
    /// componerse: al arrancar todavía no se ha leído la configuración, así que
    /// no se sabe qué ruta toca, pero lo que hay en disco es lo que hay.
    private static func archivoLocal() -> URL? {
        guard let dir = carpeta,
              let archivos = try? FileManager.default.contentsOfDirectory(
                  at: dir, includingPropertiesForKeys: nil) else { return nil }
        return archivos.first { $0.pathExtension == "png" }
    }

    private static func nombre(deRuta ruta: String) -> String {
        (ruta as NSString).lastPathComponent
    }

    // MARK: - Poner y quitar

    /// Sube la imagen y devuelve la ruta que hay que guardar en la
    /// configuración. **No la guarda**: quien llama es el dueño de ese campo, y
    /// escribirlo desde aquí daría dos sitios que lo tocan.
    ///
    /// Guarda en disco ANTES de subir. Si la subida falla —el avión, un túnel—
    /// la iglesia se queda con su logo puesto en este aparato y el error se
    /// enseña; al revés se vería un hueco sin explicación.
    func poner(_ original: UIImage) async throws -> String {
        trabajando = true
        defer { trabajando = false }

        let preparada = Self.preparada(original)
        guard let datos = preparada.pngData() else {
            throw Fallo(texto: L.t("No se pudo preparar la imagen.",
                                   "The image could not be prepared."))
        }
        let ruta = "\(churchIdActivo)/logo/\(UUID().uuidString).png"

        Self.limpiarCarpeta()
        if let dir = Self.carpeta {
            try? datos.write(to: dir.appendingPathComponent(Self.nombre(deRuta: ruta)),
                             options: .atomic)
        }
        imagen = preparada

        try await almacen.subir(datos, a: ruta)
        return ruta
    }

    /// Quita el logo de este aparato y del servidor. La ruta anterior se pasa
    /// para poder borrar el archivo: sin ella quedaría ocupando el bucket para
    /// siempre, que es como se llena un almacén de cosas que nadie reclama.
    func quitar(rutaAnterior: String) async {
        Self.limpiarCarpeta()
        imagen = nil
        if !rutaAnterior.isEmpty { try? await almacen.borrar(rutaAnterior) }
    }

    // MARK: - Ponerse al día

    /// Deja el aparato con el logo que dice la configuración. Se llama después
    /// de cada sincronización: es el momento en que puede haber cambiado desde
    /// otro aparato.
    ///
    /// Los tres casos, y ninguno sobra: sin ruta hay que BORRAR lo que hubiera
    /// —alguien quitó el logo y aquí seguiría saliendo—; con la misma ruta no
    /// se hace nada, que es lo normal y por eso va primero en coste; y con una
    /// ruta distinta se baja.
    func sincronizar(con ruta: String) async {
        let local = Self.archivoLocal()

        if ruta.isEmpty {
            if local != nil { Self.limpiarCarpeta(); imagen = nil }
            return
        }
        if local?.lastPathComponent == Self.nombre(deRuta: ruta), imagen != nil { return }

        trabajando = true
        defer { trabajando = false }
        guard let datos = try? await almacen.descargar(ruta),
              let bajada = UIImage(data: datos) else { return }

        Self.limpiarCarpeta()
        if let dir = Self.carpeta {
            try? datos.write(to: dir.appendingPathComponent(Self.nombre(deRuta: ruta)),
                             options: .atomic)
        }
        imagen = bajada
    }

    /// Se vacía la carpeta entera en vez de borrar un archivo concreto: si por
    /// lo que fuera quedaron dos, tener el de ayer y el de hoy conviviendo hace
    /// que `archivoLocal()` conteste al azar.
    private static func limpiarCarpeta() {
        guard let dir = carpeta,
              let archivos = try? FileManager.default.contentsOfDirectory(
                  at: dir, includingPropertiesForKeys: nil) else { return }
        for a in archivos { try? FileManager.default.removeItem(at: a) }
    }

    // MARK: - Preparar la imagen

    /// El lado mayor, en puntos. Un logo se imprime a unos 90 puntos de alto en
    /// el membrete; 1024 da margen de sobra para la pantalla Retina del iPad y
    /// para el PDF, y deja el archivo en unos pocos cientos de kB en vez de los
    /// varios MB que trae una foto del carrete.
    private static let ladoMaximo: CGFloat = 1024

    /// **PNG y no JPEG, igual que las firmas**: un logo recortado suele traer
    /// fondo transparente, y en JPEG la transparencia se rellena de blanco. Un
    /// rectángulo blanco encima del membrete se nota justo en el papel.
    static func preparada(_ imagen: UIImage) -> UIImage {
        let lado = max(imagen.size.width, imagen.size.height)
        guard lado > ladoMaximo, lado > 0 else { return imagen }
        let escala = ladoMaximo / lado
        let tamano = CGSize(width: imagen.size.width * escala,
                            height: imagen.size.height * escala)
        let formato = UIGraphicsImageRendererFormat.default()
        // La imagen ya está en píxeles del original: pedir la escala de la
        // pantalla la multiplicaría por tres en el iPad y desharía el
        // redimensionado que acabamos de calcular.
        formato.scale = 1
        formato.opaque = false
        return UIGraphicsImageRenderer(size: tamano, format: formato).image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: tamano))
        }
    }

    struct Fallo: LocalizedError {
        let texto: String
        var errorDescription: String? { texto }
    }
}

// MARK: - El almacén

/// Lo que el logo necesita de Storage y `ComprobantesStorage` no da: bajar los
/// bytes —el PDF se arma sin red— y borrar el anterior al reemplazarlo.
protocol LogoStorage: Sendable {
    func subir(_ datos: Data, a ruta: String) async throws
    func descargar(_ ruta: String) async throws -> Data
    func borrar(_ ruta: String) async throws
}

struct SupabaseLogoStorage: LogoStorage {
    private var bucket: String { SupabaseComprobantesStorage.bucket }

    func subir(_ datos: Data, a ruta: String) async throws {
        try await supabase.storage
            .from(bucket)
            .upload(ruta, data: datos, options: FileOptions(contentType: "image/png"))
    }

    func descargar(_ ruta: String) async throws -> Data {
        try await supabase.storage.from(bucket).download(path: ruta)
    }

    func borrar(_ ruta: String) async throws {
        _ = try await supabase.storage.from(bucket).remove(paths: [ruta])
    }
}

/// En modo revisión no hay sesión y Storage rechazaría la subida. El archivo se
/// guarda igual en el aparato, así que el logo se ve y la pantalla se puede
/// recorrer entera; lo único que no ocurre es el viaje al servidor.
struct MockLogoStorage: LogoStorage {
    func subir(_ datos: Data, a ruta: String) async throws {
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    func descargar(_ ruta: String) async throws -> Data {
        throw NSError(domain: "Tamio", code: 1, userInfo: [NSLocalizedDescriptionKey:
            L.t("En modo revisión no hay logo que bajar.", "No logo to download in review mode.")])
    }
    func borrar(_ ruta: String) async throws {}
}

func almacenLogo() -> LogoStorage {
    ModoRevision.sinLogin ? MockLogoStorage() : SupabaseLogoStorage()
}
