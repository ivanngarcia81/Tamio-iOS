import SwiftUI

/// **Las piezas de papel que comparten todos los documentos**, y el acta.
///
/// Vivían en `Views/Components` —`SecretariaPDF.swift`, `ReportePDF.swift` y
/// `LogoMembrete.swift`—, que el Mac no compila, y eso dejaba al Mac sin poder
/// sacar ni un solo PDF de los que ya sabe hacer el iPhone: el acta, la hoja
/// de culto, el corte (ver `docs/CONTEXTO.md` §0.-23). Se mudaron aquí, a
/// `Support`, que compilan los dos targets, **con el mismo nombre y la misma
/// firma**: ninguna llamada del iPhone cambió.
///
/// Lo único que no era común era el tipo de la imagen —`UIImage` en iOS,
/// `NSImage` en macOS—, y eso ya lo resuelve `ImagenPlataforma`
/// (`Plataforma.swift`). Aquí solo falta la otra mitad: pintarla.
///
/// Lo que sigue en `Views/Components` son las hojas de un solo documento y las
/// hojas modales de iOS (`DocumentoPDFSheet`, `ReportePDFSheet`…): esas usan
/// `NavigationStack`, `ShareLink` y la barra de iOS, y el Mac las resuelve a
/// su manera en cada pantalla.

// MARK: - Pintar una imagen de la plataforma

extension Image {
    /// Una `Image` de SwiftUI a partir de la imagen nativa, sea cual sea.
    ///
    /// Existe para que las piezas de abajo no lleven un `#if` cada una: la
    /// firma y el logo se pintan igual en los dos sistemas y lo único que
    /// cambia es el nombre del inicializador.
    init(plataforma imagen: ImagenPlataforma) {
        #if canImport(UIKit)
        self.init(uiImage: imagen)
        #else
        self.init(nsImage: imagen)
        #endif
    }
}

// MARK: - El logo del membrete

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
            Image(plataforma: imagen)
                .resizable()
                .scaledToFit()
                // Altura fija y ancho libre: con `maxHeight` el `scaledToFit`
                // colapsa a cero cuando el contenedor propone cero, que es lo
                // que hace `ImageRenderer` al medir la página.
                .frame(height: alto)
        }
    }
}

// MARK: - Una línea de firma

