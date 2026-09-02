import Foundation

protocol CartasRepository {
    func emitidas() async throws -> [CartaEmitida]
}

struct MockCartasRepository: CartasRepository {
    func emitidas() async throws -> [CartaEmitida] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return [
            CartaEmitida(id: 1, iniciales: "JM", persona: L.t("Javier Medina · traslado", "Javier Medina · transfer"), tipo: .traslado),
            CartaEmitida(id: 2, iniciales: "AT", persona: L.t("Ana Torres · constancia", "Ana Torres · certificate"),    tipo: .bautismo),
        ]
    }
}
