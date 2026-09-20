// **El plazo de `SesionSupabase.restaurar()`, comprobado suelto.**
//
// No es XCTest y no necesita el proyecto: se compila y se corre solo, que es
// lo que hacía falta para no montar la copia entera de §3 por tres asertos.
//
//     swiftc -parse-as-library pruebas/PlazoDeSesionTests.swift -o /tmp/plazo && /tmp/plazo
//
// Lo que prueba —y por qué existe— es la primera versión del plazo, que estaba
// MAL: era un `withThrowingTaskGroup` que corría el cuerpo contra un
// `Task.sleep`. Un grupo espera a todos sus hijos antes de propagar el error,
// así que con un cuerpo que no atiende la cancelación —`SecItemCopyMatching`
// bloqueado en el llavero es exactamente eso— el plazo se cumplía y la función
// se colgaba IGUAL. Esta prueba se quedó parada sin imprimir nada hasta que se
// la mató; la de abajo, con la continuación, tarda 1,06 s.
//
// Si alguien vuelve a "simplificarlo" a un task group, esto se cuelga otra vez.

import Foundation

struct PlazoAgotado: Error {}

func conPlazo<T: Sendable>(segundos: Double,
                           _ cuerpo: @escaping @Sendable () async throws -> T) async throws -> T {
    let caja = Entrega<T>()
    return try await withCheckedThrowingContinuation { cont in
        Task.detached {
            do { await caja.entregar(cont, .success(try await cuerpo())) }
            catch { await caja.entregar(cont, .failure(error)) }
        }
        Task.detached {
            try? await Task.sleep(nanoseconds: UInt64(segundos * 1_000_000_000))
            await caja.entregar(cont, .failure(PlazoAgotado()))
        }
    }
}

actor Entrega<T: Sendable> {
    private var entregado = false
    func entregar(_ cont: CheckedContinuation<T, Error>, _ r: Result<T, Error>) {
        guard !entregado else { return }
        entregado = true
        cont.resume(with: r)
    }
}

@main struct Prueba {
    static func main() async {
        // 1. Un cuerpo que NO vuelve nunca: tiene que agotar el plazo.
        let t0 = Date()
        do {
            _ = try await conPlazo(segundos: 1.0) { () -> String in
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                // Y aunque no atienda la cancelación, tampoco vuelve.
                while true { try? await Task.sleep(nanoseconds: 1_000_000_000) }
            }
            print("FALLO 1: volvió cuando no debía")
        } catch is PlazoAgotado {
            print(String(format: "OK 1: PlazoAgotado a los %.2f s", Date().timeIntervalSince(t0)))
        } catch {
            print("FALLO 1: error inesperado \(error)")
        }

        // 2. Un cuerpo rápido: tiene que devolver su valor, sin esperar el plazo.
        let t1 = Date()
        do {
            let v = try await conPlazo(segundos: 5.0) { () -> String in
                try await Task.sleep(nanoseconds: 100_000_000)
                return "sesión"
            }
            print(String(format: "OK 2: devolvió \"\(v)\" a los %.2f s", Date().timeIntervalSince(t1)))
        } catch {
            print("FALLO 2: \(error)")
        }

        // 3. Un cuerpo que lanza lo suyo: el error tiene que salir tal cual.
        struct FalloDeRed: Error {}
        do {
            _ = try await conPlazo(segundos: 5.0) { () -> String in throw FalloDeRed() }
            print("FALLO 3: no lanzó")
        } catch is FalloDeRed {
            print("OK 3: el error del cuerpo sale tal cual, no se disfraza de plazo")
        } catch {
            print("FALLO 3: \(error)")
        }
    }
}
