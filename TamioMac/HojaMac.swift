import SwiftUI

/// **La forma de una hoja, según `handoff5`.**
///
/// Las seis hojas del handoff —miembro, pariente, culto, asistencia, acta y
/// actividad— se dibujan todas igual, así que la forma vive aquí una sola vez y
/// cada hoja pone solo su contenido. Antes no era así: las cuatro primeras se
/// escribieron el 21 de septiembre **contra el vacío**, porque hasta el cuarto
/// handoff no había ninguna dibujada, y cada una inventó su propia forma. El
/// quinto las trae y manda él.
///
/// Lo que fija el handoff, medida por medida:
///
/// - **640 puntos de ancho** y pegada arriba.
/// - Cabecera de 46: el título a la izquierda y **"Cerrar"** en azul a la
///   derecha. No es un botón de barra: es el enlace que el handoff dibuja.
/// - El aviso de lo que falta **arriba del todo**, no junto a los botones.
///   Quien intenta guardar mira arriba, no abajo.
/// - Las secciones son **tarjetas agrupadas** de radio 13 con las filas
///   separadas por medio punto, como los Ajustes del sistema.
/// - Cada fila mide **44 de alto**, con el rótulo a la IZQUIERDA en 200 fijos y
///   el control ocupando el resto. **No hay dos columnas**, que es como se
///   habían hecho las primeras.
/// - Pie de 54 con **"Esc cierra · ⌘S guarda"** y los dos botones.
///
/// **Sigue siendo un `.sheet` de verdad** y no un `ZStack` encima de la
/// ventana, aunque el handoff dibuje su propio velo: una hoja del sistema trae
/// el Escape, el foco y el anclaje a la ventana ya resueltos, y reescribir eso
/// a mano solo añade sitios donde perderlos. Lo que se copia es la forma de
/// dentro, que es lo que se ve.
struct HojaMac<C: View>: View {

    let titulo: String
    /// El rótulo del botón que guarda: "Guardar", "Guardar el conteo"…
    let rotuloGuardar: String
    /// Lo que falta por rellenar, en palabras y en el orden de la hoja. El
    /// aviso solo sale cuando `intentoGuardar` está encendido.
    let faltan: [String]
    let intentoGuardar: Bool
    /// **Devuelve si se guardó**, y con eso la hoja se cierra sola.
    ///
    /// Empezó siendo `() -> Void` y la hoja se quedaba abierta después de
    /// guardar: el `dismiss` vive aquí, en la forma, y la hoja de dentro ya no
    /// lo tenía. Medido —la fila llegó a la base con la hoja todavía delante—.
    /// Devolver `false` es lo que hace una hoja a la que le faltan campos: se
    /// queda abierta enseñando el aviso.
    let alGuardar: () -> Bool
    @ViewBuilder let contenido: () -> C

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        VStack(spacing: 0) {
            cabecera
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if intentoGuardar && !faltan.isEmpty { avisoDeFaltan }
                    contenido()
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: 620)

