import Foundation
import Supabase

/// Guarda los comprobantes de los movimientos (foto del sobre, PDF de la
/// transferencia, imagen del cheque) y los vuelve a localizar para verlos.
protocol ComprobantesStorage {
    /// Sube el archivo y devuelve la ruta dentro del bucket, que es lo que se
    /// guarda en `transactions.comprobante_path`.
    func subir(_ url: URL) async throws -> String
    /// URL temporal para mostrar un comprobante ya subido.
    func urlFirmada(_ ruta: String) async throws -> URL
}

struct SupabaseComprobantesStorage: ComprobantesStorage {
    static let bucket = "comprobantes"
    /// Vida de la URL firmada: suficiente para abrir el documento, no tanto
    /// como para que el enlace siga sirviendo si se comparte por ahí.
    private static let vigenciaSegundos = 60 * 10

    func subir(_ url: URL) async throws -> String {
        // El fileImporter devuelve una URL fuera del sandbox de la app; sin
        // pedir acceso explícito, la lectura falla.
        let concedido = url.startAccessingSecurityScopedResource()
        defer { if concedido { url.stopAccessingSecurityScopedResource() } }

        let datos = try Data(contentsOf: url)
        let extension_ = url.pathExtension.isEmpty ? "dat" : url.pathExtension.lowercased()
        // El primer segmento es el church_id: es lo que miran las políticas del
        // bucket para aislar una iglesia de otra. El nombre original no se
        // reutiliza (dos "IMG_0001.jpg" se pisarían, y el nombre de un archivo
        // ajeno no es de fiar como ruta).
        let ruta = "\(churchIdActivo)/\(UUID().uuidString).\(extension_)"

        try await supabase.storage
            .from(Self.bucket)
            .upload(ruta, data: datos,
                    options: FileOptions(contentType: Self.tipoMime(extension_)))
        return ruta
    }

    func urlFirmada(_ ruta: String) async throws -> URL {
        try await supabase.storage
            .from(Self.bucket)
            .createSignedURL(path: ruta, expiresIn: Self.vigenciaSegundos)
    }

    /// El bucket solo acepta estos tipos; si no se manda el correcto, rechaza
    /// la subida aunque el archivo esté bien.
    private static func tipoMime(_ extension_: String) -> String {
        switch extension_ {
        case "jpg", "jpeg": return "image/jpeg"
        case "png":         return "image/png"
        case "heic":        return "image/heic"
        case "heif":        return "image/heif"
        case "webp":        return "image/webp"
        case "pdf":         return "application/pdf"
        default:            return "application/octet-stream"
        }
    }
}

/// En modo revisión no hay sesión, así que Storage rechazaría la subida. Se
/// simula para poder recorrer la hoja sin que parezca rota.
struct MockComprobantesStorage: ComprobantesStorage {
    func subir(_ url: URL) async throws -> String {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return "revision/\(url.lastPathComponent)"
    }

    /// En modo revisión no hay bucket que firmar. Antes devolvía una URL a
    /// `example.invalid`, así que "Ver comprobante" abría Safari en una página
    /// muerta y parecía un fallo de la app.
    func urlFirmada(_ ruta: String) async throws -> URL {
        throw NSError(domain: "Tamio", code: 1, userInfo: [NSLocalizedDescriptionKey:
            L.t("En modo revisión no hay comprobantes que abrir.",
                "No receipts to open in review mode.")])
    }
}

func almacenComprobantes() -> ComprobantesStorage {
    ModoRevision.sinLogin ? MockComprobantesStorage() : SupabaseComprobantesStorage()
}
