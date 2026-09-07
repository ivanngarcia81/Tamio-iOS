import GRDB
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
        // `png` o `jpg`: el formato lo decide la imagen (ver `codificada`).
        return archivos.first { ["png", "jpg"].contains($0.pathExtension) }
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
    func poner(_ original: UIImage, reemplazando anterior: String = "") async throws -> String {
        trabajando = true
        defer { trabajando = false }

        let preparada = Self.preparada(original)
        guard let (datos, extension_, tipo) = Self.codificada(preparada) else {
            throw Fallo(texto: L.t("No se pudo preparar la imagen.",
                                   "The image could not be prepared."))
        }
        let ruta = "\(churchIdActivo)/logo/\(UUID().uuidString).\(extension_)"

        Self.limpiarCarpeta()
        if let dir = Self.carpeta {
            try? datos.write(to: dir.appendingPathComponent(Self.nombre(deRuta: ruta)),
                             options: .atomic)
        }
        imagen = preparada

        try await almacen.subir(datos, a: tipo, ruta)

        // **Se barre la carpeta entera, no solo el anterior.**
        //
        // Empezó siendo "borra el que sustituyes", y con eso bastaba para no
        // acumular de aquí en adelante. Pero en el aparato de Iván ya había
        // SEIS archivos de 1,6 MB de intentos anteriores —casi diez megas—, y
        // un borrado que solo mira la ruta que conoce no los habría tocado
        // nunca. Barrer la carpeta los alcanza a todos.
        //
        // Es seguro porque ahí dentro solo hay logos de ESTA iglesia: el primer
        // segmento de la ruta es el `church_id` y es lo que miran las políticas
        // del bucket. Y va DESPUÉS de que el nuevo esté arriba; si falla no se
        // dice nada, porque es basura y no el dato de nadie.
        await limpiarSobrantes(salvo: ruta, anterior: anterior)
        return ruta
    }

    private func limpiarSobrantes(salvo vigente: String, anterior: String) async {
        let carpeta = "\(churchIdActivo)/logo/"
        guard let nombres = try? await almacen.listar() else {
            // Sin listado —sin red, o el bucket no deja listar— queda al menos
            // el de siempre: el que se acaba de sustituir.
            if !anterior.isEmpty, anterior != vigente { try? await almacen.borrar(anterior) }
            return
        }
        for nombre in nombres where carpeta + nombre != vigente {
            try? await almacen.borrar(carpeta + nombre)
        }
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

    /// Borra el archivo del aparato sin tocar el servidor. Lo usa el reinicio
    /// de fábrica: deja el teléfono limpio, y el logo de la iglesia sigue donde
    /// estaba para quien vuelva a entrar.
    func quitarLocal() {
        Self.limpiarCarpeta()
        imagen = nil
    }

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
            // **Una ruta vacía no siempre significa "no hay logo".** También
            // significa "todavía no se ha guardado la que acabo de poner", y
            // esa ventana existe de verdad: el 7 de septiembre de 2026, en el
            // aparato, el logo aparecía y se borraba solo a los pocos segundos.
            // Pasaba esto — la configuración se relee tras sincronizar, la
            // ruta nueva aún no estaba en la base, y este `if` borraba el
            // archivo recién puesto.
            //
            // Se distingue mirando la cola: si la iglesia tiene algo pendiente
            // de subir, lo que hay en la base local todavía no es la última
            // palabra y no se toca nada. Es la misma guarda que usa
            // `bajarIglesia` antes de pisar el espejo local, y por lo mismo.
            if local != nil, await Self.sinCambiosPendientes() {
                Self.limpiarCarpeta()
                imagen = nil
            }
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

    /// ¿La iglesia tiene algo esperando a subir? Si lo tiene, lo que hay en la
    /// base local todavía puede estar a medias y no se puede concluir nada de
    /// una ruta vacía.
    private static func sinCambiosPendientes() async -> Bool {
        let base = BaseLocal.compartida
        let pendientes = (try? await base.cola.read { db in
            try OperacionPendiente.filter(Column("entidad") == "iglesia").fetchCount(db)
        }) ?? 0
        return pendientes == 0
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

    /// **El formato lo decide la imagen, no una regla fija.**
    ///
    /// Aquí había un `pngData()` a secas, con este motivo escrito: un logo
    /// recortado trae fondo transparente y en JPEG la transparencia se rellena
    /// de blanco, que encima del membrete se nota. Es cierto — para un logo
    /// recortado. Para una FOTO del carrete, que es lo que se elige la primera
    /// vez, el PNG no comprime nada: en el aparato salieron **1,6 MB por
    /// logo**, y ese archivo se lo descarga cada teléfono de la iglesia.
    ///
    /// Así que se mira si la imagen tiene canal alfa: con transparencia, PNG;
    /// sin ella, JPEG al 90 %, que para la misma imagen baja de megabytes a
    /// unos cientos de kB sin diferencia visible en el papel.
    static func codificada(_ imagen: UIImage) -> (Data, String, String)? {
        if tieneTransparencia(imagen), let png = imagen.pngData() {
            return (png, "png", "image/png")
        }
        if let jpeg = imagen.jpegData(compressionQuality: 0.9) {
            return (jpeg, "jpg", "image/jpeg")
        }
        return imagen.pngData().map { ($0, "png", "image/png") }
    }

    /// Alfa de verdad, no "el formato admite alfa": una foto del carrete puede
    /// venir en un contenedor con canal alfa y estar opaca entera.
    private static func tieneTransparencia(_ imagen: UIImage) -> Bool {
        guard let cg = imagen.cgImage else { return true }
        switch cg.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        // Se miran los píxeles: basta con encontrar uno que no sea opaco.
        let ancho = cg.width, alto = cg.height
        guard ancho > 0, alto > 0 else { return false }
        // **El lienzo arranca en CERO**, no en 255. Se dibuja con mezcla normal
        // sobre lo que haya: partiendo de opaco, un píxel transparente deja el
        // destino intacto y la transparencia no se ve por ninguna parte —así
        // pasó la primera vez, y un logo recortado se habría guardado en JPEG
        // con el fondo relleno de blanco—. Partiendo de cero, cada píxel acaba
        // valiendo su propio alfa. Es lo que ya hacía `FirmasLocales`.
        var alfa = [UInt8](repeating: 0, count: ancho * alto)
        guard let ctx = CGContext(data: &alfa, width: ancho, height: alto,
                                  bitsPerComponent: 8, bytesPerRow: ancho,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return true }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: ancho, height: alto))
        return alfa.contains { $0 < 250 }
    }

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
    /// El tipo va aparte porque ya no siempre es PNG: el bucket rechaza la
    /// subida si el `contentType` no coincide con lo que se manda.
    func subir(_ datos: Data, a tipo: String, _ ruta: String) async throws
    func descargar(_ ruta: String) async throws -> Data
    func borrar(_ ruta: String) async throws
    /// Los nombres de archivo que hay en la carpeta de logos de esta iglesia.
    func listar() async throws -> [String]
}