/// La raya con su nombre debajo y, si la hay, la firma dibujada encima.
///
/// La mecánica es la de `FirmasPDF` y por el mismo motivo: **la firma va ENCIMA
/// de la raya, no en lugar de ella**, así el documento se lee igual firmado en
/// la app o a mano sobre el papel, y quien no tenga firma guardada sigue
/// teniendo dónde firmar. Se saca aparte porque ahora la usan tres documentos
/// con tres repartos distintos —el reporte firma con los cargos de la iglesia,
/// la carta con uno solo, el acta con los tres roles del acta— y la única forma
/// de que las tres se vean iguales es que sean la misma.
struct FirmaEnLinea: View {
    let nombre: String
    let cargo: String
    var imagen: ImagenPlataforma? = nil
    /// El acta marca quién ya firmó; la carta y el reporte no llevan esa
    /// casilla y no enseñan nada aquí.
    var fechaFirma: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            if let imagen {
                Image(plataforma: imagen)
                    .resizable().scaledToFit()
                    .frame(height: 34)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Color.clear.frame(height: 34)
            }
            Rectangle().fill(.secondary.opacity(0.5)).frame(height: 0.75)
            Text(nombre.isEmpty ? " " : nombre).font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
            Text(cargo).font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
            if let fechaFirma, !fechaFirma.isEmpty {
                Text(L.t("Firmó el \(Fechas.diaLegible(fechaFirma))",
                         "Signed \(Fechas.diaLegible(fechaFirma))"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Las firmas de la iglesia

/// Bloque de firmas al pie de un documento. Las líneas salen de Ajustes y solo
/// se imprimen las de quien tiene nombre: una raya con un cargo debajo y nadie
/// encima no vale para nada.
struct FirmasPDF: View {
    let iglesia: ConfiguracionIglesia
    /// Las firmas guardadas en ESTE aparato. No viajan: un documento generado
    /// desde otro teléfono sale con la raya en blanco, y eso es lo esperado
    /// (ver `FirmasLocales`).
    var firmas: FirmasLocales = .compartidas

    var body: some View {
        let firmantes = iglesia.firmantes
        if !firmantes.isEmpty {
            VStack(alignment: .leading, spacing: 28) {
                Divider()
                HStack(alignment: .top, spacing: 32) {
                    ForEach(Array(firmantes.enumerated()), id: \.offset) { i, f in
                        VStack(spacing: 6) {
                            // La firma va ENCIMA de la raya, no en lugar de
                            // ella: así el documento se lee igual esté firmado
                            // en la app o a mano sobre el papel, y quien no
                            // tenga firma guardada sigue teniendo dónde firmar.
                            if let imagen = firma(para: i) {
                                Image(plataforma: imagen)
                                    .resizable().scaledToFit()
                                    .frame(height: 34)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Color.clear.frame(height: 34)
                            }
                            Rectangle().fill(.secondary.opacity(0.5))
                                .frame(height: 0.75)
                            Text(f.nombre).font(.caption.weight(.semibold))
                            Text(f.cargo).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    /// `firmantes` va en orden pastor, tesorero, secretario, y solo trae a los
    /// que tienen nombre: por eso no vale el índice para saber quién es cada
    /// uno. Se compara con el nombre configurado.
    private func firma(para indice: Int) -> ImagenPlataforma? {
        let f = iglesia.firmantes[indice]
        if f.nombre == iglesia.tesoreroNombre { return firmas.imagen(.tesorero) }
        if f.nombre == iglesia.pastorNombre { return firmas.imagen(.pastor) }
        return nil
    }
}

// MARK: - El pie

/// Pie institucional: la línea libre de Ajustes, con los datos de contacto.
struct PieInstitucionalPDF: View {
    let iglesia: ConfiguracionIglesia

    private var contacto: String {
        [iglesia.direccion, iglesia.telefono, iglesia.correo]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !contacto.isEmpty {
                Text(contacto).font(.caption2).foregroundStyle(.secondary)
            }
            if !iglesia.pieInstitucional.isEmpty {
                Text(iglesia.pieInstitucional).font(.caption2).foregroundStyle(.secondary)
            }
            if !iglesia.idFiscal.isEmpty {
                Text(L.t("ID fiscal: \(iglesia.idFiscal)", "Tax ID: \(iglesia.idFiscal)"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - El membrete, a solas

/// **Cómo queda el membrete con lo que hay escrito en Ajustes.**
///
/// La fila "Vista previa del PDF" de Ajustes · Institución llevaba desde
/// siempre en "Próximamente". No hacía falta inventar nada para cumplirla: los
/// documentos ya se arman con estas mismas piezas —`LogoMembrete`, `FirmasPDF`,
/// `PieInstitucionalPDF`—, así que la previa es literalmente lo que va a salir
/// impreso, sin datos de ejemplo de por medio.
///
/// El cuerpo es una franja gris y no un texto falso: **lo que esta pantalla
/// configura es el marco**, no lo que va dentro. Poner una carta inventada
/// ahí invitaría a revisar la prosa en vez del membrete, que es lo que se está
/// mirando.
struct MembreteHojaPDF: View {
    var iglesia: ConfiguracionIglesia = ConfiguracionIglesiaViewModel.compartido.config

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .center, spacing: 4) {
                LogoMembrete(alto: 60)
                if !iglesia.nombre.isEmpty {
                    Text(iglesia.nombre).font(.system(.title3, design: .serif).weight(.bold))
                }
                if !iglesia.ubicacionLegible.isEmpty {
                    Text(iglesia.ubicacionLegible).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.bottom, 20)

            Divider().padding(.bottom, 24)

            // El hueco del documento. Cuatro rayas y no un párrafo de mentira:
            // aquí se mira el marco.
            // El ancho útil de la hoja: la página menos sus dos márgenes. Se
            // calcula y no se escribe a mano para que las rayas sigan al papel
            // si algún día cambia el margen.
            let util = PDFExport.anchoCarta - 96
            VStack(alignment: .leading, spacing: 10) {
                ForEach([1.0, 0.94, 0.97, 0.62], id: \.self) { proporcion in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.secondary.opacity(0.16))
                        .frame(width: util * proporcion, height: 11)
                }
            }
            .padding(.bottom, 36)

            FirmasPDF(iglesia: iglesia)
            Spacer(minLength: 24)
            PieInstitucionalPDF(iglesia: iglesia)
        }
        .padding(48)
        .frame(width: PDFExport.anchoCarta, alignment: .leading)
    }
}

// MARK: - Acta

/// La hoja de un acta. Lleva lo que el formulario recoge y la pantalla enseña,
/// más el bloque de firmas que el pie de Ajustes lleva prometiendo.
///
/// Vive aquí y no con la carta porque es la que el Mac necesitaba ya: el acta
/// se redacta y se firma en el Mac igual que en el iPhone, y sin esta hoja no
/// había forma de sacarla en papel. La carta sigue en `SecretariaPDF.swift`
/// porque depende de `CartaEnEdicion`, que es de la pantalla de iOS.
struct ActaHojaPDF: View {
    let acta: Acta
    var iglesia: ConfiguracionIglesia = ConfiguracionIglesiaViewModel.compartido.config
    var firmas: FirmasLocales = .compartidas

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .center, spacing: 4) {
                LogoMembrete(alto: 52)
                Text(L.t("ACTA · \(acta.tipo.etiqueta.uppercased())",
                         "MINUTES · \(acta.tipo.etiqueta.uppercased())"))
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .multilineTextAlignment(.center)
                Text(L.t("\(iglesia.nombre) · Acta \(acta.folio)",
                         "\(iglesia.nombre) · Minutes \(acta.folio)"))
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !acta.fecha.isEmpty {
                    Text(Fechas.diaLegible(acta.fecha))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            Divider()

            // **El quórum, que es lo único que el cuerpo no dice.** Aquí
            // hubo primero una tabla con lugar, hora, quién preside, presentes
            // y ausentes: al verla impresa resultó que `Acta.cuerpo` ya narra
            // todo eso, así que el acta salía diciendo dos veces la lista de
            // asistentes. El cuerpo manda; esta línea completa lo que le falta.
            if acta.quorum {
                Text(L.t("Se declara quórum.", "Quorum declared."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !acta.cuerpo.isEmpty {
                Text(acta.cuerpo).font(.subheadline).lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !acta.items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L.t("ACUERDOS", "AGREEMENTS"))
                        .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(Array(acta.items.enumerated()), id: \.element.id) { idx, item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(idx + 1).")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Paleta.brand)
                                .frame(width: 20, alignment: .trailing)
                            Text(item.texto).font(.subheadline).lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Spacer(minLength: 24)
            Divider()

            HStack(alignment: .top, spacing: 32) {
                ForEach(RolFirmaActa.allCases) { rol in
                    FirmaEnLinea(nombre: nombre(rol), cargo: rol.etiqueta,
                                 imagen: imagen(rol), fechaFirma: fechaFirma(rol))
                        .frame(maxWidth: .infinity)
                }
            }

            PieInstitucionalPDF(iglesia: iglesia)
        }
        .padding(48)
        // **El ancho de la página, explícito.** Es el contrato que documenta
        // `HojaCartaEscalada` y que cumplen las otras cuatro hojas. Sin él,
        // nadie propone un ancho: cada `Text` se mide a UNA línea, y el acta
        // salía con todo cortado en "…" y la hoja dibujada estrecha.
        .frame(width: PDFExport.anchoCarta, alignment: .leading)
    }

    /// Quién ocupa cada rol. Del acta, no de Ajustes: quien presidió esa
    /// reunión puede no ser el pastor, y el acta ya lo guarda.
    private func nombre(_ rol: RolFirmaActa) -> String {
        switch rol {
        case .preside:    return acta.preside.isEmpty ? iglesia.pastorNombre : acta.preside
        case .secretario: return acta.secretario.isEmpty ? iglesia.secretarioNombre : acta.secretario
        case .testigo:    return ""
        }
    }

    /// La rúbrica guardada solo si quien ocupa el rol es la persona de Ajustes
    /// que la dibujó, y solo si el acta consta como firmada por ese rol: una
    /// firma estampada en un acta que nadie ha firmado es exactamente lo que un
    /// acta no puede hacer.
    private func imagen(_ rol: RolFirmaActa) -> ImagenPlataforma? {
        guard firmo(rol) else { return nil }
        let quien = nombre(rol)
        if quien == iglesia.pastorNombre { return firmas.imagen(.pastor) }
        if quien == iglesia.tesoreroNombre { return firmas.imagen(.tesorero) }
        return nil
    }

    private func firmo(_ rol: RolFirmaActa) -> Bool {
        acta.firmas.first { $0.rol == rol }?.firmado ?? false
    }

    private func fechaFirma(_ rol: RolFirmaActa) -> String? {
        acta.firmas.first { $0.rol == rol && $0.firmado }?.fecha
    }
}
