import SwiftUI

/// **Agenda, según el handoff**: la rejilla del mes a siete columnas, con los
/// eventos dentro de cada día y el día de hoy marcado en un círculo.
struct PantallaAgenda: View {
    let vm: AgendaViewModel

    @State private var dandoDeAlta = false

    private let dias = [GridItem](repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            cabecera
            ScrollView {
                rejilla.padding(.horizontal, 26).padding(.bottom, 26)
            }
        }
        .sheet(isPresented: $dandoDeAlta) {
            NuevaActividad(mesActual: vm.mesActual,
                           diaInicial: vm.diaSeleccionado,
                           proximoId: vm.proximoId) { ev in
                Task {
                    await vm.añadir(ev)
                    // Que salga hacia el servidor ya, por lo mismo que la
                    // captura rápida y el borrado: en el Mac la app no se va al
                    // fondo, así que la vuelta de "volver al frente" no llega y
                    // el alta se quedaría en la cola hasta el próximo arranque.
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
    }

    // MARK: - Mes y navegación

    private var cabecera: some View {
        HStack(spacing: 10) {
            // **Asíncronos**: cambiar de mes vuelve a pedir sus eventos, no
            // solo mueve la fecha.
            Button { Task { await vm.irAlMesAnterior() } } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            Text(vm.etiquetaMes)
                .font(.system(size: 15, weight: .semibold))
                .frame(minWidth: 170)
            Button { Task { await vm.irAlMesSiguiente() } } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            Button(L.t("Hoy", "Today")) { Task { await vm.irAHoy() } }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
            Spacer(minLength: 0)
            // **Dice a qué día apunta.** El alta nace en el día elegido de la
            // rejilla, no en hoy, así que el botón tiene que decir cuál es: un
            // "Nueva actividad" a secas, con el 3 seleccionado y mirando el mes
            // que viene, no deja adivinar dónde va a caer.
            Button {
                dandoDeAlta = true
            } label: {
                Label(L.t("Nueva actividad · día \(vm.diaSeleccionado)",
                          "New activity · day \(vm.diaSeleccionado)"),
                      systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            if vm.pendientesMes > 0 {
                Text(L.t("\(vm.pendientesMes) sin completar",
                         "\(vm.pendientesMes) not done"))
                    .font(.system(size: 12))
                    .foregroundStyle(Paleta.aviso)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
    }

    // MARK: - La rejilla

    private var rejilla: some View {
        LazyVGrid(columns: dias, spacing: 1) {
            ForEach(Array(nombresDeDia.enumerated()), id: \.offset) { _, n in
                Text(n)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.10))
            }
            ForEach(vm.celdasDelMes) { celda in
                celdaDelDia(celda)
            }
        }
        .background(Color.secondary.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.secondary.opacity(0.22), lineWidth: 0.5))
    }

    /// Los siete rótulos, del calendario del sistema y NO escritos a mano:
    /// así siguen al idioma y a qué día empieza la semana donde se use.
    private var nombresDeDia: [String] {
        let f = DateFormatter()
        f.locale = Locale.current
        let simbolos = f.shortStandaloneWeekdaySymbols ?? ["S","M","T","W","T","F","S"]
        let primero = Calendar.current.firstWeekday - 1
        return (0..<7).map { simbolos[($0 + primero) % 7].uppercased() }
    }

    @ViewBuilder
    private func celdaDelDia(_ celda: AgendaViewModel.CeldaMes) -> some View {
        if let dia = celda.dia {
            let esHoy = vm.diaHoy == dia
            let elegido = vm.diaSeleccionado == dia
            let eventos = vm.eventos(dia: dia)
            Button { vm.diaSeleccionado = dia } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(dia)")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(esHoy ? Paleta.sobreRelleno : .primary)
                        .frame(width: 22, height: 22)
                        .background(esHoy ? Paleta.brand : .clear, in: Circle())
                    ForEach(eventos.prefix(3)) { e in
                        Text(e.titulo)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .foregroundStyle(e.tipo.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(e.tipo.color.opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    // **No se recorta en silencio.** Un día con cinco cosas que
                    // enseña tres y calla las otras dos miente sobre lo que hay.
                    if eventos.count > 3 {
                        Text(L.t("+\(eventos.count - 3) más", "+\(eventos.count - 3) more"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                .padding(8)
                .background(elegido ? Paleta.brandFill : Color(nsColor: .controlBackgroundColor))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            // Los huecos antes del día 1 y después del último: del color del
            // suelo, para que el mes se lea como un bloque.
            Color.secondary.opacity(0.06).frame(minHeight: 104)
        }
    }
}
