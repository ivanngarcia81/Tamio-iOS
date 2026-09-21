import SwiftUI

/// **Registrar una acción de seguimiento, según `handoff7`.**
///
/// Dos secciones: A QUIÉN y QUÉ SE HIZO. La forma la pone `HojaMac`.
///
/// Esta hoja se escribió antes de que el handoff la trajera, con forma propia.
/// El séptimo la dibuja y manda él; de la versión anterior se conserva una sola
/// cosa, marcada abajo: **el historial**.
///
/// **La persona es un selector y no un dato fijo.** La hoja se abre desde la
/// tarjeta de alguien —y entonces llega elegida—, pero el handoff la pide como
/// campo obligatorio porque también se abre sin contexto. Las dos formas caben:
/// lo que llega puesto se puede cambiar.
struct SeguimientoMac: View {

    /// La persona con la que se abre, cuando se abre desde su tarjeta. `nil`
    /// para empezar eligiendo.
    let miembro: Miembro?
    /// Devuelve a quién se le apunta y qué, porque el selector puede cambiar a
    /// quién se le está apuntando.
    let alGuardar: (String, SeguimientoNota) -> Void

    @State private var miembroId: String
    @State private var tipo: TipoSeguimiento = .llamada
    @State private var fecha = Date()
    @State private var texto = ""
    @State private var hecho = false
    @State private var intentoGuardar = false
    @State private var padron: [PersonaDelPadron] = []

    init(miembro: Miembro?, alGuardar: @escaping (String, SeguimientoNota) -> Void) {
        self.miembro = miembro
        self.alGuardar = alGuardar
        _miembroId = State(initialValue: miembro?.id ?? "")
    }

    private static let fmtFecha: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = L.locale
        return f
    }()

    /// Las palabras son las del handoff: `req:'choosing the person'` y
    /// `req:'a short account'`. La fecha siempre trae valor.
    private var faltan: [String] {
        var f: [String] = []
        if miembroId.isEmpty { f.append(L.t("elegir a la persona", "choosing the person")) }
        if texto.trimmingCharacters(in: .whitespaces).isEmpty {
            f.append(L.t("un relato breve", "a short account"))
        }
        return f
    }

    /// El historial de la persona elegida. Si se cambia el selector a alguien
    /// que no es con quien se abrió, no hay historial que enseñar: la hoja solo
    /// conoce la ficha que le pasaron.
    private var historialVisible: [SeguimientoNota] {
        guard let m = miembro, m.id == miembroId else { return [] }
        return m.seguimientoNotas
    }

    var body: some View {
        HojaMac(titulo: L.t("Registrar seguimiento", "Log follow-up"),
                rotuloGuardar: L.t("Guardar la nota", "Save the note"),
                faltan: faltan,
                intentoGuardar: intentoGuardar,
                alGuardar: guardar) {
            aQuien
            queSeHizo
            if !historialVisible.isEmpty { historial }
        }
        .task { if padron.isEmpty { padron = await padronParaSelector() } }
    }

    private var aQuien: some View {
        SeccionHoja(titulo: L.t("A QUIÉN", "WHO")) {
            FilaSelector(rotulo: L.t("Persona", "Person"), valor: $miembroId,
                         opciones: opcionesPersona)
            // La razón por la que está en la lista de seguimiento. No es un
            // campo: es lo que hay que saber antes de llamar.
            if let razon = miembro?.seguimientoRazon, miembro?.id == miembroId {
                FilaAviso(texto: razon)
            }
        }
    }

    /// El padrón, con la persona con la que se abrió delante aunque el padrón
    /// todavía no haya cargado: la hoja se abre y se puede guardar sin esperar.
    private var opcionesPersona: [(String, String)] {
        var op: [(String, String)] = [("", L.t("Elegir…", "Choose…"))]
        if let m = miembro, !padron.contains(where: { $0.id == m.id }) {
            op.append((m.id, m.nombre))
        }
        return op + padron.map { ($0.id, $0.nombre) }
    }

    private var queSeHizo: some View {
        SeccionHoja(
            titulo: L.t("QUÉ SE HIZO", "WHAT WAS DONE"),
            nota: L.t("La nota viaja con la persona, no con el aviso: la razón pastoral puede desaparecer y lo que se hizo se queda escrito.",
                      "The note travels with the person, not with the alert: the pastoral reason may go away, and what was done stays written.")
        ) {
            FilaSelector(rotulo: L.t("Tipo", "Kind"), valor: $tipo,
                         opciones: TipoSeguimiento.allCases.map { ($0, $0.etiqueta) })
            FilaFecha(rotulo: L.t("Cuándo", "When"), valor: $fecha)
            FilaArea(rotulo: L.t("Qué pasó", "What happened"), valor: $texto,
                     marcador: L.t("p. ej. Llamé; está de viaje y vuelve en dos semanas",
                                   "e.g. Called; she is travelling and comes back in two weeks"))
            FilaInterruptor(rotulo: L.t("Esto cierra el seguimiento",
                                        "This closes the follow-up"),
                            sub: L.t("Déjalo apagado si alguien todavía tiene que volver.",
                                     "Leave it off if someone still has to go back."),
                            activo: $hecho)
        }
    }

    /// **El historial no está en el handoff, y se queda.**
    ///
    /// Es lo único que sobrevive de la versión anterior de esta hoja. Sin él,
    /// quien va a llamar no ve que alguien ya llamó el martes, y la pantalla
    /// invita a repetir el trabajo. Va al final para no empujar hacia abajo lo
    /// que hay que rellenar, que es lo que el handoff pone primero.
    private var historial: some View {
        SeccionHoja(titulo: L.t("LO QUE YA SE HIZO", "HISTORY")) {
            // De lo último a lo primero: lo que importa al abrir es si ya se
            // hizo algo esta semana, no lo de hace un año.
            ForEach(historialVisible.reversed()) { n in
                FilaHistorial(
                    icono: n.completado ? "checkmark.circle.fill" : n.tipo.icono,
                    hecho: n.completado,
                    titulo: n.tipo.etiqueta,
                    fecha: Self.fmtFecha.string(from: n.fecha),
                    texto: n.descripcion)
            }
        }
    }

    private func guardar() -> Bool {
        intentoGuardar = true
        guard faltan.isEmpty else { return false }
        alGuardar(miembroId, SeguimientoNota(
            tipo: tipo,
            fecha: fecha,
            descripcion: texto.trimmingCharacters(in: .whitespaces),
            completado: hecho))
        return true
    }
}

/// Una fila que solo avisa: la razón pastoral por la que alguien está en la
/// lista. No se edita, así que no lleva control.
struct FilaAviso: View {
    let texto: String
    var body: some View {
        ArmazonFila {
            HStack(spacing: 9) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Paleta.aviso)
                Text(texto)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Paleta.aviso)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
        }
    }
}

/// Una acción ya registrada, de solo lectura.
struct FilaHistorial: View {
    let icono: String
    let hecho: Bool
    let titulo: String
    let fecha: String
    let texto: String

    var body: some View {
        ArmazonFila {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icono)
                    .font(.system(size: 12))
                    .foregroundStyle(hecho ? Paleta.brand : Color.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(titulo).font(.system(size: 12.5, weight: .medium))
                        Spacer(minLength: 0)
                        Text(fecha)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if !texto.isEmpty {
                        Text(texto)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }
}
