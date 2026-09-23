import XCTest

/// **Al volver del fondo con el candado puesto, ¿sale el diálogo o sale un
/// error en rojo?** Medido el 8 de septiembre de 2026: **5 de 6 veces salía**
/// "The operation couldn't be completed. (com.apple.LocalAuthentication error
/// 6.)", y tras el arreglo 0 de 6.
///
/// **Necesita Face ID inscrito en el simulador**, que no se hace con `simctl`
/// sino con una notificación:
///
///     xcrun simctl spawn <udid> notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
///     xcrun simctl spawn <udid> notifyutil -p com.apple.BiometricKit.enrollmentChanged
///
/// y la cara que COINCIDE se manda desde el shell al ver la marca:
///
///     xcrun simctl spawn <udid> notifyutil -p com.apple.BiometricKit_Sim.pearl.match
///
/// El candado se enciende en Ajustes · Cuenta y **se queda encendido entre
/// corridas**, así que cada vuelta empieza desbloqueando. El candado ya queda encendido en el simulador entre
/// corridas, así que cada vuelta empieza desbloqueando con la cara —la manda
/// el shell al ver MARCA-CARA— y termina volviendo del fondo.
final class CandadoUITests: XCTestCase {

    /// **Solo iPhone**: tras desbloquear espera la pestaña «Settings», que el
    /// iPad no tiene. En el iPad físico (23-sep) salió VERDE sin medir nada:
    /// las seis vueltas dijeron «no se pudo desbloquear» y el resultado fue
    /// «0 de 6 con error». El candado del iPad lo cubre `CandadoIPad`.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    private let rojo = NSPredicate(format:
        "label CONTAINS[c] 'interaction' OR label CONTAINS[c] 'LocalAuthentication' OR label CONTAINS[c] 'operation'")

    func testVolverDelFondo() {
        var conError = 0
        let vueltas = 6
        for vuelta in 1...vueltas {
            let app = XCUIApplication()
            // **El candado, ENCENDIDO por argumento**, como en `CandadoIPad`: sin
            // esto la prueba dependía de que se hubiera dejado puesto a mano en
            // Ajustes, y ese ajuste guardado es el que después tapa a todas las
            // demás. El dominio de argumentos no escribe de vuelta.
            app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                    "-bloqueo.biometrico", "YES"]
            app.launch(); sleep(3)

            // Arranca bloqueada: la cara la manda el shell.
            if app.staticTexts["The church's accounts are locked."].exists {
                print("MARCA-CARA"); fflush(stdout); Thread.sleep(forTimeInterval: 6)
            }
            guard app.tabBars.buttons["Settings"].waitForExistence(timeout: 6) else {
                print("vuelta \(vuelta): no se pudo desbloquear"); app.terminate(); continue
            }

            XCUIDevice.shared.press(.home); sleep(3)
            app.activate(); sleep(4)

            let bloqueada = app.staticTexts["The church's accounts are locked."].exists
            let hayError = app.staticTexts.matching(rojo).firstMatch.exists
            if hayError {
                conError += 1
                print("vuelta \(vuelta): ERROR → \(app.staticTexts.matching(rojo).firstMatch.label)")
            } else {
                print("vuelta \(vuelta): bloqueada=\(bloqueada) sin error")
            }
            fflush(stdout)
            print("MARCA:v\(vuelta)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0)
            print("MARCA-CARA"); fflush(stdout); Thread.sleep(forTimeInterval: 5)
            app.terminate()
        }
        print("RESULTADO: \(conError) de \(vueltas) con error en rojo")
        fflush(stdout)
    }
}
