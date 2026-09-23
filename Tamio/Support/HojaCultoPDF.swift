import SwiftUI

/// **La hoja de culto: el papel de UN culto.** Es para un culto lo que el acta
/// es para una reunión: quién dirigió y predicó, el mensaje, el orden, quién
/// sirvió en cada puesto, cuánta gente vino y quién la visitó.
///
/// La forma es la del diseño («Hoja de Culto Pagina»), en puntos reales: carta
/// de 612 × 792 con 48 de margen. El encargo está en
/// `docs/ENCARGO-HOJA-DE-CULTO.md`.
///
/// Vive en `Support` y no en `Views` porque la imprimen los dos targets: el Mac
/// no compila `Views`, y por eso no tenía cómo sacar el acta (CONTEXTO §0.-23).
/// Por lo mismo, aquí no entra ni UIKit ni AppKit.
///
/// **Compone sus páginas en vez de dejar que `PDFExport` corte una tira.** El
/// diseño repite una cabecera corta en la página 2, pone «Página N de M» en el
/// pie y lleva la línea «Revisado por» solo al final, y nada de eso sale de
/// cortar una vista larga cada 792 puntos: el corte parte una fila del orden
/// por la mitad y no sabe qué página es la última. Así que cada página se arma
/// entera, con 792 de alto EXACTOS, y se apilan sin espacio entre ellas.
/// `PDFExport.render` corta de 792 en 792, así que cada corte cae justo en la
/// junta entre dos páginas y no hace falta tocarlo.
struct HojaCultoPDF: View {
    let servicio: Servicio
    var iglesia: ConfiguracionIglesia = ConfiguracionIglesiaViewModel.compartido.config
    /// El `mono` del diseño: el total en negro en vez de en verde. Todo lo
    /// demás ya es blanco y negro, así que la hoja se lee igual impresa sin
    /// color. Nadie lo pide aún; está para quien imprima en una láser.
    var monocromo = false

    /// Lo que va en cada página, ya repartido. Se calcula una vez al crear la
    /// hoja porque repartir obliga a medir, y medir es dibujar fuera de
    /// pantalla: hacerlo en cada `body` sería repetirlo a cada repintado.
    private let paginas: [[Elemento]]

    init(servicio: Servicio,
         iglesia: ConfiguracionIglesia = ConfiguracionIglesiaViewModel.compartido.config,
         monocromo: Bool = false) {
        self.servicio = servicio
        self.iglesia = iglesia
        self.monocromo = monocromo
        self.paginas = PiezasCulto(s: servicio, iglesia: iglesia, monocromo: monocromo).repartir()
    }

    /// Cuántas páginas salen. El Mac las enseña sueltas en su vista previa.
    var numeroDePaginas: Int { paginas.count }