            Divider()
            pie
        }
        .frame(width: 640)
    }

    private var cabecera: some View {
        HStack(spacing: 10) {
            Text(titulo)
                .font(.system(size: 13.5, weight: .semibold))
            Spacer(minLength: 0)
            Button(L.t("Cerrar", "Close")) { cerrar() }
                .buttonStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Paleta.enlace)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    /// **El aviso nombra lo que falta, no dice "faltan campos".** Las palabras
    /// las pone cada campo obligatorio en su `req`, como en el handoff: "el
    /// nombre completo", "la fecha de la reunión". Así se puede arreglar sin
    /// recorrer la hoja buscando el hueco.
    private var avisoDeFaltan: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Paleta.aviso)
            Text(faltan.count == 1
                 ? L.t("Falta \(faltan[0]).", "Missing \(faltan[0]).")
                 : L.t("Faltan \(faltan.joined(separator: ", ")).",
                       "Missing \(faltan.joined(separator: ", "))."))
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.aviso.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var pie: some View {
        HStack(spacing: 9) {
            Text(L.t("Esc cierra · ⌘S guarda", "Esc closes · ⌘S saves"))
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            Button(L.t("Cancelar", "Cancel")) { cerrar() }
                .keyboardShortcut(.cancelAction)
            Button { if alGuardar() { cerrar() } } label: {
                HStack(spacing: 6) {
                    Text(rotuloGuardar)
                    Text("⌘S").opacity(0.75)
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .buttonStyle(.borderedProminent)
            .tint(Paleta.brand)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }
}

// MARK: - Una sección de la hoja

/// Un grupo de filas con su rótulo en mayúsculas encima y, si la tiene, su nota
/// al pie. La nota es del handoff palabra por palabra: explica una regla que no
/// se deduce del campo —qué cuenta como expediente completo, por qué un puesto
/// vacío deja el culto como parcial—, y por eso se copia y no se resume.
struct SeccionHoja<C: View>: View {
    let titulo: String
    var nota: String? = nil
    @ViewBuilder let filas: () -> C

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titulo)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) { filas() }
                .background(Color.tarjeta)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5))

            if let nota {
                Text(nota)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
        }
    }
}

// MARK: - Las filas

/// **El armazón de una fila, y el separador va en TODAS.**
///
/// También en la última: el handoff pinta `border-bottom` en cada una y recorta
/// el grupo con `overflow:hidden`, así que el de abajo queda al ras del borde
/// redondeado y hace de cierre. Quitarlo en la última dejaría la tarjeta abierta
/// por abajo.
struct ArmazonFila<C: View>: View {
    var alto: CGFloat = 44
    @ViewBuilder let contenido: () -> C

    var body: some View {
        VStack(spacing: 0) {
            contenido()
                .padding(.horizontal, 14)
                .frame(minHeight: alto)
            Divider()
        }
    }
}

