import SwiftUI

/// **Configuración, según el handoff.**
///
/// Barra propia a la izquierda —la Cuenta suelta arriba, los grupos IGLESIA y
/// GENERAL, y la Zona de riesgo separada al pie— y a la derecha una columna de
/// 640 pt con la tarjeta de cabecera y los grupos de ajustes.
///
/// Las ocho secciones, sus iconos, sus colores y sus descripciones salen de
/// `SeccionAjustes`, que ya las tenía: esta pantalla no inventa ninguna.
struct PantallaConfiguracion: View {
    @Binding var seccion: SeccionAjustes
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    @State private var firmas = FirmasLocales.compartidas
    @State private var logo = LogoIglesia.compartido
    @State private var errorLogo: String?
    @State private var confirmarQuitarLogo = false
    /// Los ingresos del mes por categoría, para el porcentaje del handoff.
    @State private var composicionDelMes: [CategoriaMonto] = []
    @State private var prefs = PreferenciasApp.compartidas
    @State private var categorias = CategoriasViewModel.compartido
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    /// **Observable, así que leerlo en el `body` basta para que la pantalla se
    /// entere.** Es el mismo motor que mira la barra de estado; aquí se
    /// consulta y se puede forzar a mano.
    private let motor = MotorSincronizacion.compartido
    @State private var bloqueo = BloqueoBiometrico.compartido

    /// **Se pregunta al construir y no dentro del `body`**, como en iOS:
    /// `canEvaluatePolicy` toca el sistema de seguridad y el `body` se
    /// reevalúa muchas veces.
    private let biometria = BloqueoBiometrico.disponible()

    @State private var invEmail = ""
    @State private var invNom = ""
    @State private var invRol: SesionSupabase.Perfil.Rol = .tesorero
    @State private var invitando = false
    @State private var avisoInvitacion: String?

    /// El saldo de apertura se teclea como texto y se guarda en centavos: ver
    /// `fijarApertura`.
    @State private var aperturaTexto = ""

    // Zona de riesgo.
    @State private var trabajando = false
    @State private var errorZona: String?
    @State private var hecho: String?
    @State private var ultimoRespaldo = Respaldo.ultimoLegible
    @State private var protegerRespaldo = false
    @State private var contrasenaRespaldo = ""
    @State private var estadoBase: Compactacion.Estado?
    @State private var porRestaurar: (url: URL, manifiesto: Respaldo.Manifiesto)?
    @State private var confirmarPurgar = false
    @State private var confirmarReinicio = false
    @State private var cuantosMovimientos: Int?
    @State private var cuantosAportantes: Int?

    @State private var confirmarCierre = false
    @State private var confirmarBorrado = false
    @State private var borrando = false
    @State private var errorBorrado: String?