    /// El nombre del archivo: la fecha ordena bien en una carpeta y no cambia
    /// con el idioma, igual que el folio del acta.
    static func nombreArchivo(_ s: Servicio) -> String {
        s.fecha.isEmpty ? "Hoja-de-culto" : "Hoja-de-culto-\(s.fecha)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<paginas.count, id: \.self) { i in pagina(i) }
        }
        .frame(width: PDFExport.anchoCarta)
    }

    /// Una página suelta, a tamaño real.
    func pagina(_ i: Int) -> some View {
        let piezas = PiezasCulto(s: servicio, iglesia: iglesia, monocromo: monocromo)
        let ultima = i == paginas.count - 1
        // Una sola página no se numera: «Página 1 de 1» no dice nada, y el
        // diseño de la mínima no la lleva.
        let numero = paginas.count > 1
            ? L.t("Página \(i + 1) de \(paginas.count)", "Page \(i + 1) of \(paginas.count)")
            : nil
        return VStack(alignment: .leading, spacing: 0) {
            if i == 0 { piezas.cabeceraPrimera } else { piezas.cabeceraCorta }
            ForEach(0..<paginas[i].count, id: \.self) { j in
                paginas[i][j].vista.padding(.top, paginas[i][j].margen)
            }
            Spacer(minLength: HC.aireAntesDelPie)
            if ultima { piezas.firma }
            piezas.pie(numero: numero)
        }
        .padding(HC.margen)
        // **El alto exacto de la página, pase lo que pase.** Si una página
        // midiera 792,4 por un redondeo, `PDFExport` cortaría la siguiente a
        // media línea. `clipped` es la red: lo repartido ya cabe, y lo que no
        // (un párrafo más largo que una hoja entera) se corta en su página en
        // vez de desplazar a todas las de detrás.
        .frame(width: PDFExport.anchoCarta, height: PDFExport.altoCarta, alignment: .top)
        .background(Color.white)
        .clipped()
        // Papel: negro sobre blanco aunque el aparato esté en modo oscuro.
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Medidas y colores del diseño

/// Lo que el diseño escribe en puntos. Todo con `.system(size:)` y no con
/// estilos (`.caption`…) a propósito: en el Mac `.caption2` mide 10 y en el
/// iPhone 11, y una hoja que se reparte midiendo tiene que medir igual en los
/// dos, o el mismo culto saldría con otras páginas según quién lo imprima.
private enum HC {
    static let margen: CGFloat = 48
    /// El ancho útil: la página menos sus dos márgenes (612 − 96).
    static let util: CGFloat = PDFExport.anchoCarta - 2 * margen
    static let altoUtil: CGFloat = PDFExport.altoCarta - 2 * margen
    /// El `min-height: 16px` del hueco flexible que empuja el pie abajo.
    static let aireAntesDelPie: CGFloat = 16

    /// El gris secundario del diseño, rgba(60,60,67,.6). Fijo y no
    /// `.secondary`, que en modo oscuro se aclara y en el papel se perdería.
    static let tinta = Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255)
    static let gris = tinta.opacity(0.6)
    static let raya = tinta.opacity(0.29)
    static let rayaFina = tinta.opacity(0.18)
    static let rayaFirma = tinta.opacity(0.5)
    /// #157A4B. El diseño lo reserva para el total; nada más lleva color.
    static let verde = Color(red: 0x15 / 255, green: 0x7A / 255, blue: 0x4B / 255)

    /// Las columnas del diseño son fracciones (`1.3fr 1fr 84px`), y SwiftUI no
    /// reparte en fracciones: se calculan sobre el ancho útil, que es fijo.
    static let ordenHora: CGFloat = 40
    static let ordenQuien: CGFloat = 150
    static let visitaPrimera: CGFloat = 84
    static var visitaNombre: CGFloat { (util - visitaPrimera - 16) * 1.3 / 2.3 }
    static var visitaPor: CGFloat { (util - visitaPrimera - 16) * 1.0 / 2.3 }
    static var columnaPuestos: CGFloat { (util - 28) * 1.15 / 2.15 }
}

/// Un rótulo de bloque: versalitas de 10 pt en gris, como «MENSAJE».
private struct Rotulo: View {
    let texto: String
    var body: some View {
        Text(texto.uppercased())
            .font(.system(size: 10, weight: .bold))
            .kerning(0.6)
            .foregroundStyle(HC.gris)
    }
}

private struct Raya: View {
    var color = HC.raya
    var grosor: CGFloat = 0.75
    var body: some View { Rectangle().fill(color).frame(height: grosor) }
}

// MARK: - El reparto

/// Lo que se pinta en una página, con el aire que lleva encima.
private struct Elemento {
    let vista: AnyView
    let margen: CGFloat
}

/// Un trozo que no se parte entre páginas: un bloque entero, un párrafo de un
/// texto largo o una fila de una tabla.
private struct Unidad {
    let vista: AnyView
    let alto: CGFloat
    /// El aire de encima cuando NO abre la página. El primero de una página
    /// arranca pegado a la cabecera, que ya trae el suyo.
    let margen: CGFloat
    /// Las filas llevan la tabla a la que pertenecen: su cabecera se repite en
    /// cada página donde la tabla siga. Una tabla que continúa sin decir qué
    /// columnas son no se lee.
    var tabla: String? = nil
    /// El bloque del que es un trozo, si se parte: la tabla, o el texto largo
    /// cuyos párrafos van por separado. Con él se evita dejar un trozo suelto
    /// al pie o en lo alto de una página (ver `cuantasBajan`).
    var grupo: String? = nil
}

private struct CabeceraTabla {
    let vista: AnyView
    let alto: CGFloat
    let margen: CGFloat
}

/// Las piezas de la hoja a partir del culto y de la iglesia. En el actor
/// principal porque mide con `ImageRenderer` y lee el logo compartido.
@MainActor
private struct PiezasCulto {
    let s: Servicio
    let iglesia: ConfiguracionIglesia
    let monocromo: Bool

