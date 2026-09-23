import SwiftUI

/// **Actas, según el handoff**: una rejilla de tarjetas a dos columnas, con el
/// estado, la fecha y quién firma.
///
/// Un acta no es una fila de tabla: lo que se quiere ver de un vistazo es
/// cuáles están firmadas y cuáles esperan una firma, y eso es una propiedad de
/// la tarjeta entera, no de una celda.
struct PantallaActas: View {
    let vm: ActasViewModel
    @Binding var seleccion: String?

    /// **El testigo del alta no es `@State` de esta vista.** Lo dispara el ⌘N
    /// del menú Archivo, que no alcanza el estado privado de una vista — ver
    /// `EstadoVentana.pidiendoAlta`.
    @Environment(EstadoVentana.self) private var estado

    private let columnas = [GridItem(.adaptive(minimum: 320, maximum: 560), spacing: 13)]

    /// El acta a la que se le están recogiendo firmas. **`item:` y no
    /// `isPresented:`**, por lo que ya midió el iPhone: la hoja recibe el acta
    /// que se abrió y no vuelve a leer la selección, que podría ser otra.
    @State private var actaFirmando: Acta?

    /// La elegida, si admite firmas. Borrador o pendiente: lo demás ya pasó
    /// por ese paso o lo cerró.
    private var actaElegidaFirmable: Acta? {
        guard let a = vm.lista.first(where: { $0.id == seleccion }) else { return nil }
        return Self.admiteFirmas(a) ? a : nil
    }

    private static func admiteFirmas(_ a: Acta) -> Bool {
        a.estado == .borrador || a.estado == .pendienteAprobacion
    }