    var body: some View {
        // **`HStack` y no `HSplitView`, y es lo que hace que esta pantalla
        // quepa.**
        //
        // El `HSplitView` clavaba la barra de secciones en su `maxWidth: 360`
        // y **no la comprimía nunca**: ni apretando la ventana ni arrastrando
        // su separador —probado, el ancho no se movía—. Con la barra de la app
        // en 220 y el contenido en 521, el mínimo de la ventana se iba a 1101,
        // y media pantalla de una MacBook de 14" son 900.
        //
        // Un `HStack` sí respeta el `minWidth` cuando falta sitio: 220 + 240 +
        // 420 = 880, y cabe. El precio es el separador arrastrable entre la
        // barra de secciones y el panel, que en una pantalla de ajustes no
        // vale lo que cuesta: la lista de secciones no es una columna que uno
        // quiera ensanchar, y el divisor de la ventana principal sigue ahí.
        HStack(spacing: 0) {
            // **Mínimo 300 y no 240.** Con 240 el `HStack` sí comprimía —la
            // ventana bajaba a 881— pero la barra se RECORTABA: su contenido
            // natural es más ancho que 240 y SwiftUI lo centra y lo corta por
            // los dos lados. Se leía "tings" en vez de "Settings" y "AL" en
            // vez de "GENERAL". Caber rompiendo es peor que no caber.
            barra.frame(minWidth: 320, idealWidth: 320, maxWidth: 360)
            Divider()
            ScrollView {
                VStack(spacing: 24) {
                    cabecera
                    contenido
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            // **El saldo se relee al ENTRAR en Iglesia y se fija al SALIR.**
            // En el iPad eso lo hacen el `onAppear`/`onDisappear` de una
            // pantalla empujada; aquí no hay tal cosa —la columna se queda
            // montada y solo cambia lo de dentro—, así que la señal es el
            // cambio de sección.
            .onChange(of: seccion) { anterior, _ in
                if anterior == .iglesia {
                    fijarApertura()
                    Task { await cfg.guardarYa() }
                }
                aperturaTexto = textoApertura
            }
            .onAppear { aperturaTexto = textoApertura }
            .sheet(item: $firmando) { quien in
                HojaFirmaMac(firmante: quien, firmas: firmas)
            }
            .alert(L.t("¿Quitar el logo?", "Remove the logo?"),
                   isPresented: $confirmarQuitarLogo) {
                Button(L.t("Cancelar", "Cancel"), role: .cancel) {}
                Button(L.t("Quitar", "Remove"), role: .destructive) {
                    Task { await quitarLogo() }
                }
            } message: {
                Text(L.t("Los documentos volverán a salir sin logo, en todos los aparatos de la iglesia.",
                         "Documents will print without a logo again, on every device in the church."))
            }
            .task {
                composicionDelMes = await repositorioReportes()
                    .estadoFinanciero(periodo: Fechas.clavePeriodo(), categoria: nil)?
                    .composicion ?? []
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.suelo)
        }
    }

    // MARK: - La barra de secciones

    private var barra: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.t("Configuración", "Settings"))
                .font(.system(size: 26, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    fila(.cuenta, alto: 52, radio: 16, fuente: 16)
                        .padding(.bottom, 20)
                    grupo(L.t("IGLESIA", "CHURCH"),
                          [.iglesia, .institucion, .tesorero, .acceso])
                    grupo(L.t("GENERAL", "GENERAL"), [.categorias, .preferencias])
                }
                .padding(.bottom, 12)
            }

            // **La zona de riesgo va separada y al pie**, como en el handoff.
            // No es una sección más: es la única desde la que se puede borrar
            // lo que no vuelve.
            Divider()
            fila(.zona, alto: 44, radio: 12, fuente: 15.5)
                .padding(.vertical, 10)
        }
    }

    private func grupo(_ titulo: String, _ secciones: [SeccionAjustes]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo)
                .font(.system(size: 11.5, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            ForEach(secciones, id: \.self) { fila($0, alto: 44, radio: 12, fuente: 15.5) }
        }
        .padding(.bottom, 20)
    }

    private func fila(_ s: SeccionAjustes, alto: CGFloat,
                      radio: CGFloat, fuente: CGFloat) -> some View {
        let activa = seccion == s
        let esZona = s == .zona
        return Button { seccion = s } label: {
            HStack(spacing: 11) {
                Image(systemName: s.icono)
                    .font(.system(size: alto > 48 ? 16 : 15, weight: .medium))
                    // El símbolo va del color que `Paleta.sobre` elija para
                    // esa placa, no blanco fijo: sobre un cian claro el blanco
                    // se hunde.
                    .foregroundStyle(Paleta.sobre(s.color, prefs.tema.esquema ?? .light))
                    .frame(width: alto > 48 ? 30 : 28, height: alto > 48 ? 30 : 28)
                    .background(s.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(s.titulo)
                    .font(.system(size: fuente, weight: activa ? .semibold : .regular))
                    .foregroundStyle(activa ? (esZona ? s.color : Paleta.brand) : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if s == .cuenta {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, s == .cuenta ? 16 : 12)
            .frame(height: alto)
            .background(fondo(activa: activa, esZona: esZona, color: s.color),
                        in: RoundedRectangle(cornerRadius: radio, style: .continuous))
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func fondo(activa: Bool, esZona: Bool, color: Color) -> Color {
        guard activa else { return .clear }
        return esZona ? color.opacity(0.12) : Paleta.brandFill
    }

    // MARK: - La cabecera de la sección

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: seccion.icono)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Paleta.sobre(seccion.color, prefs.tema.esquema ?? .light))
                .frame(width: 60, height: 60)
                .background(seccion.color,
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            Text(seccion.titulo)
                .font(.system(size: 25, weight: .bold))
                .padding(.top, 14)
            Text(seccion.descripcion)
                .font(.system(size: 14.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .tarjetaMac(18)
    }

    // MARK: - El contenido de cada sección

    @ViewBuilder
    private var contenido: some View {
        switch seccion {
        case .cuenta:       seccionCuenta
        case .iglesia:      seccionIglesia
        case .institucion:  seccionInstitucion
        case .tesorero:     seccionTesorero
        case .acceso:       seccionAcceso
        case .categorias:   seccionCategorias
        case .preferencias: seccionPreferencias
        case .zona:         seccionZona
        }
    }

    // MARK: Cuenta

    @ViewBuilder
    private var seccionCuenta: some View {
        Grupo {
            HStack(spacing: 16) {
                Text(sesion?.perfil.iniciales ?? "—")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Paleta.brand)
                    .frame(width: 66, height: 66)
                    .background(Paleta.brandFill, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(sesion?.perfil.firma ?? L.t("Sin sesión", "Signed out"))
                        .font(.system(size: 20, weight: .bold))
                    Text(sesion?.perfil.correo ?? "—")
                        .font(.system(size: 14.5)).foregroundStyle(.secondary)
                    Text(rolEscrito)
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        // **El estado de la sincronización, pegado al perfil.** Es el orden
        // del handoff, y tiene su razón: la primera pregunta de quien abre su
        // cuenta es si lo suyo está en algún sitio además de este Mac.
        Grupo {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15))
                    .foregroundStyle(motor.haFallado ? Paleta.negativo : Paleta.brand)
                Text(motor.estadoLegible)
                    .font(.system(size: 14.5))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
        }
        Grupo(titulo: L.t("APLICACIÓN", "APPLICATION")) {
            Fila(L.t("Versión", "Version"), VersionApp.completa)
        }
        if let s = sesion, s.modoSinConexion {
            Nota(L.t("La sesión se restauró sin conexión: lo que hable con el servidor fallará hasta que vuelva la red.",
                     "The session was restored offline: anything that talks to the server will fail until the network is back."))
        }

        // **El candado de ESTE Mac**, que no es lo mismo que "Acceso y áreas":
        // aquello decide quién entra al servidor de la iglesia, esto quién abre
        // esta app en este ordenador. Mismo texto que el iPad.
        Grupo(titulo: L.t("SEGURIDAD", "SECURITY")) {
            Interruptor(L.t("Pedir \(BloqueoBiometrico.nombreBiometria) al abrir",
                            "Require \(BloqueoBiometrico.nombreBiometria) to open"),
                        sub: L.t("También tapa las cuentas cuando el Mac se bloquea o se duerme la pantalla.",
                                 "Also covers the accounts when the Mac locks or the display sleeps."),
                        activo: $bloqueo.activo)
                .disabled(!biometria.puede)
        }
        Nota(pieSeguridad)

        // **Cerrar sesión y borrar la cuenta, aquí y no en la Zona de riesgo.**
        // La regla 5.1.1(v) de Apple pide que se pueda borrar la cuenta desde
        // dentro de la app y que se ENCUENTRE, y quien la busca la busca en
        // «Cuenta». Mismo sitio que en el iPhone y el iPad, por lo mismo.
        BotonRiesgo(L.t("Cerrar sesión", "Sign out"),
                    nota: L.t("Cerrar sesión no borra nada de este Mac: al volver a entrar, todo sigue donde estaba.",
                              "Signing out doesn't delete anything from this Mac: when you sign back in, everything is where it was."),
                    activo: sesion != nil) { confirmarCierre = true }
            .confirmationDialog(L.t("¿Cerrar sesión?", "Sign out?"),
                                isPresented: $confirmarCierre, titleVisibility: .visible) {
                Button(L.t("Cerrar sesión", "Sign out"), role: .destructive) {
                    Task { await sesion?.cerrarSesion() }
                }
                Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
            }

        BotonRiesgo(L.t("Borrar mi cuenta", "Delete my account"),
                    nota: BorradoDeCuenta.aviso, error: errorBorrado,
                    trabajando: borrando,
                    activo: sesion != nil && !borrando) { confirmarBorrado = true }
            .confirmationDialog(L.t("¿Borrar tu cuenta?", "Delete your account?"),
                                isPresented: $confirmarBorrado, titleVisibility: .visible) {
                Button(L.t("Sí, borrar mi cuenta", "Yes, delete my account"),
                       role: .destructive) { Task { await borrarCuenta() } }
                Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
            } message: {
                Text(BorradoDeCuenta.avisoCorto)
            }
    }

    /// Lo que el Mac puede pedir, dicho por su nombre. Si no puede, el motivo
    /// sustituye a la explicación: un interruptor apagado sin decir por qué
    /// manda a buscar un ajuste de Tamio que no existe.
    private var pieSeguridad: String {
        if let motivo = biometria.motivo { return motivo }
        return L.t("Si \(BloqueoBiometrico.nombreBiometria) no te reconoce, la contraseña del Mac también abre: nadie se queda fuera de su propia contabilidad.",
                   "If \(BloqueoBiometrico.nombreBiometria) doesn't recognize you, the Mac password also opens it: nobody gets locked out of their own books.")
    }

    /// Los avisos y los tres pasos viven en `BorradoDeCuenta`, junto a la
    /// sesión: el Mac, el iPad y el teléfono ofrecen lo mismo, y escrito tres
    /// veces se corrige uno y los otros se quedan mintiendo sobre una operación
    /// que no tiene vuelta atrás.
    private func borrarCuenta() async {
        borrando = true
        errorBorrado = nil
        do { try await BorradoDeCuenta.ejecutar(sesion) }
        catch { errorBorrado = error.localizedDescription }
        borrando = false
    }

    private var rolEscrito: String {
        guard let rol = sesion?.perfil.rol else { return L.t("Nadie ha entrado", "Nobody signed in") }
        switch rol {
        case .administrador: return L.t("Administrador", "Administrator")
        case .tesorero:      return L.t("Tesorero", "Treasurer")
        case .secretaria:    return L.t("Secretaría", "Secretary")
        }
    }

    // MARK: Iglesia

    private var seccionIglesia: some View {
        // `@Bindable` se declara DENTRO de cada sección y no se pasa como
        // parámetro: `Bindable<...>` no es el tipo del ViewModel, y el
        // compilador lo dice sin rodeos.
        @Bindable var cfg = cfg
        return Group {
        Grupo {
            HStack(spacing: 14) {
                // Con logo, el logo. Sin él, las iniciales de la IGLESIA sobre
                // el verde de marca, que es lo que va a salir en el papel
                // mientras no haya imagen.
                Group {
                    if let imagen = logo.imagen {
                        Image(nsImage: imagen)
                            .resizable().scaledToFit()
                            .padding(4)
                            .background(.quaternary.opacity(0.5),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Text(cfg.config.iniciales)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Paleta.sobreRelleno)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Paleta.brand,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("Logo de la iglesia", "Church logo"))
                        .font(.system(size: 15.5))
                    Text(logo.imagen == nil
                         ? L.t("Sale en el membrete de cartas, actas y reportes.",
                               "Appears on the letterhead of letters, minutes, and reports.")
                         : nombreDelLogo)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if logo.trabajando { ProgressView().controlSize(.small) }
                if logo.imagen != nil {
                    Button(L.t("Quitar", "Remove")) { confirmarQuitarLogo = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(Paleta.negativo)
                }
                Button(logo.imagen == nil ? L.t("Elegir…", "Choose…")
                                          : L.t("Reemplazar", "Replace")) { elegirLogo() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(Paleta.brand)
            }
            .padding(16)
            if let errorLogo {
                Text(errorLogo)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Paleta.negativo)
                    .padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
        // Nota del handoff, palabra por palabra: explica una regla que no se
        // deduce mirando la pantalla.
        Nota(L.t("El logo se guarda para toda la iglesia: sale en los documentos que genere cualquier aparato. Las firmas, en cambio, se quedan en el aparato donde se dibujan.",
                 "The logo is saved for the whole church: it appears on documents generated from any device. Signatures, on the other hand, stay on the device where they're drawn."))

        Grupo(titulo: L.t("DATOS DE LA IGLESIA", "CHURCH INFORMATION")) {
            Campo(L.t("Nombre", "Church name"), texto: $cfg.config.nombre)
            // **"(opcional)" en las cuatro, como el handoff.** No es adorno: el
            // nombre es el único que hace falta para el membrete, y sin la
            // marca parecen cinco casillas obligatorias.
            Campo(L.t("Ciudad (opcional)", "City (optional)"), texto: $cfg.config.ciudad)
            Campo(L.t("Estado o provincia (opcional)", "State/Province (optional)"),
                  texto: $cfg.config.estado)
            Campo(L.t("País (opcional)", "Country (optional)"), texto: $cfg.config.pais)
            Campo(L.t("Código postal (opcional)", "ZIP (optional)"),
                  texto: $cfg.config.codigoPostal, ultimo: true)
        }
        Grupo(titulo: L.t("FISCAL Y CONTABLE", "FISCAL & ACCOUNTING")) {
            Campo(L.t("Identificación fiscal", "Tax ID"), texto: $cfg.config.idFiscal)
            // Era una fila de solo lectura que enseñaba el CÓDIGO —"USD"— y no
            // dejaba cambiarlo; el handoff le pone chevron, o sea que se elige.
            // Las monedas son las del catálogo compartido, no una lista nueva.
            SelectorFila(L.t("Moneda", "Currency"), seleccion: $cfg.config.moneda,
                         opciones: Catalogos.monedas.map(\.codigo),
                         rotulo: { Catalogos.moneda($0).etiqueta })
            Campo(L.t("Saldo de apertura", "Opening balance"), texto: $aperturaTexto,
                  ultimo: true)
                .onSubmit { fijarApertura() }
        }
        Nota(L.t("El saldo inicial es el dinero que la tesorería ya tenía antes del primer movimiento registrado. No se suma al saldo en caja, que es el dinero todavía sin depositar.",
                 "The opening balance is money the treasury already had before the first recorded transaction. It is not added to cash on hand, which is money not yet deposited."))
        }
    }

    /// **El porcentaje que pide el handoff, calculado con la MISMA función que
    /// los reportes.**
    ///
    /// `composicion` es `porCategoria` de los ingresos del periodo, lo mismo
    /// que alimenta la dona de Reportes. Calcularlo aquí por separado sería
    /// pedir que dos pantallas de la misma app discrepen sobre el mismo mes.
    /// Vacío mientras no haya movimientos de esa categoría: un "0%" dice que se
    /// midió y salió cero, y no es lo mismo que no haber ingresado nada.
    private func porcentaje(_ nombre: String) -> String {
        guard let c = composicionDelMes.first(where: { $0.nombre == nombre }),
              totalDelMes > 0 else { return "" }
        let parte = Int((Double(c.monto) / Double(totalDelMes) * 100).rounded())
        return parte > 0 ? "\(parte)%" : ""
    }

    /// Lo que va a la derecha de una categoría: su parte del mes si la tiene, y
    /// si no, "Personalizada" cuando no es de fábrica —que es lo que el handoff
    /// pone en su "Building fund"—. **Sin chevron**: en el Mac todavía no hay
    /// pantalla de editar una categoría, y una flecha prometería una.
    private func valorDe(_ f: CategoriasViewModel.FilaCategoria) -> String {
        let parte = porcentaje(f.nombre)
        if !parte.isEmpty { return parte }
        return f.deFabrica ? "" : L.t("Personalizada", "Custom")
    }

    private var totalDelMes: Centavos {
        composicionDelMes.reduce(0) { $0 + $1.monto }
    }

    // MARK: El logo

    private var nombreDelLogo: String {
        let ruta = cfg.config.logoPath
        guard !ruta.isEmpty else { return "" }
        return (ruta as NSString).lastPathComponent
    }

    /// **El panel de archivos, no el carrete.** El iPhone abre `PhotosPicker`
    /// porque allí las imágenes viven en Fotos; en un Mac el logo de una
    /// iglesia está en una carpeta, y `PhotosPicker` ni existe aquí.
    private func elegirLogo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let imagen = NSImage(contentsOf: url) else {
            errorLogo = L.t("No se pudo leer esa imagen.", "That image couldn't be read.")
            return
        }
        Task {
            errorLogo = nil
            do {
                // La ruta se escribe DESPUÉS de que la subida salga bien:
                // guardarla antes dejaría a los demás aparatos buscando un
                // archivo que no llegó a existir.
                let nueva = try await logo.poner(imagen, reemplazando: cfg.config.logoPath)
                await cfg.fijarLogo(nueva)
            } catch { errorLogo = error.localizedDescription }
        }
    }

    private func quitarLogo() async {
        errorLogo = nil
        await logo.quitar(rutaAnterior: cfg.config.logoPath)
        await cfg.fijarLogo("")
    }

    // MARK: Firmas

    /// Cuál se está firmando ahora mismo; `nil` si no hay hoja abierta.
    @State private var firmando: FirmasLocales.Firmante?

    private var textoApertura: String {
        cfg.config.saldoInicial == 0 ? "" : Money.fmt(cfg.config.saldoInicial)
    }

    /// Lo tecleado se convierte a centavos y se vuelve a escribir formateado,
    /// así que en pantalla queda exactamente lo que se guardó. Si no se
    /// entiende, se deja lo anterior: un cero silencioso en una cifra de dinero
    /// es peor que no aceptar el texto. Misma regla que en el iPad.
    private func fijarApertura() {
        let limpio = aperturaTexto.trimmingCharacters(in: .whitespaces)
        if limpio.isEmpty {
            cfg.config.saldoInicial = 0
        } else if let centavos = Money.desdeTexto(limpio) {
            cfg.config.saldoInicial = centavos
        }
        aperturaTexto = textoApertura
    }

    // MARK: Institución

    private var seccionInstitucion: some View {
        @Bindable var cfg = cfg
        return Group {
        // **La previa del membrete, arriba del todo.** Es lo primero del
        // handoff en esta sección y contesta la única pregunta que tiene:
        // ¿cómo sale impreso lo que estoy escribiendo aquí abajo?
        Grupo {
            VStack(spacing: 12) {
                Text(cfg.config.nombre.isEmpty
                     ? L.t("Tu iglesia", "Your church") : cfg.config.nombre)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Paleta.brand)
                if !cfg.config.ubicacionLegible.isEmpty {
                    Text(cfg.config.ubicacionLegible)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Divider()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        Nota(L.t("Así se ve el membrete de los PDF con lo que hay escrito abajo.",
                 "This is how the PDF letterhead looks with what's written below."))

        Grupo(titulo: L.t("DATOS DEL MEMBRETE", "LETTERHEAD DATA")) {
            Campo(L.t("Dirección de la iglesia", "Church address"), texto: $cfg.config.direccion)
            // **Sale dos veces, aquí y en Iglesia, y es la MISMA columna.** Lo
            // pide así el handoff y así lo tiene el iPad: quien escribe el
            // membrete no debería tener que ir a otra sección a por la mitad.
            Campo(L.t("Estado / provincia", "State / province"), texto: $cfg.config.estado)
            Campo(L.t("Teléfono", "Phone"), texto: $cfg.config.telefono)
            Campo(L.t("Correo institucional", "Institutional email"), texto: $cfg.config.correo)
            Campo(L.t("Pie (opcional)", "Footer (optional)"), texto: $cfg.config.pieInstitucional)
            Campo(L.t("Nombre del secretario", "Secretary name"), texto: $cfg.config.secretarioNombre)
            Campo(L.t("Cargo", "Title"), texto: $cfg.config.secretarioCargo, ultimo: true)
        }
        Nota(L.t("Las casillas vacías no se imprimen: el membrete se cierra sin renglones en blanco.",
                 "Empty fields won't print — the letterhead closes without blank lines."))
        }
    }

    // MARK: Tesorero y pastor

    private var seccionTesorero: some View {
        @Bindable var cfg = cfg
        return Group {
        Grupo(titulo: L.t("TESORERO", "TREASURER")) {
            Campo(L.t("Nombre", "Full name"), texto: $cfg.config.tesoreroNombre)
            Campo(L.t("Cargo", "Title"), texto: $cfg.config.tesoreroCargo)
            Campo(L.t("Correo", "Email"), texto: $cfg.config.tesoreroCorreo)
            Campo(L.t("Teléfono", "Phone"), texto: $cfg.config.tesoreroTelefono, ultimo: true)
        }
        Grupo(titulo: L.t("PASTOR", "PASTOR")) {
            Campo(L.t("Nombre", "Full name"), texto: $cfg.config.pastorNombre)
            Campo(L.t("Cargo", "Title"), texto: $cfg.config.pastorCargo)
            Campo(L.t("Correo", "Email"), texto: $cfg.config.pastorCorreo)
            Campo(L.t("Teléfono", "Phone"), texto: $cfg.config.pastorTelefono, ultimo: true)
        }
        // **Las firmas son de ESTE Mac**, no de la iglesia: es la regla que el
        // propio handoff escribe al lado del logo —*"Signatures, on the other
        // hand, stay on the device where they're drawn"*— y la razón por la que
        // el respaldo se las lleva en su carpeta.
        Grupo(titulo: L.t("FIRMAS DE ESTE MAC", "SIGNATURES ON THIS MAC")) {
            FilaFirma(.tesorero, firmas: firmas) { firmando = .tesorero }
            FilaFirma(.pastor, firmas: firmas, ultimo: true) { firmando = .pastor }
        }
        Grupo {
            Interruptor(L.t("Imprimir las firmas en los PDF", "Print signatures on PDFs"),
                        sub: L.t("Apagado, el bloque de firmas no se imprime: ni raya, ni nombre, ni cargo.",
                                 "When off, the signature block isn't printed at all: no line, no name, no title."),
                        activo: $cfg.config.imprimirFirmas)
        }
        Nota(L.t("El correo y el teléfono de aquí son de la persona, no de la iglesia: esos van en Institución, que es lo que se imprime en el membrete.",
                 "Email and phone here belong to the person, not the church: those go in Institution, which is what prints on the letterhead."))
        }
    }

    // MARK: Acceso

    @ViewBuilder
    private var seccionAcceso: some View {
        Grupo(titulo: L.t("ÁREAS", "AREAS")) {
            Interruptor(L.t("El tesorero puede ver el padrón", "The treasurer can see the roster"),
                        sub: L.t("Membresía es la única parte de Secretaría a la que llega un tesorero.",
                                 "Membership is the only part of Secretary a treasurer can reach."),
                        activo: Binding(
                            get: { cfg.config.tesoreroVePadron },
                            set: { v in Task { _ = await cfg.fijarPermisos(vePadron: v,
                                puedeEliminar: cfg.config.tesoreroPuedeEliminar) } }))
            Interruptor(L.t("El tesorero puede eliminar movimientos", "The treasurer can delete transactions"),
                        sub: L.t("Con esto apagado, el servidor frena el borrado además de la app.",
                                 "With this off, the server blocks deletion as well as the app."),
                        activo: Binding(
                            get: { cfg.config.tesoreroPuedeEliminar },
                            set: { v in Task { _ = await cfg.fijarPermisos(
                                vePadron: cfg.config.tesoreroVePadron, puedeEliminar: v) } }))
        }
        // **Invitar a alguien**, tal cual lo pide el handoff. El envío lo hace
        // `Invitaciones.invitar`, la misma función que el iPhone: la llama una
        // función del servidor que crea la cuenta y manda el correo.
        Grupo(titulo: L.t("INVITAR A ALGUIEN", "INVITE SOMEONE")) {
            Campo(L.t("Correo", "Email"), texto: $invEmail)
            Campo(L.t("Nombre (opcional)", "Name (optional)"), texto: $invNom)
            SelectorFila(L.t("Rol", "Role"), seleccion: $invRol,
                         opciones: [.tesorero, .secretaria, .administrador],
                         rotulo: Self.rolCorto)
            FilaBoton(invitando ? L.t("Enviando…", "Sending…")
                                : L.t("Enviar invitación", "Send invitation"),
                      ultimo: true, activo: puedeInvitar) {
                Task { await invitar() }
            }
        }
        // **La nota dice qué verá QUIEN RECIBE, según el rol elegido**, y
        // cambia con el selector: decía siempre "Verá Tesorería" aunque se
        // invitara a Secretaría, y eso ya se arregló una vez en el iPhone.
        Nota(avisoInvitacion ?? (permisos.administraPermisos
             ? rolExplicado
             : L.t("Solo el administrador de la iglesia puede invitar.",
                   "Only the church administrator can invite people.")))

        // **La sincronización, donde la pone el handoff.** En el iPad vive en
        // la Zona de riesgo porque allí contesta "¿esto está en algún sitio
        // además de este aparato?"; aquí el diseño la quiso al lado de los
        // permisos, y es igual de cierta: las dos hablan de lo que sale de este
        // Mac hacia la iglesia.
        Grupo(titulo: L.t("SINCRONIZACIÓN", "SYNC")) {
            Fila(L.t("Estado", "Status"), motor.estadoLegible)
            // "Sin subir" y no "último cambio": lo que le importa a quien mira
            // esto es si algo suyo se quedó en el aparato.
            Fila(L.t("Sin subir", "Not uploaded"), motor.pendientesLegible)
            // **El handoff no dibuja este botón y entra igual.** Un estado que
            // dice "3 sin subir" y no deja hacer nada es un callejón; el iPhone
            // ya lo ofrece y la función es la misma.
            FilaBoton(L.t("Sincronizar ahora", "Sync now"),
                      ultimo: true, activo: motor.puedeSincronizar) {
                Task { await motor.sincronizar(reintentarLoAtascado: true) }
            }
        }

        Grupo(titulo: L.t("PLAN", "PLAN")) {
            Fila(L.t("Plan", "Plan"), cfg.config.planLegible)
            // Los rótulos del web, no las claves: salía «cortesia» y la fecha
            // en crudo («2027-03-12»).
            Fila(L.t("Estado", "Status"), cfg.config.estadoSuscripcionLegible)
            Fila(L.t("Vence", "Renews"), cfg.config.venceLegible ?? "—", ultimo: true)
        }
        Nota(L.t("Estos permisos no son solo de la app: el servidor los aplica también, así que cambiarlos aquí cambia lo que se puede hacer desde cualquier aparato.",
                 "These permissions aren't only in the app: the server enforces them too, so changing them here changes what can be done from any device."))
    }

    private var permisos: Permisos {
        Permisos(rol: sesion?.perfil.rol ?? .administrador, iglesia: cfg.config)
    }

    private var puedeInvitar: Bool {
        permisos.administraPermisos && !invitando && invEmail.contains("@")
    }

    /// Qué verá quien reciba la invitación, según el rol elegido.
    private var rolExplicado: String {
        switch invRol {
        case .tesorero:
            return L.t("Verá Tesorería: ingresos, gastos, depósitos y reportes.",
                       "They'll see Treasury: income, expenses, deposits, and reports.")
        case .secretaria:
            return L.t("Verá Secretaría: padrón, actas, servicios y cartas.",
                       "They'll see Secretary: roster, minutes, services, and letters.")
        case .administrador:
            return L.t("Verá todo, y podrá invitar a otros y cambiar los permisos.",
                       "They'll see everything, and can invite others and change permissions.")
        }
    }

    /// El nombre corto de un rol, para el selector. `AjustesRol` hace esto
    /// mismo en iOS y no se puede reusar: vive en `Tamio/Views`, que el Mac no
    /// compila.
    static func rolCorto(_ rol: SesionSupabase.Perfil.Rol) -> String {
        switch rol {
        case .tesorero:      return L.t("Tesorero", "Treasurer")
        case .secretaria:    return L.t("Secretaría", "Secretary")
        case .administrador: return L.t("Administrador", "Administrator")
        }
    }

    private func invitar() async {
        invitando = true
        avisoInvitacion = nil
        do {
            let r = try await Invitaciones.invitar(correo: invEmail, nombre: invNom, rol: invRol)
            avisoInvitacion = r.mensaje
            invEmail = ""
            invNom = ""
        } catch {
            avisoInvitacion = error.localizedDescription
        }
        invitando = false
    }

    // MARK: Categorías

    @ViewBuilder
    private var seccionCategorias: some View {
        Grupo(titulo: L.t("INGRESOS", "INCOME")) {
            let filas = categorias.filas(.ingreso)
            ForEach(Array(filas.enumerated()), id: \.offset) { i, f in
                FilaCategoriaVista(nombre: f.nombre, valor: valorDe(f),
                                   ultimo: i == filas.count - 1)
            }
        }
        Grupo(titulo: L.t("GASTOS", "EXPENSES")) {
            let filas = categorias.filas(.gasto)
            ForEach(Array(filas.enumerated()), id: \.offset) { i, f in
                FilaCategoriaVista(nombre: f.nombre, valor: valorDe(f),
                                   ultimo: i == filas.count - 1)
            }
        }
        Nota(L.t("Las categorías se comparten con la app web: renombrar una aquí la renombra en todos los reportes y PDF.",
                 "Categories are shared with the web app: renaming one here renames it in every report and PDF."))
    }

    // MARK: Preferencias

    @ViewBuilder
    private var seccionPreferencias: some View {
        @Bindable var prefs = prefs
        Grupo(titulo: L.t("APARIENCIA", "APPEARANCE")) {
            SelectorFila(L.t("Tema", "Theme"), seleccion: $prefs.tema,
                         opciones: PreferenciasApp.Tema.allCases, rotulo: \.etiqueta)
        }
        Grupo(titulo: L.t("GENERAL", "GENERAL")) {
            SelectorFila(L.t("Idioma", "Language"), seleccion: $prefs.idioma,
                         opciones: PreferenciasApp.Idioma.allCases, rotulo: \.etiqueta)
            SelectorFila(L.t("Tamaño del texto", "Text size"), seleccion: $prefs.tamano,
                         opciones: PreferenciasApp.Tamano.allCases, rotulo: \.etiqueta,
                         ultimo: true)
        }
        Nota(L.t("Tamio sigue la apariencia que elijas aquí, no la del sistema: las tesoreras trabajan a menudo en un salón iluminado con la pantalla oscura.",
                 "Tamio follows the appearance you pick here, not the system one — treasurers often work in a lit hall with a dark screen."))
    }

    // MARK: Zona de riesgo

    @ViewBuilder
    private var seccionZona: some View {
        Grupo(titulo: L.t("ESTE APARATO", "THIS MAC")) {
            Fila(L.t("Base local", "Local database"),
                 BaseLocal.caida == nil ? L.t("En disco", "On disk")
                                        : L.t("En memoria", "In memory"), ultimo: true)
        }

        Grupo(titulo: L.t("RESPALDO", "BACKUP")) {
            // "Preparado" y no "guardado": la app sabe que hizo el paquete, no
            // si quien lo guardó llegó a elegir dónde ponerlo.
            Fila(L.t("Último respaldo preparado", "Last backup prepared"), ultimoRespaldo)
            Interruptor(L.t("Proteger con una contraseña", "Protect with a password"),
                        sub: L.t("Sin ella, el paquete es un zip que abre cualquiera con acceso al archivo.",
                                 "Without it, the package is a zip anyone with the file can open."),
                        activo: $protegerRespaldo)
            if protegerRespaldo {
                CampoSecreto(L.t("Contraseña", "Password"), texto: $contrasenaRespaldo)
            }
            FilaBoton(L.t("Preparar un respaldo…", "Prepare a backup…"),
                      activo: !trabajando) { Task { await respaldar() } }
            FilaBoton(L.t("Exportar movimientos (CSV)", "Export transactions (CSV)"),
                      valor: cuentaLegible(cuantosMovimientos, L.t("movimientos", "records")),
                      activo: !trabajando) { Task { await exportar(.movimientos) } }
            FilaBoton(L.t("Exportar aportantes (CSV)", "Export contributors (CSV)"),
                      valor: cuentaLegible(cuantosAportantes, L.t("aportantes", "records")),
                      ultimo: true, activo: !trabajando) { Task { await exportar(.aportantes) } }
        }
        // **El handoff dice aquí que "el respaldo va cifrado con la clave de la
        // iglesia", y hoy no es verdad**: va cifrado solo si se pide arriba, y
        // la contraseña la elige quien lo hace, no la iglesia. Una nota que
        // promete un cifrado que no existe es peor que no tener nota, así que
        // se escribe la regla de verdad — y la mitad que sí vale del handoff:
        // el que lo protege necesita esa misma contraseña para restaurarlo.
        Nota(L.t("El respaldo lleva la base entera y los recibos. Si lo proteges, restaurarlo en otro Mac pide esa misma contraseña, y no hay forma de recuperarla. Los CSV son para abrirlos en una hoja de cálculo.",
                 "The backup includes the whole database and the receipts. If you protect it, restoring it on another Mac needs that same password, and there's no way to recover it. The CSVs are for opening in a spreadsheet."))

        Grupo(titulo: L.t("MANTENIMIENTO", "MAINTENANCE")) {
            FilaBoton(L.t("Compactar la base", "Compact the database"),
                      valor: tamanoDeLaBase,
                      activo: !trabajando && (estadoBase?.filasPurgables ?? 0) > 0) {
                confirmarPurgar = true
            }
            FilaBoton(L.t("Restaurar desde un respaldo…", "Restore from a backup…"),
                      ultimo: true, activo: !trabajando) { elegirRespaldo() }
        }
        Nota(L.t("Lo que se borra queda marcado y sigue ocupando sitio: es lo que permite que la baja llegue a los demás aparatos. Al compactar se va de verdad lo que lleve más de \(Compactacion.diasParaPurgar) días borrado y ya haya subido. Los apuntes del Registro nunca se tocan.",
                 "Deleted items stay marked and keep taking space: that's what lets the deletion reach other devices. Compacting permanently removes what has been deleted for more than \(Compactacion.diasParaPurgar) days and has already been uploaded. Log entries are never touched."))

        BotonRiesgo(L.t("Borrar los datos de este Mac", "Erase the data on this Mac"),
                    nota: L.t("Se lleva la copia local y todo lo que no se haya sincronizado todavía, incluida la cola de salida. Tu cuenta y lo que está en el servidor de la iglesia se quedan.",
                              "This removes the local copy and everything that has not synced yet, including the outbox. Your account and the church's server data stay."),
                    error: errorZona, trabajando: trabajando, activo: !trabajando) {
            confirmarReinicio = true
        }
        .confirmationDialog(L.t("¿Borrar los datos de este Mac?", "Erase the data on this Mac?"),
                            isPresented: $confirmarReinicio, titleVisibility: .visible) {
            Button(L.t("Borrar", "Erase"), role: .destructive) { Task { await reiniciar() } }
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
        } message: {
            Text(L.t("Este Mac queda como recién instalado y se cierra la sesión. Lo que está en el servidor NO se borra.",
                     "This Mac is left as newly installed and the session is closed. What's on the server is NOT deleted."))
        }
        .confirmationDialog(L.t("¿Compactar la base?", "Compact the database?"),
                            isPresented: $confirmarPurgar, titleVisibility: .visible) {
            Button(L.t("Compactar", "Compact"), role: .destructive) { Task { await purgar() } }
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
        } message: {
            Text(L.t("Se van de verdad \(estadoBase?.filasPurgables ?? 0) registros que llevan más de \(Compactacion.diasParaPurgar) días borrados y ya subieron. No se pueden recuperar ni desde otro aparato.",
                     "\(estadoBase?.filasPurgables ?? 0) records deleted for more than \(Compactacion.diasParaPurgar) days and already uploaded will be permanently removed. They can't be recovered, not even from another device."))
        }
        .confirmationDialog(tituloRestaurar, isPresented: Binding(
            get: { porRestaurar != nil }, set: { if !$0 { porRestaurar = nil } }),
                            titleVisibility: .visible) {
            Button(L.t("Restaurar", "Restore"), role: .destructive) {
                if let u = porRestaurar?.url { Task { await restaurar(u) } }
            }
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { porRestaurar = nil }
        } message: {
            if let m = porRestaurar?.manifiesto { Text(ResumenRespaldo.frase(m)) }
        }
        .alert(L.t("Listo", "Done"), isPresented: Binding(
            get: { hecho != nil }, set: { if !$0 { hecho = nil } })) {
            Button("OK", role: .cancel) { hecho = nil }
        } message: {
            if let hecho { Text(hecho) }
        }
        .task {
            estadoBase = await Compactacion.medir()
            await contarLoExportable()
        }
    }

    // MARK: Zona de riesgo · lo que hace cada botón

    private enum Exportacion { case movimientos, aportantes }

    private var tamanoDeLaBase: String {
        guard let e = estadoBase else { return "—" }
        return Compactacion.legible(e.bytesBase)
    }

    private var tituloRestaurar: String {
        L.t("¿Restaurar este respaldo?", "Restore this backup?")
    }

    /// "14 movimientos", o un guion mientras se cuentan. El handoff pone la
    /// cifra en la fila: sin ella, exportar es una apuesta a ciegas —y un CSV
    /// vacío no se distingue de un fallo—.
    private func cuentaLegible(_ n: Int?, _ que: String) -> String {
        guard let n else { return "—" }
        return "\(n) \(que)"
    }

    private func contarLoExportable() async {
        let repo = repositorioMovimientos()
        let movs = ((try? await repo.lista(tipo: .ingreso)) ?? []).count
            + ((try? await repo.lista(tipo: .gasto)) ?? []).count
        // `.todos`: un respaldo sin las bajas no es el padrón, es una foto de
        // los activos de hoy.
        let gente = ((try? await repositorioMiembros().lista(filtro: .todos)) ?? []).count
        cuantosMovimientos = movs
        cuantosAportantes = gente
    }

    private func respaldar() async {
        trabajando = true; errorZona = nil
        do {
            let url = try await Respaldo.crear(
                protegidoCon: protegerRespaldo ? contrasenaRespaldo : nil)
            Respaldo.anotarHecho()
            ultimoRespaldo = Respaldo.ultimoLegible
            guardar(url, como: url.lastPathComponent)
        } catch { errorZona = error.localizedDescription }
        trabajando = false
    }

    private func exportar(_ que: Exportacion) async {
        trabajando = true; errorZona = nil
        switch que {
        case .movimientos:
            let repo = repositorioMovimientos()
            let todos = ((try? await repo.lista(tipo: .ingreso)) ?? [])
                + ((try? await repo.lista(tipo: .gasto)) ?? [])
            if todos.isEmpty {
                errorZona = L.t("No hay movimientos que exportar.",
                                "There are no transactions to export.")
            } else if let url = ExportadorMovimientos.csv(todos) {
                guardar(url, como: url.lastPathComponent)
            }
        case .aportantes:
            let lista = (try? await repositorioMiembros().lista(filtro: .todos)) ?? []
            if lista.isEmpty {
                errorZona = L.t("No hay aportantes que exportar.",
                                "There are no contributors to export.")
            } else if let url = ExportadorAportantes.aportantes(lista) {
                guardar(url, como: url.lastPathComponent)
            }
        }
        trabajando = false
    }

    /// **En el Mac no se "comparte": se guarda donde uno diga.** El iPhone abre
    /// la hoja de compartir porque allí no hay Finder; aquí el gesto es el
    /// panel de guardar de siempre, y el archivo que preparamos se copia
    /// encima del destino elegido.
    private func guardar(_ origen: URL, como nombre: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = nombre
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destino = panel.url else { return }
        do {
            try? FileManager.default.removeItem(at: destino)
            try FileManager.default.copyItem(at: origen, to: destino)
        } catch { errorZona = error.localizedDescription }
    }

    private func elegirRespaldo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await inspeccionar(url) }
    }

    /// **Se mira el manifiesto ANTES de restaurar**, que es lo que deja
    /// preguntar "¿de qué iglesia y de qué día es este paquete?" en vez de
    /// "¿seguro?". Un respaldo protegido no se puede inspeccionar sin su
    /// contraseña: entonces se pide la misma que esté escrita arriba.
    private func inspeccionar(_ url: URL) async {
        trabajando = true; errorZona = nil
        let clave = Respaldo.pideContrasena(url) ? contrasenaRespaldo : nil
        do {
            porRestaurar = (url, try await Respaldo.inspeccionar(url, contrasena: clave))
        } catch {
            errorZona = Respaldo.pideContrasena(url) && (clave ?? "").isEmpty
                ? L.t("Ese respaldo está protegido: escribe su contraseña arriba y vuelve a elegirlo.",
                      "That backup is protected: type its password above and pick it again.")
                : error.localizedDescription
        }
        trabajando = false
    }

    private func restaurar(_ url: URL) async {
        porRestaurar = nil
        trabajando = true; errorZona = nil
        let clave = Respaldo.pideContrasena(url) ? contrasenaRespaldo : nil
        do {
            let m = try await Respaldo.restaurar(url, contrasena: clave)
            hecho = L.t("Restaurado el respaldo de \(m.iglesia).",
                        "Restored the backup from \(m.iglesia).")
        } catch { errorZona = error.localizedDescription }
        trabajando = false
        estadoBase = await Compactacion.medir()
        await contarLoExportable()
    }

    private func purgar() async {
        trabajando = true; errorZona = nil
        do {
            let r = try await Compactacion.purgar()
            hecho = r.bytesLiberados > 0
                ? L.t("Se fueron \(r.filas) registros y se liberaron \(Compactacion.legible(r.bytesLiberados)).",
                      "\(r.filas) records removed, \(Compactacion.legible(r.bytesLiberados)) freed.")
                : L.t("Se fueron \(r.filas) registros. El archivo no encogió: SQLite reutilizará ese hueco.",
                      "\(r.filas) records removed. The file didn't shrink: SQLite will reuse that space.")
        } catch { errorZona = error.localizedDescription }
        trabajando = false
        estadoBase = await Compactacion.medir()
    }

    private func reiniciar() async {
        trabajando = true; errorZona = nil
        do {
            try await BorradoMasivo.reinicioDeFabrica()
            await sesion?.cerrarSesion()
        } catch { errorZona = error.localizedDescription }
        trabajando = false
    }
}

// MARK: - Las piezas de una hoja de ajustes

/// Un grupo de filas, con su rótulo opcional. Es la tarjeta de
/// `ConfiguracionView` traducida al Mac: mismo radio, mismo fondo.
struct Grupo<C: View>: View {
    var titulo: String? = nil
    @ViewBuilder let contenido: () -> C

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let titulo {
                Text(titulo)
                    .font(.system(size: 12, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
            }
            VStack(spacing: 0) { contenido() }
                .tarjetaMac(18)
        }
    }
}

/// Un renglón de solo lectura.
struct Fila: View {
    let rotulo: String
    let valor: String
    var ultimo = false
    init(_ r: String, _ v: String, ultimo: Bool = false) {
        rotulo = r; valor = v; self.ultimo = ultimo
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(rotulo).font(.system(size: 15.5))
                Spacer(minLength: 12)
                Text(valor)
                    .font(.system(size: 15.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            if !ultimo { Divider().padding(.leading, 16) }
        }
    }
}

/// Un renglón que se puede escribir. **Guarda solo cuando se sale de la
/// casilla**: `ConfiguracionIglesiaViewModel` ya reprograma el guardado a cada
/// cambio, y escribir letra a letra dispararía una subida por tecla.
struct Campo: View {
    let rotulo: String
    @Binding var texto: String
    var ultimo = false
    init(_ r: String, texto: Binding<String>, ultimo: Bool = false) {
        rotulo = r; _texto = texto; self.ultimo = ultimo
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(rotulo)
                    .font(.system(size: 15.5))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                TextField("", text: $texto)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15.5))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            if !ultimo { Divider().padding(.leading, 16) }
        }
    }
}

/// Como `Campo`, pero lo que se teclea no se lee por encima del hombro. Solo lo
/// usa la contraseña del respaldo, que es la única de esta pantalla.
struct CampoSecreto: View {
    let rotulo: String
    @Binding var texto: String
    var ultimo = false
    init(_ r: String, texto: Binding<String>, ultimo: Bool = false) {
        rotulo = r; _texto = texto; self.ultimo = ultimo
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(rotulo)
                    .font(.system(size: 15.5))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                SecureField("", text: $texto)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15.5))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            if !ultimo { Divider().padding(.leading, 16) }
        }
    }
}

struct Interruptor: View {
    let rotulo: String
    let sub: String
    @Binding var activo: Bool
    init(_ r: String, sub: String, activo: Binding<Bool>) {
        rotulo = r; self.sub = sub; _activo = activo
    }
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rotulo).font(.system(size: 16))
                Text(sub)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $activo).labelsHidden().toggleStyle(.switch)
        }
        .padding(16)
    }
}

