import SwiftUI

/// **Por revisar, según el handoff.**
///
/// Una franja de aviso arriba con cuántas cosas esperan decisión, y debajo una
/// tarjeta por cada una: la etiqueta de qué clase de problema es, el concepto,
/// el porqué y de dónde viene.
///
/// No va a tabla a propósito, y el handoff acierta: aquí no se compara, se
/// DECIDE. Cada tarjeta es un caso con su explicación, y esa explicación es lo
/// que permite decidir sin ir a buscar el movimiento a otra pantalla.
struct PantallaRevisar: View {
    let vm: RevisarViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if vm.porRevisarCount > 0 { franja }
                if !vm.tiposPresentes.isEmpty { filtros }
                if vm.visibles.isEmpty {
                    vacio
                } else {
                    ForEach(vm.visibles) { tarjeta($0) }
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
        }
        .background(Color.suelo)
        .overlay(alignment: .bottom) { aviso }
        .animation(.snappy, value: vm.toast?.id)
    }

    private var franja: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Paleta.aviso)
            Text(vm.porRevisarCount == 1
                 ? L.t("1 cosa espera una decisión.", "1 item needs a decision.")
                 : L.t("\(vm.porRevisarCount) cosas esperan una decisión.",
                       "\(vm.porRevisarCount) items need a decision."))
                .font(.system(size: 12.5, weight: .semibold))
            Text(resumenDeTipos)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            aprobarLoSeguro
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .background(Paleta.aviso.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Paleta.aviso.opacity(0.35), lineWidth: 1))
    }

    /// "3 esperan visto bueno, 2 sin comprobante" — lo que hay, contado por su
    /// tipo. El handoff escribe una frase así y no un número suelto: saber
    /// QUÉ espera cambia por dónde se empieza.
    private var resumenDeTipos: String {
        vm.tiposPresentes
            .map { "\(vm.count($0)) \($0.etiqueta.lowercased())" }
            .joined(separator: " · ")
    }

    private var filtros: some View {
        HStack(spacing: 6) {
            chip(L.t("Todo", "All"), activo: vm.filtro == nil) { vm.filtro = nil }
            ForEach(vm.tiposPresentes, id: \.self) { t in
                chip("\(t.etiqueta) (\(vm.count(t)))", activo: vm.filtro == t) { vm.filtro = t }
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ r: String, activo: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(r)
                .font(.system(size: 12, weight: activo ? .semibold : .regular))
                .foregroundStyle(activo ? Paleta.brand : Color.secondary)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(activo ? Paleta.brandFill : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tarjeta(_ r: Revision) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(r.tipo.etiqueta.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(Paleta.aviso)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Paleta.aviso.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(r.concepto).font(.system(size: 13.5, weight: .semibold))
                Spacer(minLength: 0)
                if r.archivado {
                    Text(L.t("Solo para enterarse", "Just so you know"))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            // **El porqué, entero.** Es lo que distingue esta pantalla de una
            // lista de avisos: sin la razón hay que ir a buscar el movimiento
            // a otra parte para poder decidir.
            Text(r.descripcion)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            // **Los botones, y a su derecha de dónde viene**, como en el
            // handoff. Entran solo Aprobar y Devolver, que son los que el
            // iPhone ya usa sobre el mismo repositorio. "Pedir datos" no existe
            // en ningún sitio —ni aquí ni en el web—, y "Editar", "Ir al corte"
            // y "Restaurar" abren otras pantallas que el Mac aún no enlaza: un
            // botón que no hace nada promete una decisión que no se toma.
            // Decidido por Iván el 23-sep.
            let botones = r.acciones.filter { $0.kind == .aprobar || $0.kind == .devolver }
            if !botones.isEmpty || !r.detalleLista.isEmpty {
                HStack(spacing: 8) {
                    ForEach(botones) { ac in
                        if ac.kind == .aprobar {
                            Button(ac.label) { resolver(r, ac.kind) }
                                .buttonStyle(.borderedProminent)
                                .tint(Paleta.brand)
                        } else {
                            Button(ac.label) { resolver(r, ac.kind) }
                                .buttonStyle(.bordered)
                        }
                    }
                    Spacer(minLength: 0)
                    if !r.detalleLista.isEmpty {
                        Text(r.detalleLista)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.tertiary)
                    }
                }
                .controlSize(.small)
                .padding(.top, 12)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjetaMac(13)
    }

    // MARK: - Acciones

    /// **"Aprobar todo lo seguro", y lo seguro es solo el visto bueno.** Un
    /// duplicado probable o un gasto sin comprobante piden mirar ESE
    /// movimiento; aprobarlos en bloque es justo lo que su bandera evita. Por
    /// eso el botón desaparece cuando no hay ninguno, en vez de apagarse: en
    /// el iPhone, apagado, prometía una acción que no podía hacer.
    @ViewBuilder
    private var aprobarLoSeguro: some View {
        if vm.aprobablesCount > 0 {
            Button(L.t("Aprobar todo lo seguro", "Approve all safe")) {
                Task {
                    await vm.aprobarTodo()
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Paleta.brand)
            .controlSize(.small)
            .help(L.t("Aprueba los \(vm.aprobablesCount) que solo esperan visto bueno. Los demás se deciden uno a uno.",
                      "Approves the \(vm.aprobablesCount) that only await approval. The rest are decided one by one."))
        }
    }

    /// **Se sube en cuanto se decide.** En el Mac no hay "volver al frente"
    /// que dispare la sincronización, y sin esto el visto bueno se quedaba en
    /// la cola hasta el próximo arranque, igual que le pasaba a Membresía.
    private func resolver(_ r: Revision, _ kind: AccionKind) {
        Task {
            await vm.resolver(r, kind: kind)
            await MotorSincronizacion.compartido.sincronizar()
        }
    }

    /// El aviso de lo que se acaba de hacer, con Deshacer: aprobar dinero con
    /// un clic de más no puede ser irreversible.
    @ViewBuilder
    private var aviso: some View {
        if let t = vm.toast {
            HStack(spacing: 14) {
                Text(t.mensaje)
                    .font(.system(size: 12.5))
                    .lineLimit(2)
                Button(L.t("Deshacer", "Undo")) {
                    Task {
                        await vm.deshacer()
                        await MotorSincronizacion.compartido.sincronizar()
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 12.5, weight: .semibold))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(.bottom, 18)
            .frame(maxWidth: 560)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: t.id) {
                try? await Task.sleep(for: .seconds(5))
                if vm.toast?.id == t.id { vm.toast = nil }
            }
        }
    }

    private var vacio: some View {
        ContentUnavailableView {
            Label(L.t("Nada que revisar", "Nothing to review"), systemImage: "checkmark.circle")
        } description: {
            Text(L.t("Todo lo capturado está en orden.",
                     "Everything captured is in order."))
        }
        .padding(.top, 40)
    }
}
