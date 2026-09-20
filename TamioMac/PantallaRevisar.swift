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
    }

    private var franja: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Paleta.aviso)
            Text(L.t("\(vm.porRevisarCount) cosas esperan una decisión.",
                     "\(vm.porRevisarCount) items need a decision."))
                .font(.system(size: 12.5, weight: .semibold))
            Text(resumenDeTipos)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
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

            if !r.detalleLista.isEmpty {
                Text(r.detalleLista)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }

            // **Sin botones todavía.** El handoff pone aquí Aprobar, Devolver
            // y Pedir datos. Las tres mueven el estado de revisión de un
            // apunte de dinero y aún no están escritas: un botón que no hace
            // nada, aquí, promete una decisión que no se toma.
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjetaMac(13)
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