    // MARK: Repartir

    /// **Llena las páginas de arriba abajo con lo que quepa.** Los bloques no
    /// se parten; las tablas sí, por filas; los textos largos, por párrafos.
    func repartir() -> [[Elemento]] {
        let (unidades, cabeceras) = self.unidades()
        let altoPie = medir(pie(numero: L.t("Página 9 de 9", "Page 9 of 9")))
        let altoFirma = medir(firma)
        let altoPrimera = medir(cabeceraPrimera)
        let altoCorta = medir(cabeceraCorta)

        func disponible(_ pagina: Int) -> CGFloat {
            HC.altoUtil - (pagina == 0 ? altoPrimera : altoCorta) - altoPie - HC.aireAntesDelPie
        }
        // Lo que cuesta poner `u` detrás de `previa` en la misma página. Tiene
        // que coincidir con `componer`, que es lo que luego se pinta.
        func coste(_ u: Unidad, tras previa: Unidad?) -> CGFloat {
            if let t = u.tabla {
                if previa?.tabla == t { return u.alto }
                let c = cabeceras[t]
                return (previa == nil ? 0 : (c?.margen ?? 0)) + (c?.alto ?? 0) + u.alto
            }
            return (previa == nil ? 0 : u.margen) + u.alto
        }

        // Lo que ocupa una página ya llena, con los mismos costes.
        func altoDe(_ pagina: [Unidad]) -> CGFloat {
            var total: CGFloat = 0
            var previa: Unidad?
            for u in pagina { total += coste(u, tras: previa); previa = u }
            return total
        }
        // Cuántos trozos quedan del grupo de `unidades[i]` contando ese.
        func restantes(desde i: Int) -> Int {
            guard let g = unidades[i].grupo else { return 1 }
            var n = 0
            for u in unidades[i...] { if u.grupo == g { n += 1 } else { break } }
            return n
        }

        // Las filas de una tabla cuentan siempre. De un texto, solo el párrafo
        // de UNA línea (12 pt con su interlineado mide unos 18): un párrafo
        // largo abriendo página es tipografía normal y no hay que arrastrarle
        // nada.
        func grupoSuelto(_ u: Unidad) -> String? {
            u.tabla != nil || u.alto < 20 ? u.grupo : nil
        }

        var paginas: [[Unidad]] = [[]]
        var usado: CGFloat = 0
        for (i, u) in unidades.enumerated() {
            let c = coste(u, tras: paginas[paginas.count - 1].last)
            // Una página vacía se queda la unidad aunque no quepa: es más alta
            // que una hoja entera y no cabría en ninguna. Sin esto el bucle
            // abriría páginas en blanco para siempre.
            if usado + c > disponible(paginas.count - 1), !paginas[paginas.count - 1].isEmpty {
                // Con la unidad bajan las que haga falta para que ninguna de
                // las dos páginas se quede con una fila suelta.
                var n = cuantasBajan(paginas[paginas.count - 1], grupo: grupoSuelto(u),
                                     restantes: restantes(desde: i), esTabla: u.tabla != nil)
                // Si lo que baja junto ya no cabe en la página nueva, se parte
                // como salga: una fila suelta es fea, pero un corte que pierde
                // texto es peor.
                if altoDe(Array(paginas[paginas.count - 1].suffix(n)) + [u]) > disponible(paginas.count) {
                    n = 0
                }
                let bajan = Array(paginas[paginas.count - 1].suffix(n))
                paginas[paginas.count - 1].removeLast(n)
                paginas.append(bajan + [u])
                usado = altoDe(paginas[paginas.count - 1])
            } else {
                paginas[paginas.count - 1].append(u)
                usado += c
            }
        }

        // **«Revisado por» va en la última página, y tiene que caber.** Si no
        // cabe, lo último baja a una página nueva: la firma no se queda sola
        // en una hoja en blanco más que si la última página es un único
        // bloque que la llena entera.
        let ultima = paginas.count - 1
        if usado + altoFirma > disponible(ultima) {
            if paginas[ultima].count > 1 {
                let u = paginas[ultima].removeLast()
                // Lo que baja es lo ÚLTIMO del grupo: la misma regla que al
                // partir, o la firma se llevaría una fila sola a la hoja nueva.
                var n = cuantasBajan(paginas[ultima], grupo: grupoSuelto(u),
                                     restantes: 1, esTabla: u.tabla != nil)
                if altoDe(Array(paginas[ultima].suffix(n)) + [u]) + altoFirma > disponible(ultima + 1) {
                    n = 0
                }
                let bajan = Array(paginas[ultima].suffix(n))
                paginas[ultima].removeLast(n)
                paginas.append(bajan + [u])
            } else {
                paginas.append([])
            }
        }

        return paginas.map { componer($0, cabeceras) }
    }

