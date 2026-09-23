import SwiftUI
import AppKit

/// **La tabla de Ingresos y Gastos.**
///
/// Es un `Table` de verdad y no una lista de filas dibujadas a mano: en el Mac
/// se espera poder ordenar por una columna pulsando su cabecera, arrastrar el
/// borde para ensancharla y recorrer la selección con las flechas. Todo eso
/// sale gratis con `Table` y habría que escribirlo entero con una `List`.
struct TablaMovimientos: View {
    let vm: MovimientosViewModel
    @Environment(EstadoVentana.self) private var estado
    @Environment(\.openWindow) private var abrirVentana
    @Binding var seleccion: Set<Movimiento.ID>

    /// **Quién puede borrar, y por qué se pregunta.** El permiso vive en
    /// Supabase con un disparador que deshace la baja de un tesorero sin él;
    /// enseñar la orden igualmente haría que la fila desapareciera y volviera
    /// a la siguiente sincronización sin que nadie supiera por qué. Es la
    /// misma comprobación que hace `MovimientosView` en iOS.
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    private var puedeEliminar: Bool {
        Permisos(rol: sesion?.perfil.rol ?? .administrador,
                 iglesia: ConfiguracionIglesiaViewModel.compartido.config)
            .puedeEliminarMovimientos
    }

    /// Lo que espera confirmación. Vacío mientras no se pida nada.
    @State private var aEliminar: [Movimiento] = []

    /// **Por fecha y de la más reciente hacia abajo**, que es como se mira un
    /// libro: lo último que se capturó es lo que se está comprobando.
    @State private var orden = [KeyPathComparator(\Movimiento.fecha, order: .reverse)]

    private var filas: [Movimiento] { vm.itemsFiltrados.sorted(using: orden) }

