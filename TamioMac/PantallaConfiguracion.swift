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
    @State private var prefs = PreferenciasApp.compartidas
    @State private var categorias = CategoriasViewModel.compartido
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    var body: some View {
        HSplitView {
            barra.frame(minWidth: 240, idealWidth: 300, maxWidth: 360)
            ScrollView {
                VStack(spacing: 24) {
                    cabecera
                    contenido
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fondoAgrupado)
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
        .background(.background.secondary,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        Grupo(titulo: L.t("APLICACIÓN", "APPLICATION")) {
            Fila(L.t("Versión", "Version"), VersionApp.completa)
        }
        if let s = sesion, s.modoSinConexion {
            Nota(L.t("La sesión se restauró sin conexión: lo que hable con el servidor fallará hasta que vuelva la red.",
                     "The session was restored offline: anything that talks to the server will fail until the network is back."))
        }
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
        Grupo(titulo: L.t("DATOS DE LA IGLESIA", "CHURCH INFORMATION")) {
            Campo(L.t("Nombre", "Church name"), texto: $cfg.config.nombre)
            Campo(L.t("Ciudad", "City"), texto: $cfg.config.ciudad)
            Campo(L.t("Estado o provincia", "State/Province"), texto: $cfg.config.estado)
            Campo(L.t("País", "Country"), texto: $cfg.config.pais)
            Campo(L.t("Código postal", "ZIP"), texto: $cfg.config.codigoPostal, ultimo: true)
        }
        Grupo(titulo: L.t("FISCAL Y CONTABLE", "FISCAL & ACCOUNTING")) {
            Campo(L.t("Identificación fiscal", "Tax ID"), texto: $cfg.config.idFiscal)
            Fila(L.t("Moneda", "Currency"), cfg.config.moneda)
            Fila(L.t("Saldo inicial", "Opening balance"),
                 Money.fmt(cfg.config.saldoInicial), ultimo: true)
        }
        Nota(L.t("El saldo inicial es el dinero que la tesorería ya tenía antes del primer movimiento registrado. No se suma al saldo en caja, que es el dinero todavía sin depositar.",
                 "The opening balance is money the treasury already had before the first recorded transaction. It is not added to cash on hand, which is money not yet deposited."))
        }
    }

    // MARK: Institución

    private var seccionInstitucion: some View {
        @Bindable var cfg = cfg
        return Group {
        Grupo(titulo: L.t("DATOS DEL MEMBRETE", "LETTERHEAD DATA")) {
            Campo(L.t("Dirección", "Address"), texto: $cfg.config.direccion)
            Campo(L.t("Teléfono", "Phone"), texto: $cfg.config.telefono)
            Campo(L.t("Correo institucional", "Institutional email"), texto: $cfg.config.correo)
            Campo(L.t("Pie (opcional)", "Footer (optional)"), texto: $cfg.config.pieInstitucional)
            Campo(L.t("Secretario", "Secretary"), texto: $cfg.config.secretarioNombre)
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
        Grupo(titulo: L.t("PLAN", "PLAN")) {
            Fila(L.t("Plan", "Plan"), cfg.config.planLegible)
            Fila(L.t("Estado", "Status"),
                 cfg.config.subEstado.isEmpty ? "—" : cfg.config.subEstado)
            Fila(L.t("Vence", "Renews"),
                 cfg.config.subVence.isEmpty ? "—" : cfg.config.subVence, ultimo: true)
        }
        Nota(L.t("Estos permisos no son solo de la app: el servidor los aplica también, así que cambiarlos aquí cambia lo que se puede hacer desde cualquier aparato.",
                 "These permissions aren't only in the app: the server enforces them too, so changing them here changes what can be done from any device."))
    }

    // MARK: Categorías

    @ViewBuilder
    private var seccionCategorias: some View {
        Grupo(titulo: L.t("INGRESOS", "INCOME")) {
            let filas = categorias.filas(.ingreso)
            ForEach(Array(filas.enumerated()), id: \.offset) { i, f in
                FilaCategoriaVista(nombre: f.nombre, ultimo: i == filas.count - 1)
            }
        }
        Grupo(titulo: L.t("GASTOS", "EXPENSES")) {
            let filas = categorias.filas(.gasto)
            ForEach(Array(filas.enumerated()), id: \.offset) { i, f in
                FilaCategoriaVista(nombre: f.nombre, ultimo: i == filas.count - 1)
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
        // **Sin botones, y aquí menos que en ningún sitio.** Esta es la única
        // sección desde la que se borra lo que no vuelve: respaldo, restaurar y
        // borrado. Un botón que no hace nada en las otras pantallas es una
        // promesa incumplida; aquí sería una invitación a pulsar algo cuyo
        // efecto no se puede comprobar todavía.
        Nota(L.t("El respaldo, la restauración y el borrado todavía no están enchufados en el Mac. Se hacen desde el iPhone o el iPad mientras tanto.",
                 "Backup, restore and erase aren't wired on the Mac yet. Use the iPhone or iPad in the meantime."))
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
                .background(.background.secondary,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
    var ultimo = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Paleta.categoria(Catalogos.clave(deEtiqueta: nombre), nombre: nombre))
                    .frame(width: 10, height: 10)
                Text(nombre).font(.system(size: 15.5))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 46)
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