    /// **Al menos dos filas de una tabla en cada página donde esté.** Una sola
    /// fila bajo su cabecera repetida, o una sola al pie antes del corte, se
    /// lee como un error de imprenta: con 12 puntos de orden, la página 2
    /// llevaba el último sola.
    ///
    /// Se abre página antes de `u`. `pagina` es la que se cierra y `restantes`
    /// lo que queda del grupo de `u`, contándolo. Devuelve cuántas unidades del
    /// final de `pagina` tienen que bajar con él:
    /// - si a la página nueva le llegaría menos de dos, baja la que falte;
    /// - si en la que se cierra quedaría una fila sola (o nada, en un texto),
    ///   baja la tabla entera.
    ///
    /// En un texto partido por párrafos el mínimo de arriba es uno: el primer
    /// trozo ya lleva el rótulo y su párrafo, y eso sí se sostiene solo.
    ///
    /// Nunca vacía la página que se cierra: si el grupo la ocupa entera, se
    /// queda con lo que pueda y el resto baja.
    private func cuantasBajan(_ pagina: [Unidad], grupo: String?, restantes: Int,
                              esTabla: Bool) -> Int {
        guard let g = grupo else { return 0 }
        var racha = 0
        for x in pagina.reversed() { if x.grupo == g { racha += 1 } else { break } }
        guard racha > 0 else { return 0 }
        let minimoArriba = esTabla ? 2 : 1
        var bajan = min(max(0, 2 - restantes), racha)
        if racha - bajan < minimoArriba { bajan = racha }
        if bajan >= pagina.count {
            bajan = max(0, min(max(0, 2 - restantes), racha - minimoArriba))
        }
        return bajan
    }

    private func componer(_ unidades: [Unidad], _ cabeceras: [String: CabeceraTabla]) -> [Elemento] {
        var elementos: [Elemento] = []
        var previa: Unidad?
        for u in unidades {
            if let t = u.tabla {
                if previa?.tabla != t, let c = cabeceras[t] {
                    elementos.append(Elemento(vista: c.vista, margen: previa == nil ? 0 : c.margen))
                }
                elementos.append(Elemento(vista: u.vista, margen: 0))
            } else {
                elementos.append(Elemento(vista: u.vista, margen: previa == nil ? 0 : u.margen))
            }
            previa = u
        }
        return elementos
    }

    /// **El alto con el ancho útil ya fijado.** `ImageRenderer` es el mismo
    /// motor que luego saca el PDF, así que lo que se mide aquí es lo que se
    /// imprime. Con el ancho fijo (612 − 96) da lo mismo en el iPhone que en
    /// el Mac.
    private func medir(_ vista: some View) -> CGFloat {
        let r = ImageRenderer(content: vista
            .frame(width: HC.util, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, .light))
        r.proposedSize = .init(width: HC.util, height: nil)
        var alto: CGFloat = 0
        // Solo se lee el tamaño; no se dibuja nada.
        r.render { tam, _ in alto = tam.height }
        return ceil(alto)
    }

    // MARK: Los bloques, en el orden del diseño