    var body: some View {
        Table(filas, selection: $seleccion, sortOrder: $orden) {

            TableColumn(L.t("Fecha", "Date"), value: \.fecha) { m in
                Text(m.fecha.formatted(.dateTime.day().month(.abbreviated)))
                    .foregroundStyle(.secondary)
                    // **El alto de fila se fija en la PRIMERA columna.**
                    //
                    // `Table` no tiene ajuste de alto de fila: la fila mide lo
                    // que mida su celda más alta, así que basta con dárselo a
                    // una. Va aquí y no en las seis para no repetir el mismo
                    // modificador seis veces.
                    .frame(height: estado.altoDeFila)
            }
            .width(min: 76, ideal: 96, max: 140)

            TableColumn(L.t("Folio", "Folio"), value: \.folio) { m in
                Text(m.folio)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 64, ideal: 84, max: 120)

            TableColumn(L.t("Concepto", "Concept"), value: \.categoria) { m in
                HStack(spacing: 8) {
                    // El punto de color de la categoría, igual que en la app de
                    // iOS: es lo que deja leer la columna de un vistazo sin
                    // llegar a leer la palabra.
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Paleta.categoria(m.claveCategoria, nombre: m.categoria))
                        .frame(width: 8, height: 8)
                    // En la lengua de la app: se guarda la clave (`diezmo`).
                    Text(Catalogos.etiquetaDeCategoria(m.categoria)).fontWeight(.semibold)
                    if !quien(m).isEmpty {
                        Text("· \(quien(m))")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 180, ideal: 320)

            TableColumn(L.t("Método", "Method"), value: \.metodo) { m in
                Text(m.metodo).foregroundStyle(.secondary)
            }
            .width(min: 88, ideal: 110, max: 160)

            TableColumn(L.t("Estado", "Status"), value: \.ordenDeEstado) { m in
                let e = EstadoFila(m)
                Text(e.texto)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(e.tinta)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(e.tinta.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .width(min: 104, ideal: 128, max: 180)

            TableColumn(L.t("Importe", "Amount"), value: \.monto) { m in
                // A la derecha y con cifras de ancho fijo: una columna de
                // dinero que no alinea las unidades no se puede recorrer con
                // la vista, que es justo para lo que se mira.
                Text(Money.firmado(m.monto, ingreso: m.esIngreso))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(Money.color(ingreso: m.esIngreso))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 100, ideal: 130, max: 180)
        }
        // **Sin rayas alternas, y no es capricho.**
        //
        // `alternatesRowBackgrounds` las pinta en TODO el alto de la tabla,
        // también donde no hay datos: con dos movimientos en pantalla, la
        // ventana se llenaba de cuarenta renglones rayados vacíos. El handoff
        // alterna solo las filas que existen y deja el resto limpio, y entre
        // las dos cosas la que más se parece es no alternar.
        .tableStyle(.inset)
        // **El menú contextual del handoff, con lo que de verdad funciona.**
        //
        // El diseño lista ocho órdenes: Aprobar ⌘R, Marcar depositado ⇧⌘B,
        // Devolver a la bandeja, Duplicar ⌘D, Copiar folio ⌘C, Eliminar… y
        // dos más. Las que mueven dinero o estado de revisión todavía no están
        // escritas; ponerlas apagadas o, peor, que no hagan nada, promete lo
        // que no hay. Entran las tres de copiar —las que se usan para cuadrar
        // contra el talonario sin soltar el teclado— y Duplicar, que no mueve
        // nada: solo rellena la captura rápida, y guardar sigue siendo ⌘S.
        .contextMenu(forSelectionType: Movimiento.ID.self) { ids in
            // **Aprobar ⌘R, solo si hay algo que aprobar.** Pasa por la misma
            // bandeja que Por revisar —el asunto de visto bueno del
            // movimiento—, así que aprueba igual, deja el mismo Deshacer y el
            // contador de la barra lateral baja a la vez. "Marcar depositado"
            // y "Devolver a la bandeja" no entran: el primero no existe en
            // ninguna plataforma y el segundo no se sabe si es devolver al
            // tesorero o volver a pendiente. Decidido por Iván el 23-sep.
            let aprobables = filas.filter { ids.contains($0.id) && $0.estadoRevision == .pendiente }
            if !aprobables.isEmpty {
                Button(aprobables.count == 1
                       ? L.t("Aprobar", "Approve")
                       : L.t("Aprobar \(aprobables.count)", "Approve \(aprobables.count)")) {
                    aprobar(aprobables)
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
            }
            if let m = filas.first(where: { ids.contains($0.id) }) {
                // Solo con UNA fila: la captura rápida es de un apunte, y
                // duplicar seis a la vez tendría que elegir cuál sin decirlo.
                if ids.count == 1 {
                    Button(L.t("Duplicar", "Duplicate")) { duplicar(m) }
                        .keyboardShortcut("d", modifiers: .command)
                    Divider()
                }
                Button(L.t("Copiar folio", "Copy folio")) { copiar(m.folio) }
                Button(L.t("Copiar concepto", "Copy concept")) {
                    copiar([Catalogos.etiquetaDeCategoria(m.categoria), quien(m)].filter { !$0.isEmpty }.joined(separator: " · "))
                }
                Button(L.t("Copiar importe", "Copy amount")) {
                    copiar(Money.fmt(m.monto))
                }
                if puedeEliminar {
                    Divider()
                    // **Con puntos suspensivos porque pregunta.** La convención
                    // del Mac, y aquí no es cortesía: borra dinero de un libro.
                    Button(L.t("Eliminar…", "Delete…"), role: .destructive) {
                        aEliminar = filas.filter { ids.contains($0.id) }
                    }
                }
            }
        }
        // **El ⌘D tiene que funcionar sin abrir el menú.** Un atajo dentro de
        // un menú contextual solo responde mientras el menú está abierto; este
        // botón invisible es el que lo cumple con la fila seleccionada, igual
        // que el ⌘C de una tabla del Finder.
        .background {
            Button(L.t("Duplicar", "Duplicate")) {
                if let m = seleccionUnica { duplicar(m) }
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(seleccionUnica == nil)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            // El ⌘R, por lo mismo que el ⌘D.
            Button(L.t("Aprobar", "Approve")) { aprobar(seleccionPendiente) }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(seleccionPendiente.isEmpty)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        // **Actúa sobre TODA la selección, no sobre la fila pulsada.** Una
        // tabla de Mac selecciona muchas y el menú sale de la selección; borrar
        // solo una de las seis marcadas sería la sorpresa, no lo contrario. Por
        // eso el aviso dice cuántas y cuánto dinero se lleva.
        .confirmationDialog(tituloDelBorrado,
                            isPresented: Binding(get: { !aEliminar.isEmpty },
                                                 set: { if !$0 { aEliminar = [] } }),
                            titleVisibility: .visible) {
            Button(L.t("Eliminar", "Delete"), role: .destructive) { eliminarConfirmados() }
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { aEliminar = [] }
        } message: {
            Text(L.t("Se va del libro de la iglesia y de todos los aparatos. El Registro guarda quién lo hizo.",
                     "It leaves the church's books and every device. The Log keeps who did it."))
        }
    }

    private var seleccionPendiente: [Movimiento] {
        filas.filter { seleccion.contains($0.id) && $0.estadoRevision == .pendiente }
    }

    /// Por la bandeja y no escribiendo el estado a mano: el id del asunto es
    /// `tx-<id>-vistoBueno` (`CalculadoraRevisiones.base`), y `resolver` es lo
    /// que ya usan Por revisar y el iPhone.
    private func aprobar(_ movs: [Movimiento]) {
        Task {
            let bandeja = RevisarViewModel.compartido
            await bandeja.cargar()
            for m in movs {
                if let r = bandeja.todos.first(where: { $0.id == "tx-\(m.id)-\(RevisionTipo.vistoBueno.rawValue)" }) {
                    await bandeja.resolver(r, kind: .aprobar)
                }
            }
            await vm.cargar()
            await MotorSincronizacion.compartido.sincronizar()
        }
    }

    private var tituloDelBorrado: String {
        guard aEliminar.count != 1 else {
            let m = aEliminar[0]
            let cat = Catalogos.etiquetaDeCategoria(m.categoria)
            return L.t("¿Eliminar \(cat) de \(Money.fmt(m.monto))?",
                       "Delete \(cat) for \(Money.fmt(m.monto))?")
        }
        let total = Money.fmt(aEliminar.reduce(0) { $0 + $1.monto })
        return L.t("¿Eliminar \(aEliminar.count) movimientos, \(total) en total?",
                   "Delete \(aEliminar.count) entries, \(total) in total?")
    }

    /// **Uno por uno y por el repositorio**, que es quien hace el borrado
    /// lógico —`borrado = 1` más el apunte en la cola de salida— y el apunte
    /// del Registro con copia de lo que decía la fila. Un `DELETE` de verdad no
    /// se podría sincronizar.
    private func eliminarConfirmados() {
        let cuales = aEliminar
        aEliminar = []
        Task {
            for m in cuales {
                await vm.eliminar(m)
                if vm.error != nil { break }
            }
            seleccion.subtract(Set(cuales.map(\.id)))
            estado.recargar()
            // Que el borrado SALGA, por lo mismo que la captura rápida: si la
            // app no se va al fondo, la vuelta de "volver al frente" no llega y
            // la baja se quedaría en la cola hasta el próximo arranque.
            await MotorSincronizacion.compartido.sincronizar()
        }
    }

    /// La fila elegida, si es una sola. Con varias no hay "el" movimiento que
    /// duplicar.
    private var seleccionUnica: Movimiento? {
        guard seleccion.count == 1, let id = seleccion.first else { return nil }
        return filas.first { $0.id == id }
    }

    /// **Duplicar no guarda: abre la captura rápida ya rellena.**
    ///
    /// Se copian el tipo, la categoría, el método y el importe, que es lo que
    /// se repite entre dos sobres iguales. La persona, la nota y la fecha NO:
    /// son de cada apunte, y heredarlas metería en el libro un aporte con el
    /// nombre y el día de otro. El folio lo asigna el repositorio al guardar,
    /// como siempre. La plantilla viaja por `EstadoVentana` porque la captura
    /// es otra escena y no hay otro sitio que vean las dos.
    private func duplicar(_ m: Movimiento) {
        estado.plantillaCaptura = .init(tipo: m.tipo, categoria: m.categoria,
                                        metodo: m.metodo, monto: m.monto)
        abrirVentana(id: CapturaRapida.idVentana)
    }

    private func copiar(_ texto: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texto, forType: .string)
    }

    /// Quién está al otro lado: el aportante en un ingreso, el beneficiario en
    /// un gasto. La misma columna no significa lo mismo en las dos pantallas.
    private func quien(_ m: Movimiento) -> String {
        (m.esIngreso ? m.persona : m.pagadoA)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
}

// MARK: - El estado de una fila

/// **Las tres situaciones que la maqueta pinta como píldora**, resueltas desde
/// lo que el modelo ya sabe. No hay campo "estado" en `Movimiento`: se deduce
/// de si espera visto bueno y de si algún corte depositado lo reclama.
struct EstadoFila {
    let texto: String
    let tinta: Color

    init(_ m: Movimiento) {
        if m.marcadoPendiente {
            texto = L.t("En revisión", "In review")
            tinta = Paleta.aviso
        } else if m.esIngreso && m.sinDepositar {
            texto = L.t("Sin depositar", "Not deposited")
            tinta = Paleta.aviso
        } else if m.esIngreso {
            texto = L.t("Depositado", "Deposited")
            tinta = Paleta.brand
        } else {
            texto = L.t("Asentado", "Posted")
            tinta = Paleta.brand
        }
    }
}

extension Movimiento {
    /// Para poder ORDENAR por la columna de estado.
    ///
    /// `Table` exige un `KeyPath` a algo comparable, y el estado es una píldora
    /// que se calcula. Vive en una extensión DENTRO del target de Mac a
    /// propósito: es una necesidad de esta tabla y no del modelo, y el iPhone
    /// no tiene por qué cargar con ella.
    ///
    /// El orden es el de urgencia, no el alfabético: primero lo que espera una
    /// decisión, luego lo que espera el banco, al final lo cerrado.
    var ordenDeEstado: Int {
        if marcadoPendiente { return 0 }
        if esIngreso && sinDepositar { return 1 }
        return 2
    }
}