struct SelectorFila<T: Hashable>: View {
    let rotulo: String
    @Binding var seleccion: T
    let opciones: [T]
    let etiqueta: (T) -> String
    var ultimo = false

    init(_ r: String, seleccion: Binding<T>, opciones: [T],
         rotulo etiqueta: @escaping (T) -> String, ultimo: Bool = false) {
        self.rotulo = r; _seleccion = seleccion; self.opciones = opciones
        self.etiqueta = etiqueta; self.ultimo = ultimo
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(rotulo).font(.system(size: 15.5))
                Spacer(minLength: 12)
                Picker("", selection: $seleccion) {
                    ForEach(opciones, id: \.self) { Text(etiqueta($0)).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            if !ultimo { Divider().padding(.leading, 16) }
        }
    }
}

struct FilaCategoriaVista: View {
    let nombre: String
    var valor: String = ""
    var ultimo = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Paleta.categoria(Catalogos.clave(deEtiqueta: nombre), nombre: nombre))
                    .frame(width: 10, height: 10)
                Text(nombre).font(.system(size: 15.5))
                Spacer(minLength: 0)
                if !valor.isEmpty {
                    Text(valor)
                        .font(.system(size: 15.5))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 46)
            if !ultimo { Divider().padding(.leading, 16) }
        }
    }
}