struct SupabaseLogoStorage: LogoStorage {
    private var bucket: String { SupabaseComprobantesStorage.bucket }

    func subir(_ datos: Data, a tipo: String, _ ruta: String) async throws {
        try await supabase.storage
            .from(bucket)
            .upload(ruta, data: datos, options: FileOptions(contentType: tipo))
    }

    func descargar(_ ruta: String) async throws -> Data {
        try await supabase.storage.from(bucket).download(path: ruta)
    }

    func borrar(_ ruta: String) async throws {
        _ = try await supabase.storage.from(bucket).remove(paths: [ruta])
    }

    func listar() async throws -> [String] {
        try await supabase.storage
            .from(bucket)
            .list(path: "\(churchIdActivo)/logo")
            .map(\.name)
    }
}

/// En modo revisión no hay sesión y Storage rechazaría la subida. El archivo se
/// guarda igual en el aparato, así que el logo se ve y la pantalla se puede
/// recorrer entera; lo único que no ocurre es el viaje al servidor.
struct MockLogoStorage: LogoStorage {
    func subir(_ datos: Data, a tipo: String, _ ruta: String) async throws {
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    func descargar(_ ruta: String) async throws -> Data {
        throw NSError(domain: "Tamio", code: 1, userInfo: [NSLocalizedDescriptionKey:
            L.t("En modo revisión no hay logo que bajar.", "No logo to download in review mode.")])
    }
    func borrar(_ ruta: String) async throws {}
    func listar() async throws -> [String] { [] }
}

func almacenLogo() -> LogoStorage {
    ModoRevision.sinLogin ? MockLogoStorage() : SupabaseLogoStorage()
}
