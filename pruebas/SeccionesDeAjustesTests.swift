import XCTest
@testable import Tamio

/// **Qué secciones de Ajustes ve cada rol.**
///
/// Las ocho filas se pintaban para todo el mundo en el teléfono y en el iPad,
/// mientras el app web ya escondía dos (`visible: verTesoreria` y
/// `visible: esAdmin` en `ZONAS`). No era cosmética: de la Zona de riesgo salen
/// los CSV de movimientos y de aportantes, así que una secretaria se llevaba la
/// tesorería que la navegación le cierra, y un tesorero sin `tesoreroVePadron`
/// se llevaba el padrón que no puede ni abrir.
final class SeccionesDeAjustesTests: XCTestCase {

    private func permisos(_ rol: SesionSupabase.Perfil.Rol,
                          vePadron: Bool = false) -> Permisos {
        var iglesia = ConfiguracionIglesia()
        iglesia.tesoreroVePadron = vePadron
        return Permisos(rol: rol, iglesia: iglesia)
    }

    // MARK: - Lo que se cierra

    func testLaSecretariaNoVeCategoriasNiLaZonaDeRiesgo() {
        let p = permisos(.secretaria)
        XCTAssertFalse(p.veAjuste(.categorias),
                       "son las categorías de ingresos y gastos, y no entra a Tesorería")
        XCTAssertFalse(p.veAjuste(.zona),
                       "de ahí sale el CSV de movimientos: la tesorería entera")
    }

    func testElTesoreroVeCategoriasPeroNoLaZonaDeRiesgo() {
        let p = permisos(.tesorero)
        XCTAssertTrue(p.veAjuste(.categorias), "son suyas")
        XCTAssertFalse(p.veAjuste(.zona),
                       "sin `tesoreroVePadron` se llevaba el padrón en CSV")
    }

    /// El permiso del padrón abre una PANTALLA, no la exportación: la Zona de
    /// riesgo sigue siendo del administrador.
    func testNiConElPadronAbiertoVeElTesoreroLaZonaDeRiesgo() {
        XCTAssertFalse(permisos(.tesorero, vePadron: true).veAjuste(.zona))
    }

    // MARK: - Lo que no se toca

    func testElAdministradorLasVeTodas() {
        let p = permisos(.administrador)
        for s in SeccionAjustes.allCases {
            XCTAssertTrue(p.veAjuste(s), "\(s.rawValue) le falta al administrador")
        }
    }

    /// Cerrar sesión, el candado y el idioma tienen que estar para cualquiera:
    /// una app en la que un rol no puede salirse de su cuenta está rota.
    func testCuentaYPreferenciasLasVenTodOS() {
        for rol in [SesionSupabase.Perfil.Rol.tesorero, .secretaria, .administrador] {
            let p = permisos(rol)
            XCTAssertTrue(p.veAjuste(.cuenta), "\(rol) se quedó sin cerrar sesión")
            XCTAssertTrue(p.veAjuste(.preferencias), "\(rol) se quedó sin idioma")
        }
    }

    /// Las cuatro del grupo "Iglesia" siguen abiertas: el membrete y las firmas
    /// los usan los documentos de las dos áreas, y Acceso ya se reserva por
    /// dentro con `administraPermisos`.
    func testElGrupoDeIglesiaSigueAbierto() {
        for rol in [SesionSupabase.Perfil.Rol.tesorero, .secretaria, .administrador] {
            let p = permisos(rol)
            for s in [SeccionAjustes.iglesia, .institucion, .tesorero, .acceso] {
                XCTAssertTrue(p.veAjuste(s), "\(s.rawValue) desapareció para \(rol)")
            }
        }
    }
}