    private func unidades() -> ([Unidad], [String: CabeceraTabla]) {
        var u: [Unidad] = []
        var cab: [String: CabeceraTabla] = [:]

        func agregar(_ v: some View, margen: CGFloat, tabla: String? = nil, grupo: String? = nil) {
            u.append(Unidad(vista: AnyView(v), alto: medir(v), margen: margen, tabla: tabla,
                            grupo: grupo ?? tabla))
        }

        // Mensaje. El rótulo viaja con el primer párrafo: un título al pie de
        // una página con el texto en la siguiente se lee como un bloque vacío.
        let resumen = parrafos(s.resumenMensaje)
        if hay(s.tituloMensaje) || hay(s.textoBiblico) || !resumen.isEmpty {
            agregar(bloqueMensaje(primerParrafo: resumen.first), margen: 14, grupo: "mensaje")
            for p in resumen.dropFirst() { agregar(parrafo(p), margen: 6, grupo: "mensaje") }
        }

        if hay(s.temaEscuela) || hay(s.maestroEscuela) {
            agregar(bloqueEscuela, margen: 14)
        }

        let orden = s.orden
            .sorted { $0.posicion < $1.posicion }
            .filter { hay($0.hora) || hay($0.titulo) || hay($0.encargado) }
        if !orden.isEmpty {
            let cabecera = Rotulo(texto: L.t("Orden del culto", "Order of service"))
                .padding(.bottom, 3)
            cab["orden"] = CabeceraTabla(vista: AnyView(cabecera), alto: medir(cabecera), margen: 14)
            for p in orden { agregar(filaOrden(p), margen: 0, tabla: "orden") }
        }

        if !s.puestos.isEmpty || !participaciones.isEmpty {
            agregar(bloquePuestos, margen: 20)
        }

        let visitantes = s.visitantes.filter { hay($0.nombre) }
        if !visitantes.isEmpty {
            let cabecera = cabeceraVisitantes(visitantes)
            cab["visitantes"] = CabeceraTabla(vista: AnyView(cabecera), alto: medir(cabecera), margen: 20)
            for v in visitantes { agregar(filaVisitante(v), margen: 0, tabla: "visitantes") }
        }

        let eventos = parrafos(s.eventos)
        if !eventos.isEmpty {
            agregar(VStack(alignment: .leading, spacing: 3) {
                Rotulo(texto: L.t("Eventos", "Events"))
                parrafo(eventos[0])
            }, margen: 20, grupo: "eventos")
            for p in eventos.dropFirst() { agregar(parrafo(p), margen: 6, grupo: "eventos") }
        }

        return (u, cab)
    }

    // MARK: Cabeceras de página

    private var hayLogo: Bool { LogoIglesia.compartido.imagen != nil }

    private var lineaDireccion: String {
        unir([iglesia.direccion, iglesia.ubicacionLegible])
    }

    private var lineaContacto: String {
        unir([iglesia.telefono, iglesia.correo])
    }

    /// Página 1: el membrete de la iglesia y el encabezado del culto.
    var cabeceraPrimera: some View {
        VStack(alignment: .leading, spacing: 0) {
            // **Sin nada en Ajustes, sin membrete** —ni hueco ni raya—: el
            // encabezado del culto sube y la hoja sigue viéndose terminada.
            if hayLogo || hay(iglesia.nombre) || !lineaDireccion.isEmpty || !lineaContacto.isEmpty {
                VStack(spacing: 3) {
                    // El logo solo si existe: nada de caja reservada.
                    if hayLogo {
                        LogoMembrete(alto: 44)
                            .frame(maxWidth: 120)
                            .padding(.bottom, 4)
                    }
                    if hay(iglesia.nombre) {
                        Text(iglesia.nombre)
                            .font(.system(size: 20, weight: .bold, design: .serif))
                    }
                    if !lineaDireccion.isEmpty {
                        Text(lineaDireccion).font(.system(size: 11)).foregroundStyle(HC.gris)
                    }
                    if !lineaContacto.isEmpty {
                        Text(lineaContacto).font(.system(size: 11)).foregroundStyle(HC.gris)
                    }
                }
                .frame(maxWidth: .infinity)
                // En el contenedor: un nombre largo que envuelve también se
                // centra línea a línea (ver `CartaHojaPDF`).
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                Raya().padding(.vertical, 16)
            }
            encabezadoCulto
            Raya().padding(.vertical, 14)
        }
    }