    var body: some View {
        ScrollView {
            if vm.lista.isEmpty {
                ContentUnavailableView {
                    Label(L.t("Todavía no hay actas", "No minutes yet"), systemImage: "doc.text")
                } description: {
                    Text(L.t("Las reuniones que se cierren aparecerán aquí.",
                             "Meetings you close will show up here."))
                }
                .padding(.top, 50)
            } else {
                // **La cabecera del handoff**: el rótulo del año a la izquierda
                // y el alta a la derecha con su atajo escrito, que es donde se
                // aprende. El botón hace lo mismo que el ⇧⌘M del menú.
                HStack(spacing: 10) {
                    Text(L.t("REUNIONES DE ESTE AÑO", "MEETINGS THIS YEAR"))
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.5)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    // **Solo con un acta que todavía se trabaja**, la misma
                    // condición del iPhone: firmar una ya cerrada o archivada
                    // la devolvería a "Firmada" y le quitaría el cierre.
                    Button(L.t("Recopilar firmas…", "Collect signatures…")) {
                        actaFirmando = actaElegidaFirmable
                    }
                    .disabled(actaElegidaFirmable == nil)
                    Button { estado.pidiendoAlta = true } label: {
                        HStack(spacing: 6) {
                            Text(L.t("Nueva acta", "New minutes entry"))
                            Text("⇧⌘M").opacity(0.75)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                LazyVGrid(columns: columnas, spacing: 13) {
                    ForEach(vm.lista) { tarjeta($0) }
                }
                .padding(20)
            }
        }
        .background(Color.suelo)
        .sheet(isPresented: Binding(
            get: { estado.pidiendoAlta },
            set: { estado.pidiendoAlta = $0 }
        )) {
            NuevaActa(proximoId: vm.proximoId,
                      proximoNumeroProvisional: vm.lista.count + 1) { acta in
                Task {
                    // Guardar y LUEGO sincronizar, en ese orden y esperando:
                    // lanzarlos a la vez deja la vuelta saliendo antes de que la
                    // operación esté en la cola. Medido en Membresía.
                    await vm.agregarActa(acta)
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
        .sheet(item: $actaFirmando) { acta in
            FirmasActaMac(acta: acta) { firmas in
                Task {
                    // `firmarActa` es el del iPhone: guarda las firmas en su
                    // columna, pasa el acta a Firmada —que al web sube como
                    // "aprobada", ver `EstadoActa.clave`— y la encola. Después
                    // se sincroniza, esperando, como el alta de arriba.
                    await vm.firmarActa(id: acta.id, firmas: firmas)
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
    }

    private func tarjeta(_ a: Acta) -> some View {
        let elegida = seleccion == a.id
        return Button { seleccion = a.id } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    Text(a.tituloPersonalizado ?? a.tipo.etiqueta)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(a.estado.etiqueta)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(a.estado.color)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(a.estado.color.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                Text(meta(a))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)

                // El primer acuerdo hace de resumen. Un acta sin acuerdos es
                // una reunión sin decisiones, y también se dice.
                Text(a.items.first?.texto ?? L.t("Sin acuerdos anotados.",
                                                 "No resolutions recorded."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(a.items.isEmpty ? .tertiary : .secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                if !a.firmas.isEmpty {
                    HStack(spacing: 7) {
                        ForEach(a.firmas) { chipDeFirma($0, en: a) }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 13)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(elegida ? Paleta.brandFill : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(elegida ? Paleta.brandStroke : Color.secondary.opacity(0.22),
                        lineWidth: elegida ? 1 : 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if Self.admiteFirmas(a) {
                Button(L.t("Recopilar firmas…", "Collect signatures…")) {
                    seleccion = a.id
                    actaFirmando = a
                }
            }
        }
    }

    /// **En su propia función y no dentro del `ForEach`.**
    ///
    /// Dentro de la tarjeta, el compilador se rindió: "unable to type-check
    /// this expression in reasonable time". Es el mismo aviso que ya documenta
    /// `InformesMembresiaViewModel` al armar `porMinisterio`, y la cura es la
    /// misma: sacar la pieza y darle tipos.
    private func chipDeFirma(_ f: FirmaActa, en a: Acta) -> some View {
        let tinta: Color = f.firmado ? Paleta.brand : Paleta.aviso
        // **El nombre no está en la firma.** `FirmaActa` solo guarda el rol y
        // si está firmada; quién ocupa ese rol vive en el acta —`preside` y
        // `secretario`—. El testigo no tiene campo, así que se queda con el
        // rótulo de su rol.
        let quien: String = {
            switch f.rol {
            case .preside:    return a.preside
            case .secretario: return a.secretario
            case .testigo:    return ""
            }
        }()
        let nombre: String = quien.isEmpty ? f.rol.etiqueta : quien
        return HStack(spacing: 4) {
            Image(systemName: f.firmado ? "checkmark" : "clock")
                .font(.system(size: 9, weight: .bold))
            Text(nombre)
                .font(.system(size: 11.5))
                .lineLimit(1)
        }
        .foregroundStyle(tinta)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func meta(_ a: Acta) -> String {
        var piezas: [String] = []
        if !a.fecha.isEmpty { piezas.append(Fechas.diaLegible(a.fecha)) }
        if !a.presentes.isEmpty {
            piezas.append(L.t("\(a.presentes.count) presentes",
                              "\(a.presentes.count) attendees"))
        }
        if !a.folio.isEmpty { piezas.append(L.t("folio \(a.folio)", "folio \(a.folio)")) }
        return piezas.joined(separator: " · ")
    }
}

// MARK: - Recopilar firmas

/// **La hoja de firmas del Mac**, con la forma común `HojaMac` y la regla del
/// iPhone (`FirmasSheet` en `ActasView`), que es la que ya cumple el web: se
/// marca a cada persona al recibir su firma en el papel, y el acta pasa a
/// Firmada solo cuando constan los tres renglones que se imprimen.
///
/// **No es una firma dibujada.** Eso es `FirmasLocales` y no se sincroniza; esto
/// es la casilla de que esa persona ya firmó, con el día, que es lo que guarda
/// la columna `firmas` del web.
///
/// **Por qué no se guarda a medias.** `firmarActa` pone el acta en Firmada al
/// guardar; dejar guardar con dos de tres firmaría un acta a la que le falta
/// una. Sin un estado "firmada en parte" —y no se inventa: el web no lo
/// reconocería— lo honrado es pedir las tres, como hace el iPhone.
private struct FirmasActaMac: View {
    let acta: Acta
    let alFirmar: ([FirmaActa]) -> Void

    @State private var firmados: Set<RolFirmaActa> = []
    @State private var intentoGuardar = false
    /// Para marcar lo ya firmado UNA vez al abrir, y no pisar lo que se toque
    /// después si la vista se vuelve a evaluar.
    @State private var cargado = false

    private let roles = RolFirmaActa.allCases

    /// Quién ocupa cada renglón, si el acta lo dice. El testigo no tiene campo
    /// y se queda con el nombre de su rol.
    private func nombre(_ rol: RolFirmaActa) -> String {
        switch rol {
        case .preside:    return acta.preside.isEmpty ? rol.etiqueta : acta.preside
        case .secretario: return acta.secretario.isEmpty ? rol.etiqueta : acta.secretario
        case .testigo:    return rol.etiqueta
        }
    }

    /// Lo que falta, con el nombre de quien falta: "falta la firma de Preside"
    /// no sirve de nada si el acta ya dice quién presidió.
    private var faltan: [String] {
        roles.filter { !firmados.contains($0) }
             .map { L.t("la firma de \(nombre($0))", "\(nombre($0))'s signature") }
    }

    var body: some View {
        HojaMac(titulo: L.t("Recopilar firmas · \(acta.titulo)",
                            "Collect signatures · \(acta.titulo)"),
                rotuloGuardar: L.t("Confirmar firmas", "Confirm signatures"),
                faltan: faltan,
                intentoGuardar: intentoGuardar,
                alGuardar: guardar) {
            SeccionHoja(titulo: L.t("FIRMAS REQUERIDAS", "REQUIRED SIGNATURES"),
                        nota: L.t("Marca a cada persona al recibir su firma en el papel. Al confirmar, el acta pasa a «Firmada».",
                                  "Tick each person as you receive their signature on paper. On confirm, the minutes change to “Signed”.")) {
                ForEach(roles) { rol in
                    FilaInterruptor(rotulo: nombre(rol),
                                    sub: subtitulo(rol),
                                    activo: Binding(
                                        get: { firmados.contains(rol) },
                                        set: { if $0 { firmados.insert(rol) } else { firmados.remove(rol) } }
                                    ))
                }
            }
        }
        // **Lo ya firmado viene marcado.** Sin esto, recoger la tercera firma
        // obligaba a volver a marcar las dos que ya estaban.
        .task {
            guard !cargado else { return }
            firmados = Set(acta.firmas.filter(\.firmado).map(\.rol))
            cargado = true
        }
    }

    /// El rol debajo del nombre y, si ya firmó, el día: un acta puede recoger
    /// la tercera firma semanas después de las dos primeras.
    private func subtitulo(_ rol: RolFirmaActa) -> String? {
        let yaFirmo = acta.firmas.first { $0.rol == rol && $0.firmado }
        let base = nombre(rol) == rol.etiqueta ? nil : rol.etiqueta
        guard let fecha = yaFirmo?.fecha, !fecha.isEmpty else { return base }
        let firmo = L.t("Firmó el \(Fechas.diaLegible(fecha))", "Signed \(Fechas.diaLegible(fecha))")
        return base.map { "\($0) · \(firmo)" } ?? firmo
    }

    private func guardar() -> Bool {
        intentoGuardar = true
        guard faltan.isEmpty else { return false }
        // El día se guarda por firma y se conserva el de quien ya había
        // firmado: volver a confirmar no le cambia la fecha a nadie.
        let hoy = Fechas.claveDia()
        alFirmar(roles.map { rol in
            let antes = acta.firmas.first { $0.rol == rol && $0.firmado }
            return FirmaActa(rol: rol, firmado: true, fecha: antes?.fecha ?? hoy)
        })
        return true
    }
}
