import SwiftUI

/// La pantalla que tapa la app mientras espera la cara.
///
/// **No enseña nada.** Ni el nombre de la iglesia, ni el saldo, ni cuántos
/// movimientos hay: si algo de eso se pudiera leer sin autenticar, el candado
/// no serviría de nada. Solo el candado, el nombre de la app y el botón.
struct PantallaBloqueo: View {
    @Bindable var bloqueo: BloqueoBiometrico

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: Esp.panel) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Paleta.brand)

                VStack(spacing: Esp.hueco) {
                    Text("Tamio").font(.title2.weight(.bold))
                    Text(L.t("Las cuentas de la iglesia están bloqueadas.",
                             "The church's accounts are locked."))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await bloqueo.abrir() }
                } label: {
                    Text(L.t("Desbloquear con \(BloqueoBiometrico.nombreBiometria)",
                             "Unlock with \(BloqueoBiometrico.nombreBiometria)"))
                        .font(.body.weight(.medium))
                        .padding(.horizontal, Esp.panel)
                        .padding(.vertical, Esp.chip)
                }
                .buttonStyle(.glass)
                .tint(Paleta.brand)

                if let error = bloqueo.error {
                    Text(error)
                        .font(.footnote).foregroundStyle(Paleta.negativo)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Esp.panel)
        }
        // Se pide en cuanto aparece: tener que pulsar un botón para que salga
        // el diálogo del sistema es un toque de más en el gesto que se repite
        // varias veces al día. El botón se queda para reintentar.
        .task { await bloqueo.abrir() }
    }
}

/// El velo del conmutador de apps.
///
/// iOS fotografía la pantalla al salir de la app para la tarjeta del
/// conmutador, y esa foto se hace ANTES de que nada tape el contenido: sin
/// esto, el saldo de la iglesia se queda visible en el conmutador aunque la app
/// esté bloqueada. Va atado al mismo interruptor: un candado que deja la foto
/// a la vista no es un candado.
struct VeloConmutador: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