    /// Lo que se lee en dos segundos: qué culto, cuándo, quién, cuántos.
    private var encabezadoCulto: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Rotulo(texto: L.t("Hoja de culto", "Service sheet"))
                Text(s.titulo)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                if !fechaLarga.isEmpty {
                    Text(fechaLarga).font(.system(size: 13))
                }
                if !quien.isEmpty {
                    Text(quien).font(.system(size: 12)).foregroundStyle(HC.gris)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Sin conteo, sin cifra: un «0 asistentes» diría que no vino nadie
            // cuando lo que pasa es que no se contó.
            if total > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(total))
                        .font(.system(size: 34, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(monocromo ? Color.black : HC.verde)
                    Text(total == 1 ? L.t("asistente", "attendee") : L.t("asistentes", "attendees"))
                        .font(.system(size: 11, weight: .semibold))
                    if !desglose.isEmpty {
                        Text(desglose)
                            .font(.system(size: 10.5))
                            .monospacedDigit()
                            .foregroundStyle(HC.gris)
                    }
                }
                .fixedSize()
            }
        }
    }

    /// Página 2 en adelante: una línea para saber de qué culto es la hoja
    /// suelta, sin repetir el membrete entero.
    var cabeceraCorta: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if hay(iglesia.nombre) {
                    Text(iglesia.nombre).font(.system(size: 11, weight: .semibold))
                }
                Spacer(minLength: 0)
                Text(unir([L.t("Hoja de culto", "Service sheet"), s.titulo, fechaLarga]))
                    .font(.system(size: 11))
                    .foregroundStyle(HC.gris)
                    .multilineTextAlignment(.trailing)
            }
            .fixedSize(horizontal: false, vertical: true)
            Raya().padding(.top, 8).padding(.bottom, 18)
        }
    }

    // MARK: Firma y pie

    /// **Una raya en blanco, no un campo.** La tabla no guarda quién revisó
    /// la hoja: se firma a mano sobre el papel. Por eso no es `FirmasPDF`,
    /// que imprime a los cargos de Ajustes.
    var firma: some View {
        HStack(alignment: .bottom, spacing: 28) {
            VStack(alignment: .leading, spacing: 5) {
                Color.clear.frame(height: 30)
                Raya(color: HC.rayaFirma)
                Text(L.t("Revisado por · nombre y firma", "Reviewed by · name and signature"))
                    .font(.system(size: 10.5)).foregroundStyle(HC.gris)
            }
            .frame(width: 230)
            VStack(alignment: .leading, spacing: 5) {
                Raya(color: HC.rayaFirma)
                Text(L.t("Fecha", "Date"))
                    .font(.system(size: 10.5)).foregroundStyle(HC.gris)
            }
            .frame(width: 110)
        }
        .padding(.bottom, 20)
    }

    /// **La línea libre de Ajustes, centrada, con el número de página a la
    /// derecha.** Es la forma del diseño y no la de `PieInstitucionalPDF`
    /// (tres líneas a la izquierda): la dirección y el contacto ya están en
    /// el membrete, a unos centímetros. Sin línea escrita en Ajustes, el
    /// nombre y la dirección, para que una hoja suelta diga de quién es.
    func pie(numero: String?) -> some View {
        let texto = hay(iglesia.pieInstitucional)
            ? iglesia.pieInstitucional.trimmingCharacters(in: .whitespacesAndNewlines)
            : unir([iglesia.nombre, iglesia.direccion])
        return Group {
            if !texto.isEmpty || numero != nil {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(texto)
                        .font(.system(size: 9.5)).foregroundStyle(HC.gris)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let numero {
                        Text(numero)
                            .font(.system(size: 9.5)).monospacedDigit()
                            .foregroundStyle(HC.gris)
                            .fixedSize()
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .overlay(alignment: .top) { Raya(color: HC.rayaFina, grosor: 0.5) }
            }
        }
    }

    // MARK: Bloques

    private func bloqueMensaje(primerParrafo: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Rotulo(texto: L.t("Mensaje", "Message"))
            if hay(s.tituloMensaje) {
                Text(s.tituloMensaje)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            }
            let referencia = unir([
                s.textoBiblico,
                hay(s.predica) ? L.t("predicó \(limpio(s.predica))", "preached by \(limpio(s.predica))") : "",
            ])
            if !referencia.isEmpty {
                Text(referencia).font(.system(size: 11.5)).foregroundStyle(HC.gris)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let primerParrafo {
                parrafo(primerParrafo).padding(.top, 4)
            }
        }
    }

    private var bloqueEscuela: some View {
        VStack(alignment: .leading, spacing: 2) {
            Rotulo(texto: L.t("Escuela dominical", "Sunday school"))
            Group {
                if hay(s.temaEscuela) && hay(s.maestroEscuela) {
                    // Interpolación y no `Text + Text`, que iOS 26 marca como
                    // obsoleto.
                    Text("\(Text(limpio(s.temaEscuela)))\(Text(" · \(limpio(s.maestroEscuela))").foregroundStyle(HC.gris))")
                } else if hay(s.temaEscuela) {
                    Text(limpio(s.temaEscuela))
                } else {
                    Text(limpio(s.maestroEscuela)).foregroundStyle(HC.gris)
                }
            }
            .font(.system(size: 12))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func filaOrden(_ p: PuntoOrden) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(limpio(p.hora))
                .monospacedDigit()
                .foregroundStyle(HC.gris)
                .frame(width: HC.ordenHora, alignment: .leading)
            Text(limpio(p.titulo))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(limpio(p.encargado))
                .foregroundStyle(HC.gris)
                .multilineTextAlignment(.trailing)
                .frame(width: HC.ordenQuien, alignment: .trailing)
        }
        .font(.system(size: 11.5))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 3.5)
        .overlay(alignment: .bottom) { Raya(color: HC.rayaFina, grosor: 0.5) }
    }

    private var participaciones: [String] {
        s.participaciones.map(limpio).filter { !$0.isEmpty }
    }

    /// Los puestos agrupados por clave y en el orden en que llegan: dos
    /// ujieres son UNA fila con dos nombres, como en el diseño. Un puesto sin
    /// nadie no entra en la lista: va a «Sin asignar», que es lo que el papel
    /// le tiene que decir a quien lo revisa.
    private var puestosAgrupados: (asignados: [(String, String)], sinAsignar: [String]) {
        var claves: [String] = []
        var nombres: [String: [String]] = [:]
        for p in s.puestos {
            if nombres[p.puesto] == nil { claves.append(p.puesto); nombres[p.puesto] = [] }
            if p.asignado { nombres[p.puesto]?.append(limpio(p.nombre)) }
        }
        var asignados: [(String, String)] = []
        var sinAsignar: [String] = []
        for c in claves {
            let n = nombres[c] ?? []
            if n.isEmpty { sinAsignar.append(Puestos.etiqueta(c)) }
            else { asignados.append((Puestos.etiqueta(c), n.joined(separator: " · "))) }
        }
        return (asignados, sinAsignar)
    }

    private var bloquePuestos: some View {
        let (asignados, sinAsignar) = puestosAgrupados
        let hayPuestos = !asignados.isEmpty || !sinAsignar.isEmpty
        return HStack(alignment: .top, spacing: 28) {
            if hayPuestos {
                VStack(alignment: .leading, spacing: 0) {
                    Rotulo(texto: L.t("Puestos", "Roles")).padding(.bottom, 4)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(0..<asignados.count, id: \.self) { i in
                            HStack(alignment: .top, spacing: 0) {
                                Text(asignados[i].0)
                                    .foregroundStyle(HC.gris)
                                    .frame(width: 78, alignment: .leading)
                                Text(asignados[i].1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.system(size: 11.5))
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !sinAsignar.isEmpty {
                        Text(L.t("Sin asignar: \(sinAsignar.joined(separator: ", "))",
                                 "Unassigned: \(sinAsignar.joined(separator: ", "))"))
                            .font(.system(size: 10.5)).foregroundStyle(HC.gris)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, asignados.isEmpty ? 0 : 6)
                    }
                }
                // Las dos columnas del diseño (1.15fr · 1fr); sin
                // participaciones, los puestos se quedan el ancho entero.
                .frame(width: participaciones.isEmpty ? HC.util : HC.columnaPuestos, alignment: .leading)
            }
            if !participaciones.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Rotulo(texto: L.t("Participaciones", "Participants")).padding(.bottom, 4)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(0..<participaciones.count, id: \.self) { i in
                            Text(participaciones[i])
                                .font(.system(size: 11.5))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// **Nombre, quién lo invitó y si es su primera vez. Nada más.** El
    /// visitante dejó su teléfono y su correo a la iglesia, no a quien
    /// encuentre la hoja en una carpeta o en la bandeja de la impresora.
    private func cabeceraVisitantes(_ v: [VisitanteServicio]) -> some View {
        let primeras = v.filter(\.primeraVisita).count
        let cuenta = primeras > 0
            ? L.t("\(v.count) · \(primeras) por primera vez", "\(v.count) · \(primeras) first-time")
            : String(v.count)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Rotulo(texto: L.t("Visitantes", "Visitors"))
                Text(cuenta).font(.system(size: 10.5)).foregroundStyle(HC.gris)
            }
            .padding(.bottom, 3)
            HStack(spacing: 8) {
                Text(L.t("Nombre", "Name"))
                    .frame(width: HC.visitaNombre, alignment: .leading)
                Text(L.t("Invitado por", "Invited by"))
                    .frame(width: HC.visitaPor, alignment: .leading)
                Text(L.t("Primera visita", "First visit"))
                    .frame(width: HC.visitaPrimera, alignment: .trailing)
            }
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(HC.gris)
            .lineLimit(1)
            .padding(.vertical, 3)
            .overlay(alignment: .bottom) { Raya() }
        }
    }

    private func filaVisitante(_ v: VisitanteServicio) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(limpio(v.nombre))
                .frame(width: HC.visitaNombre, alignment: .leading)
            Text(limpio(v.invitadoPor ?? ""))
                .foregroundStyle(HC.gris)
                .frame(width: HC.visitaPor, alignment: .leading)
            // «Sí» o nada: un «No» en cada fila de los que ya vinieron antes
            // es ruido que tapa a los nuevos, que es lo que se busca.
            Text(v.primeraVisita ? L.t("Sí", "Yes") : "")
                .fontWeight(.semibold)
                .frame(width: HC.visitaPrimera, alignment: .trailing)
        }
        .font(.system(size: 11.5))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Raya(color: HC.rayaFina, grosor: 0.5) }
    }

    /// Un párrafo de 12 pt con el interlineado 1,5 del diseño.
    private func parrafo(_ texto: String) -> some View {
        Text(texto)
            .font(.system(size: 12))
            .lineSpacing(3.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Datos

    private var total: Int { s.ninos + s.jovenes + s.adultos }

    /// «142 adultos · 38 jóvenes · 27 niños», en ese orden, como el diseño, y
    /// sin los grupos en cero. Los visitantes NO suman: ya están contados
    /// dentro de esas tres cifras o no vinieron.
    private var desglose: String {
        var partes: [String] = []
        if s.adultos > 0 {
            partes.append(s.adultos == 1 ? L.t("1 adulto", "1 adult")
                                         : L.t("\(s.adultos) adultos", "\(s.adultos) adults"))
        }
        if s.jovenes > 0 {
            partes.append(s.jovenes == 1 ? L.t("1 joven", "1 youth")
                                         : L.t("\(s.jovenes) jóvenes", "\(s.jovenes) youth"))
        }
        if s.ninos > 0 {
            partes.append(s.ninos == 1 ? L.t("1 niño", "1 child")
                                       : L.t("\(s.ninos) niños", "\(s.ninos) children"))
        }
        return partes.joined(separator: " · ")
    }

    private var quien: String {
        let d = limpio(s.dirige), p = limpio(s.predica)
        switch (d.isEmpty, p.isEmpty) {
        case (false, false): return L.t("Dirigió \(d) · predicó \(p)", "Led by \(d) · preached by \(p)")
        case (false, true):  return L.t("Dirigió \(d)", "Led by \(d)")
        case (true, false):  return L.t("Predicó \(p)", "Preached by \(p)")
        case (true, true):   return ""
        }
    }

    /// «domingo, 21 de septiembre de 2026». **En UTC**, como `diaLegible`: la
    /// fecha del culto es un día y se lee a medianoche UTC; en la zona del
    /// aparato —al oeste de Greenwich— saldría el sábado.
    private var fechaLarga: String {
        guard !s.fecha.isEmpty, let d = Fechas.desdeTextoFlexible(s.fecha) else { return s.fecha }
        let f = L.formateador(L.t("EEEE, d 'de' MMMM 'de' yyyy", "EEEE, MMMM d, yyyy"))
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d)
    }

    private func limpio(_ t: String) -> String { t.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func hay(_ t: String) -> Bool { !limpio(t).isEmpty }
    private func unir(_ partes: [String]) -> String {
        partes.map(limpio).filter { !$0.isEmpty }.joined(separator: " · ")
    }
    /// Los saltos de línea que escribió la secretaria, como párrafos: son los
    /// puntos por donde un texto largo puede pasar a la página siguiente.
    private func parrafos(_ t: String) -> [String] {
        t.components(separatedBy: .newlines).map(limpio).filter { !$0.isEmpty }
    }
}