/// El rótulo de la izquierda: **200 puntos fijos**, del handoff. Fijo y no
/// flexible para que los controles de todas las filas empiecen en la misma
/// vertical, que es lo que hace que un formulario largo se lea de un vistazo.
struct RotuloFila: View {
    let texto: String
    var body: some View {
        Text(texto)
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)
            .frame(width: 200, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct FilaTexto: View {
    let rotulo: String
    @Binding var valor: String
    var marcador: String = ""

    var body: some View {
        ArmazonFila {
            HStack(spacing: 12) {
                RotuloFila(texto: rotulo)
                TextField("", text: $valor, prompt: marcador.isEmpty ? nil : Text(marcador))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(rotulo)
            }
        }
    }
}

struct FilaSelector<T: Hashable>: View {
    let rotulo: String
    @Binding var valor: T
    let opciones: [(valor: T, etiqueta: String)]

    var body: some View {
        ArmazonFila {
            HStack(spacing: 12) {
                RotuloFila(texto: rotulo)
                // **Se estira, como el `flex:1` del handoff.** Sin esto el
                // selector toma su ancho natural y, al no haber nada que
                // empuje, el `HStack` centra la fila entera: el rótulo dejaba
                // de alinearse con el de las filas de texto, que sí crecen.
                // Se vio en la captura, con "Estado" desplazado a la derecha.
                Picker("", selection: $valor) {
                    ForEach(opciones, id: \.valor) { o in
                        Text(o.etiqueta).tag(o.valor)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(rotulo)
            }
        }
    }
}

struct FilaFecha: View {
    let rotulo: String
    @Binding var valor: Date

    var body: some View {
        ArmazonFila {
            HStack(spacing: 12) {
                RotuloFila(texto: rotulo)
                DatePicker("", selection: $valor, displayedComponents: .date)
                    .labelsHidden()
                    .accessibilityLabel(rotulo)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Un número, con **96 puntos de ancho** y alineado a la derecha: son conteos
/// —niños, jóvenes, adultos— y en columna se suman con la vista.
struct FilaNumero: View {
    let rotulo: String
    @Binding var valor: String

    var body: some View {
        ArmazonFila {
            HStack(spacing: 12) {
                Text(rotulo)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                TextField("", text: $valor, prompt: Text("0"))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 96)
                    .accessibilityLabel(rotulo)
            }
        }
    }
}

/// Un interruptor con su explicación debajo, cuando la lleva. **Esta fila es
/// más alta que 44** porque el subtexto la estira, y el handoff la dibuja así.
struct FilaInterruptor: View {
    let rotulo: String
    var sub: String? = nil
    @Binding var activo: Bool

    var body: some View {
        ArmazonFila {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rotulo).font(.system(size: 13))
                    if let sub {
                        Text(sub)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Toggle("", isOn: $activo)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Paleta.brand)
                    .accessibilityLabel(rotulo)
            }
            .padding(.vertical, 12)
        }
    }
}

/// Texto largo: el rótulo ARRIBA y la caja debajo a todo lo ancho, al revés que
/// las demás. Lo que se escribe aquí son párrafos —un resumen, unas notas— y en
/// 400 puntos de ancho no se leen.
struct FilaArea: View {
    let rotulo: String
    @Binding var valor: String
    var marcador: String = ""
    var lineas: ClosedRange<Int> = 3...8

    var body: some View {
        ArmazonFila(alto: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(rotulo)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                TextField("", text: $valor,
                          prompt: marcador.isEmpty ? nil : Text(marcador),
                          axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(lineas)
                    .accessibilityLabel(rotulo)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// **Una lista que se va llenando: fichas con aspa, campo y "Agregar".**
///
/// Es el `adder` del handoff, y sustituye a lo que se había hecho antes —filas
/// con aspa en Actas, casillas en tres columnas en Membresía—. Sirve para lo
/// que no es un catálogo cerrado: visitantes, mociones, acuerdos, nombres.
///
/// Return agrega, además del botón: escribiendo ocho nombres seguidos, ir al
/// botón cada vez cuesta más que escribirlos.
struct FilaFichas: View {
    let rotulo: String
    @Binding var valores: [String]
    var marcador: String = ""

    @State private var texto = ""
    private var limpio: String { texto.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ArmazonFila(alto: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(rotulo)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)

                if !valores.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(Array(valores.enumerated()), id: \.offset) { i, v in
                            HStack(spacing: 7) {
                                Text(v).font(.system(size: 12))
                                Button {
                                    valores.remove(at: i)
                                } label: {
                                    Text("✕").opacity(0.7)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(L.t("Quitar \(v)", "Remove \(v)"))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.quaternary.opacity(0.5), in: Capsule())
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("", text: $texto,
                              prompt: marcador.isEmpty ? nil : Text(marcador))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(agregar)
                        .accessibilityLabel(marcador.isEmpty ? rotulo : marcador)
                    Button(L.t("Agregar", "Add"), action: agregar)
                        .disabled(limpio.isEmpty)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func agregar() {
        guard !limpio.isEmpty else { return }
        valores.append(limpio)
        texto = ""
    }
}

/// **Una fecha que puede no saberse.**
///
/// El handoff pone un `<input type=date>` que admite quedarse vacío; un
/// `DatePicker` de SwiftUI **siempre tiene un valor**, así que sin el
/// interruptor una ficha sin fecha de nacimiento guardaría la de hoy y diría
/// que esa persona nació hoy. El interruptor es lo mínimo para poder no saberlo,
/// y va en la misma fila para no romper el ritmo de la tarjeta.
struct FilaFechaOpcional: View {
    let rotulo: String
    @Binding var conocida: Bool
    @Binding var valor: Date

    var body: some View {
        ArmazonFila {
            HStack(spacing: 12) {
                RotuloFila(texto: rotulo)
                Toggle("", isOn: $conocida)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Paleta.brand)
                    .accessibilityLabel(L.t("\(rotulo), conocida", "\(rotulo), known"))
                if conocida {
                    DatePicker("", selection: $valor, displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityLabel(rotulo)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
