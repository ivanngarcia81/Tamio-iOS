import SwiftUI

/// **El logo dentro del membrete de un documento**, con las dos disposiciones
/// que usan los papeles de Tamio.
///
/// Existe para que el logo entre en los seis membretes sin copiar seis veces la
/// misma decisión de tamaño y de qué hacer cuando no hay logo. Y lo que hace
/// cuando no lo hay es **nada**: ni un hueco reservado ni un marcador con las
/// iniciales. Un documento oficial de una iglesia que todavía no subió su logo
/// tiene que salir como salía antes —sin un rectángulo vacío donde debería ir
/// algo—, y las iniciales sobre verde son un recurso de pantalla, no de papel.
///
/// El alto va en puntos y el ancho lo pone la imagen: un logo apaisado y uno
/// cuadrado tienen que ocupar el mismo renglón, no la misma caja.
struct LogoMembrete: View {
    var alto: CGFloat = 52

    /// Una propiedad normal y no un `@State`, igual que `FirmasPDF` con las
    /// firmas. No es un detalle de estilo: **el PDF se dibuja con
    /// `ImageRenderer`, fuera de la jerarquía de vistas**, y ahí el `@State`
    /// no llega a instalarse — el logo salía en Ajustes y no en el papel, que
    /// es justo donde tenía que salir.
    var logo: LogoIglesia = .compartido

    var body: some View {
        if let imagen = logo.imagen {
            Image(uiImage: imagen)
                .resizable()
                .scaledToFit()
                // Altura fija y ancho libre: con `maxHeight` el `scaledToFit`
                // colapsa a cero cuando el contenedor propone cero, que es lo
                // que hace `ImageRenderer` al medir la página.
                .frame(height: alto)
        }
    }
}
