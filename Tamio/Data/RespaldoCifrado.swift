import CommonCrypto
import CryptoKit
import Foundation

/// **El respaldo, protegido con una contraseña.**
///
/// Es el agujero que `docs/CIFRADO-LOCAL.md` señalaba como el único real: de
/// todo lo que guarda la app, el `.zip` es lo único que SALE del aparato —a
/// Archivos, a iCloud, a un correo, a WhatsApp— y hasta hoy salía en claro con
/// la contabilidad entera dentro. Data Protection no lo cubre: en cuanto el
/// archivo abandona el recinto de la app, deja de protegerlo nadie.
///
/// **Va con casilla y no obligatorio**, decidido por Iván el 7 de septiembre de
/// 2026. Quien manda el respaldo por correo lo cifra; quien lo guarda en su Mac
/// lo deja como un `.zip` que se abre con doble clic. Obligarlo tendría un
/// precio real: un respaldo que solo abre Tamio, y quien pierda la contraseña
/// pierde el respaldo — que es justo el desenlace que este proyecto evita en el
/// candado biométrico, donde nadie se queda fuera de sus propios libros.
///
/// **El formato, para quien tenga que leerlo dentro de dos años:**
///
/// ```
/// "TAMIOBK1"  8 bytes   marca, para reconocerlo sin fiarse de la extensión
/// sal        16 bytes   distinta en cada respaldo
/// resto      n bytes    el .zip cifrado con AES-GCM (incluye su etiqueta)
/// ```
///
/// La clave sale de la contraseña con PBKDF2-SHA256 y 200.000 vueltas. No es
/// HKDF ni un hash a secas a propósito: una contraseña humana necesita que
/// derivarla CUESTE, o probarlas todas es cuestión de tarde. CryptoKit no
/// expone PBKDF2, así que lo pone CommonCrypto, que viene con el sistema.
enum RespaldoCifrado {

    static let marca = Data("TAMIOBK1".utf8)
    private static let bytesDeSal = 16
    private static let vueltas: UInt32 = 200_000

    enum Fallo: LocalizedError, Equatable {
        case contrasenaVacia
        case noSePudoCifrar
        case contrasenaIncorrecta

        var errorDescription: String? {
            switch self {
            case .contrasenaVacia:
                return L.t("Escribe una contraseña para proteger el respaldo.",
                           "Type a password to protect the backup.")
            case .noSePudoCifrar:
                return L.t("No se pudo proteger el respaldo.",
                           "The backup couldn't be protected.")
            case .contrasenaIncorrecta:
                return L.t("La contraseña no abre este respaldo.",
                           "That password doesn't open this backup.")
            }
        }
    }

    /// ¿Este archivo está cifrado? Se mira la marca del principio y no la
    /// extensión: el nombre lo puede cambiar cualquiera al guardarlo.
    static func estaCifrado(_ datos: Data) -> Bool {
        datos.count > marca.count && datos.prefix(marca.count) == marca
    }

    static func cifrar(_ zip: Data, con contrasena: String) throws -> Data {
        guard !contrasena.isEmpty else { throw Fallo.contrasenaVacia }
        var sal = Data(count: bytesDeSal)
        let ok = sal.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, bytesDeSal, $0.baseAddress!) }
        guard ok == errSecSuccess else { throw Fallo.noSePudoCifrar }

        let clave = try derivar(contrasena, sal: sal)
        guard let sellada = try? AES.GCM.seal(zip, using: clave).combined else {
            throw Fallo.noSePudoCifrar
        }
        return marca + sal + sellada
    }

    static func descifrar(_ paquete: Data, con contrasena: String) throws -> Data {
        guard estaCifrado(paquete) else { return paquete }
        let inicioSal = marca.count
        let inicioCuerpo = inicioSal + bytesDeSal
        guard paquete.count > inicioCuerpo else { throw Fallo.contrasenaIncorrecta }

        let sal = paquete.subdata(in: inicioSal..<inicioCuerpo)
        let cuerpo = paquete.subdata(in: inicioCuerpo..<paquete.count)
        let clave = try derivar(contrasena, sal: sal)
        // **Una contraseña equivocada llega aquí como un fallo de
        // autenticación**, no como bytes raros: AES-GCM comprueba la etiqueta
        // antes de devolver nada. Por eso no hace falta guardar ninguna prueba
        // de la contraseña en el archivo.
        guard let caja = try? AES.GCM.SealedBox(combined: cuerpo),
              let claro = try? AES.GCM.open(caja, using: clave) else {
            throw Fallo.contrasenaIncorrecta
        }
        return claro
    }

    /// PBKDF2-SHA256. La sal viaja con el archivo; las vueltas son fijas.
    private static func derivar(_ contrasena: String, sal: Data) throws -> SymmetricKey {
        let bytes = Array(contrasena.utf8)
        var salida = [UInt8](repeating: 0, count: 32)
        let estado = sal.withUnsafeBytes { salPtr -> Int32 in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                bytes.map { Int8(bitPattern: $0) }, bytes.count,
                salPtr.bindMemory(to: UInt8.self).baseAddress, sal.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                vueltas,
                &salida, salida.count)
        }
        guard estado == kCCSuccess else { throw Fallo.noSePudoCifrar }
        return SymmetricKey(data: Data(salida))
    }
}