/// **Una acción de las que no se deshacen, con su explicación debajo.**
///
/// Es el `sAction` del handoff: una tarjeta del ancho de la columna, el rótulo
/// en rojo centrado, y la nota fuera. No lleva chevron porque no lleva a
/// ninguna parte —pregunta y actúa—, y todas las que hay preguntan antes.
struct BotonRiesgo: View {
    let rotulo: String
    let nota: String
    var error: String? = nil
    var trabajando = false
    var activo = true
    let accion: () -> Void

    init(_ r: String, nota: String, error: String? = nil, trabajando: Bool = false,
         activo: Bool = true, accion: @escaping () -> Void) {
        rotulo = r; self.nota = nota; self.error = error
        self.trabajando = trabajando; self.activo = activo; self.accion = accion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: accion) {
                Group {
                    if trabajando {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(rotulo)
                            .font(.system(size: 15.5))
                            .foregroundStyle(activo ? Paleta.negativo : Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .tarjetaMac(18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!activo)
            if let error {
                Text(error)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Paleta.negativo)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            Nota(nota)
        }
    }
}

/// Un renglón que hace algo: exportar, restaurar, liberar espacio. El rótulo va
/// en verde de marca cuando se puede pulsar —es lo que lo distingue de una
/// `Fila`, que solo informa— y en gris cuando no.
struct FilaBoton: View {
    let rotulo: String
    var valor: String = ""
    var ultimo = false
    var activo = true
    let accion: () -> Void

    init(_ r: String, valor: String = "", ultimo: Bool = false,
         activo: Bool = true, accion: @escaping () -> Void) {
        rotulo = r; self.valor = valor; self.ultimo = ultimo
        self.activo = activo; self.accion = accion
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: accion) {
                HStack {
                    Text(rotulo)
                        .font(.system(size: 15.5))
                        // Un solo `foregroundStyle` con la condición dentro:
                        // encadenar dos deja el color a merced del orden, y
                        // está medido en el iPad que salían los dos verdes.
                        .foregroundStyle(activo ? AnyShapeStyle(Paleta.brand)
                                                : AnyShapeStyle(.primary.opacity(0.7)))
                    Spacer(minLength: 12)
                    if !valor.isEmpty {
                        Text(valor)
                            .font(.system(size: 15.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!activo)
            if !ultimo { Divider().padding(.leading, 16) }
        }
    }
}

/// El texto explicativo de debajo de un grupo.
struct Nota: View {
    let texto: String
    init(_ t: String) { texto = t }
    var body: some View {
        Text(texto)
            .font(.system(size: 12.5))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
    }
}

// MARK: - Las firmas, en el Mac

/// La fila de una firma: su nombre, si la hay, y la miniatura de lo dibujado.
struct FilaFirma: View {
    let firmante: FirmasLocales.Firmante
    let firmas: FirmasLocales
    var ultimo = false
    let accion: () -> Void

    init(_ f: FirmasLocales.Firmante, firmas: FirmasLocales,
         ultimo: Bool = false, accion: @escaping () -> Void) {
        firmante = f; self.firmas = firmas; self.ultimo = ultimo; self.accion = accion
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: accion) {
                HStack(spacing: 12) {
                    Text(firmante.titulo).font(.system(size: 15.5))
                    Spacer(minLength: 12)
                    if let imagen = firmas.imagen(firmante) {
                        // **La miniatura y no solo la palabra "Guardada".** Una
                        // firma se reconoce mirándola; con el rótulo solo, la
                        // del pastor y la del tesorero cambiadas de sitio no se
                        // notarían hasta ver el PDF.
                        Image(nsImage: imagen)
                            .resizable().scaledToFit()
                            .frame(height: 26)
                            .frame(maxWidth: 140)
                    }
                    Text(firmas.tiene(firmante)
                         ? L.t("Cambiar", "Replace")
                         : L.t("Firmar", "Sign"))
                        .font(.system(size: 15.5))
                        .foregroundStyle(Paleta.brand)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !ultimo { Divider().padding(.leading, 16) }
        }
    }
}

/// **Firmar con el trackpad, que es como se firma en un Mac.**
///
/// El iPhone y el iPad usan `PKCanvasView` de PencilKit, que no existe aquí, así
/// que el lienzo es propio: se guardan los trazos como listas de puntos y se
/// pintan con `Canvas`. Es lo mismo que hace Vista Previa para capturar una
/// firma, y da el mismo resultado —un PNG con el trazo y el fondo transparente—
/// que es lo único que el PDF necesita.
///
/// **Se recorta antes de guardar, y NADA MÁS.** Una rúbrica pequeña hecha en
/// una esquina saldría diminuta dentro del hueco del PDF, que se ajusta al alto
/// disponible; por eso el recorte.
///
/// **Lo que NO se le pasa es `sinFondo`**, aunque esté ahí al lado y suene a lo
/// que uno quiere. Esa función es para una FOTO de una firma en papel: mete la
/// imagen en un contexto de grises sin canal alfa y convierte lo oscuro en
/// tinta. Un dibujo que ya nace transparente entra con el fondo valiendo cero
/// —o sea, negro— y sale un rectángulo negro macizo. Medido aquí: la primera
/// firma guardada en el Mac salió así en la miniatura de la fila.
struct HojaFirmaMac: View {
    let firmante: FirmasLocales.Firmante
    let firmas: FirmasLocales
    @Environment(\.dismiss) private var cerrar

    @State private var trazos: [[CGPoint]] = []
    @State private var actual: [CGPoint] = []
    @State private var error: String?

    /// El lienzo en puntos. Ancho de firma de documento: el recorte se encarga
    /// de que firmar pequeño no salga pequeño.
    private let ancho: CGFloat = 520
    private let alto: CGFloat = 200

    private var hayAlgo: Bool { !trazos.isEmpty || actual.count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(firmante.titulo).font(.system(size: 13.5, weight: .semibold))
                Spacer(minLength: 0)
                Button(L.t("Cerrar", "Close")) { cerrar() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Paleta.enlace)
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(L.t("Firma con el trackpad o el ratón, manteniendo pulsado.",
                         "Sign with the trackpad or mouse, holding the button down."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)

                lienzo

                Text(L.t("La firma se queda en este Mac. El respaldo se la lleva; la sincronización no.",
                         "The signature stays on this Mac. A backup takes it along; syncing doesn't."))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                if let error {
                    Text(error).font(.system(size: 12)).foregroundStyle(Paleta.negativo)
                }
            }
            .padding(18)

            Divider()
            HStack(spacing: 9) {
                if firmas.tiene(firmante) {
                    Button(L.t("Borrar la guardada", "Delete the saved one"), role: .destructive) {
                        firmas.borrar(firmante)
                        cerrar()
                    }
                }
                Spacer(minLength: 0)
                Button(L.t("Empezar de nuevo", "Start over")) {
                    trazos = []; actual = []
                }
                .disabled(!hayAlgo)
                Button(L.t("Guardar la firma", "Save the signature")) { guardar() }
                    .buttonStyle(.borderedProminent)
                    .tint(Paleta.brand)
                    .disabled(!hayAlgo)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .frame(width: 560)
    }

    private var lienzo: some View {
        Canvas { ctx, _ in
            for t in trazos + [actual] { ctx.stroke(camino(t), with: .color(.black),
                                                    style: trazoFino) }
        }
        .frame(width: ancho, height: alto)
        // Blanco siempre, también en modo oscuro: se está mirando el papel, no
        // la app. Es la misma regla que `HojaCarta`.
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.25))
                .frame(height: 1)
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
        }
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(.quaternary, lineWidth: 1))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in actual.append(g.location) }
                .onEnded { _ in
                    // Un clic suelto no es un trazo: dejaría un punto en el
                    // PNG y el recorte lo trataría como dibujo.
                    if actual.count > 1 { trazos.append(actual) }
                    actual = []
                }
        )
    }

    private var trazoFino: StrokeStyle {
        StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
    }

    private func camino(_ puntos: [CGPoint]) -> Path {
        var p = Path()
        guard let primero = puntos.first else { return p }
        p.move(to: primero)
        for punto in puntos.dropFirst() { p.addLine(to: punto) }
        return p
    }

    /// **Se pinta en un `NSBitmapImageRep` propio y ya a escala, no con
    /// `lockFocus`.**
    ///
    /// Dos trampas, las dos medidas aquí y las dos con el mismo síntoma —la
    /// firma guardada a 1×, pixelada en el PDF—:
    ///
    /// - `lockFocus` **añade una representación nueva** a la escala de la
    ///   pantalla y dibuja en ella, así que la de 3× que se le hubiera puesto a
    ///   la imagen se queda sin usar.
    /// - Y una `NSImage` de 520×200 puntos con una representación de 1560×600
    ///   píxeles **se rasteriza a 520×200** al pedirle su `CGImage`
    ///   (`cgImage(forProposedRect: nil, …)`, que es lo que hacen `recortada` y
    ///   `datosPNG`). En iOS no pasa porque `UIImage.cgImage` es el bitmap de
    ///   verdad; aquí el punto y el píxel se separan y gana el punto.
    ///
    /// Por eso el bitmap es de 1× y grande —los trazos se escalan al
    /// dibujarlos—, y el margen del recorte se escala con ellos para que la
    /// firma quede enmarcada igual que en el teléfono.
    private func guardar() {
        let escala: CGFloat = 3
        let anchoPx = Int(ancho * escala), altoPx = Int(alto * escala)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: anchoPx, pixelsHigh: altoPx,
                                         bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            error = L.t("No se pudo preparar la firma.",
                        "The signature could not be prepared.")
            return
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        NSColor.black.setStroke()
        for t in trazos {
            guard let primero = t.first else { continue }
            let ruta = NSBezierPath()
            ruta.lineWidth = 2.2 * escala
            ruta.lineCapStyle = .round
            ruta.lineJoinStyle = .round
            // El eje Y de AppKit va al revés que el de SwiftUI.
            ruta.move(to: NSPoint(x: primero.x * escala, y: (alto - primero.y) * escala))
            for punto in t.dropFirst() {
                ruta.line(to: NSPoint(x: punto.x * escala, y: (alto - punto.y) * escala))
            }
            ruta.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()

        let imagen = NSImage(size: NSSize(width: anchoPx, height: altoPx))
        imagen.addRepresentation(rep)

        do {
            try firmas.guardar(FirmasLocales.recortada(imagen, margen: 12 * escala),
                               para: firmante)
            cerrar()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
