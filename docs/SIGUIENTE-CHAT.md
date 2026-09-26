# Para el siguiente chat · desde la noche del 24 de septiembre de 2026

El mapa para entrar. Lo que pasó está en `CONTEXTO.md`: §0.-26 (la tarde y la noche del 24-sep) y
§0.-25 (el 23 y la mañana del 24). Aquí solo va lo que hace falta para seguir.

**Cómo entrar:** «revisa el repo de Tamio-iOS, rama mac-target, lee `docs/SIGUIENTE-CHAT.md` y
sigamos».

## Dónde está todo

- **Rama de trabajo:** `mac-target`, empujada a GitHub.
- **`main` y `liquid-glass`** están en `449d684`, por detrás, y avanzan en avance rápido hasta
  `mac-target`. **El push a `main` lo hace Iván** desde su terminal: a Claude se lo bloquea el
  clasificador del modo automático («Git Destructive»). El comando:
  `! git -C ~/Desktop/Tamio-iOS fetch . mac-target:main mac-target:liquid-glass && git -C ~/Desktop/Tamio-iOS push origin main liquid-glass`
- **El repo tiene `deny: git push`** en `.claude/settings.json`. Solo aplica si Claude se abre DENTRO
  de `Tamio-iOS`; abierto en `~`, no. Iván decide si se queda (§0.-26).
- **Hay otra sesión, «ivangarcia-c3»**, que también commitea. Antes de commitear, `git status`.
- **Interruptores de DEBUG:** `-mostrarTraerDatos YES`, `-mostrarAcceso YES`, `-modoRevision YES`
  (la maqueta; en inglés es «New Life Church», como la iglesia del revisor).

## Lo listo para la tienda (nada subido)

- **iOS · SUBIDO el 24-sep a las 18:30** a la ficha nueva (Apple ID de la app **6815859389**):
  `~/Desktop/Tamio-ipa/Tamio.ipa` · 1.0.0 (**2026092402**, de `fe54076`) · «Tamio Church»
  bajo el icono. El anterior (2026092401, sin `fe54076`) quedó en `anterior-2026092401/`.
  Receta: `xcodebuild archive` desde el repo tal cual (con `CURRENT_PROJECT_VERSION=…`) y
  `-exportArchive` con `ExportOptions.plist` de esa carpeta y `-allowProvisioningUpdates`.
- **Mac:** `~/Desktop/Tamio-mac/Tamio.pkg` · 1.0.0 (2026092401), **sin `fe54076`**: rehacerlo antes
  de subirlo. **Se sube solo cuando Iván
  quiera que la ficha declare macOS**: desde ese momento el revisor revisa también el Mac.
- **DMG del Mac · PUBLICADO el 25-sep** en tamio.church: release `mac-1.0.0` de `Tamio-app`
  (`Tamio_universal.dmg`, 1.0.0 · 2026092501, universal, macOS 26+), que es la que baja el botón
  «Download for Mac». Firmado con Developer ID (el certificado lo guarda Apple; Xcode lo usa solo)
  y notarizado. Receta, desde `~/Desktop/Tamio-mac/`: `xcodebuild archive` del esquema `TamioMac`,
  `-exportArchive` con `ExportOptions-dmg.plist` (developer-id, destination upload),
  `-exportNotarizedApp` cuando Apple termine, y `hdiutil create` con la app y el acceso a
  Aplicaciones. Necesita `ENABLE_HARDENED_RUNTIME` en `TamioMac`. La release la crea Iván.
- **Capturas:** `docs/capturas-tienda/` (fuera de git): `telefono`, `ipad` → es-MX; `telefono-en`,
  `ipad-en` → en-US; `mac`, `mac-en` → solo con el paquete del Mac.
- **Un build nuevo necesita un número mayor que 2026092501** (el que está en revisión).

## Lo que hace Iván en App Store Connect

> **REENVIADA el 25-sep-2026 por la tarde con el build 2026092501** (de `1950035`): Iván retiró la
> 1.0.0 (2026092402) a las dos horas de enviarla, subió el nuevo con Transporter y la mandó otra vez.
> Trae lo de las contraseñas (ojo, confirmar, las cuatro reglas, el motivo del servidor, la misma
> contraseña) y `webcredentials:tamio.church`. El IPA está en `~/Desktop/Tamio-ipa/`; el 2026092402,
> en `anterior-2026092402/`. **Un build nuevo necesita un número mayor que 2026092501.**
>
> **ENVIADA A REVISIÓN el 25-sep-2026 por la mañana**: iOS 1.0.0 (2026092402), solo iPhone y
> iPad (Mac y Vision Pro desmarcados en Pricing and Availability), publicación **manual** al
> aprobarse, gratis, todos los países. Capturas es-MX y en-US, texto de `FICHA-APP-STORE.md`,
> privacidad publicada con los nueve tipos, edad 4+, nota al revisor con el párrafo «Courtesy».
> La contraseña del revisor se puso por SQL el 24-sep (se salta la política de contraseñas) y
> se comprobó contra `auth.users`; no está en el repo. **Lo que sigue es esperar a Apple** y
> contestar en App Store Connect si pregunta. Los pasos de abajo quedan como registro.

1. ~~Crear la ficha~~ **Hecho el 24-sep:** «Tamio Church», Apple ID 6815859389, SKU `TAMIO-IOS-001`.
2. ~~Subir el IPA~~ **Hecho** (2026092402). Faltan las capturas por idioma.
   El web ya dice «Tamio Church» (`d5ed865` en `pages` de `Tamio-app`, verificado en vivo).
3. **Los tres cuestionarios** (privacidad, edad, exportación): respuestas en `APP-STORE.md` y
   `FICHA-APP-STORE.md`.
4. **Notas para el revisor:** la cuenta `ivanngarcia82+prueba@gmail.com` y su contraseña (va en
   blanco en el repo a propósito), y la cuenta «Courtesy» explicada con la 3.1.3(c) (párrafo PLAN STATUS, añadido a la nota de `FICHA-APP-STORE.md` §5 el 24-sep).
5. **Antes de enviar, revisar la iglesia del revisor** (`809d3b50…`): «New Life Church», Houston,
   USD, 14 miembros, 34 movimientos; cifras al final de `docs/demo-revision.sql`.
6. **Comprobar que la política de privacidad publicada** en tamio.church ya no dice que la app no
   tiene inicio de sesión (el reemplazo está en `docs/privacidad-propuesta.html`). Eso sí bloquea.

## Lo que queda

0. **Cómo llega un cliente nuevo · montado y PROBADO el 25-sep** con `ivanngarcia82+cliente1@gmail.com`
   (descuento `PRUEBA100` del 100 %): cuenta, invitación, iglesia «Mi Iglesia», plan completo activo
   hasta el 25-oct, y la app lo enseña. La contraseña de esa cuenta se puso por SQL. Quedan por
   cancelar su suscripción en Lemon Squeezy y el código `PRUEBA100`.
   Paga en `tamio.church` (Lemon Squeezy) → `pago-webhook` v10, si el correo no tiene cuenta, le
   manda la invitación de Supabase y el disparador `al_crear_usuario` le crea iglesia («Mi Iglesia»)
   y perfil de administrador con el plan pagado → elige contraseña en `invitacion.html` (ya pide
   las cuatro reglas) → baja Tamio Church y entra. Código: `9bf4b87` en `main` y `854ec39` en
   `pages` de `Tamio-app`. **Ojo al probar:** Link (el «Save my information» del cobro) cambia el
   correo del enlace por el guardado; hacerlo en ventana privada. La primera compra entró como
   `ig07644@gmail.com` y la función, bien, no tocó su iglesia de cortesía.
   **Y la portada sigue hablando de la app vieja:** el botón de App Store va a `id6794741319` (la
   de Tauri) y dice que los datos viven en el aparato. Cambiarla cuando Apple apruebe Tamio Church
   (`apps.apple.com/app/id6815859389`), y antes de pulsar «Release».

1. **HECHO el 26-sep: verdes en el iPhone físico** (`f792c28`, 5 pruebas en 220 s) `TextoBruto`,
   `DobleToque` y `FichaAlDia`, ya con la maqueta. La base y las preferencias del iPhone quedaron
   idénticas byte a byte. Lo original: correr en el iPhone físico esas tres.
   El iPhone tiene la versión de desarrollo de `fe54076` y sesión con la iglesia de prueba.
2. **VISTO el 26-sep** (Mac y simulador del iPhone 17 Pro, maqueta, claro y oscuro, con
   interruptores temporales que no quedaron en el código). Padrón vacío y «Hecho» sin conexión:
   bien en los dos. **Arreglado, sin commitear:** la vista previa de los PDF (acta, carta, culto,
   corte, membrete, reportes, constancia: todas pasan por `HojaCartaEscalada`) salía en oscuro con
   hoja negra y letra blanca, y el PDF es papel blanco; y «BORRADOR» casi no se veía y se partía en
   «BORRADO / R». **Y arreglado después, sin commitear:** el botón verde principal (`borderedProminent` +
   `tint`) llevaba texto BLANCO en oscuro, 2,38:1 (iPhone y Mac). Ahora `.etiquetaSobreRelleno()`
   en la etiqueta de los 18 (4 iPhone, 14 Mac): 5,88–7,15:1 en oscuro y 6,28–6,63:1 en claro,
   medidos. En el Mac tiene que ir DENTRO de la etiqueta: sobre el `Button` AppKit lo ignora.
   Apagado no se toca: sale gris, como el sistema. Lo original:
   **Ver en pantalla lo que aún no se ha visto:** el padrón vacío de Membresía (I8 · M6), el aviso
   de sin conexión del «Hecho» de importar, y la vista previa del acta y de la carta en iOS en
   oscuro.
3. **El concepto vacío de un aporte importado** sale como «Aporte», que no es del catálogo. Se
   decide con un archivo real.
4. **HECHO el 25-sep, sin commitear:** en el Mac, la ficha de la iglesia sube al salir de Iglesia,
   Institución o Tesorero y pastor, o de Ajustes entero (`subirFicha` en `PantallaConfiguracion`).
   Antes solo subía al volver la app al frente. Probado con un build firmado con Developer ID
   contra la iglesia de prueba: el estado llegó al servidor en el mismo segundo del ⌘1 y del clic en
   «Account»; la ficha quedó como estaba.
5. **HECHO en código el 25-sep, sale en el próximo build** (iPhone, iPad y Mac): ojo para ver la
   contraseña en la puerta y en «contraseña nueva», el campo «Confirmar contraseña», las cuatro
   reglas escritas y comprobadas antes de enviar (`ReglasContrasena` en `SesionSupabase.swift`), el
   motivo real si Supabase la rechaza, entrar directo si la nueva es igual a la vieja, y el código
   que no se vuelve a canjear en el reintento. El Mac ya no dice «seis cifras». Visto en el
   simulador del iPhone 17 Pro con una prueba de interfaz temporal (no está en el repo); el Mac,
   solo compilado. Lo que sigue es el diagnóstico original:
   **Recuperar la contraseña con la MISMA contraseña gasta el código y despista** (visto el 24-sep
   con la cuenta del revisor, en el build 2026092402). `verifyOTP` pasa, `update(user:)` da 422
   `same_password`, la app enseña «No se pudo cambiar la contraseña» y el reintento dice «Código
   inválido o vencido» porque el código ya se usó. Arreglo: distinguir `same_password` («Esa ya es
   tu contraseña: entra con ella») en `SesionSupabase.cambiarContrasena`, y como `verifyOTP` ya
   dejó la sesión iniciada, entrar directamente. Para la próxima versión.
   **Y peor: la política de contraseñas de Supabase exige minúscula, MAYÚSCULA, número y símbolo**
   (422 `Password should contain at least one character of each…`, visto dos veces el 24-sep a las
   23:58 y 00:01). La app solo dice «al menos 6 caracteres» y esconde el motivo, así que quien
   cambia la contraseña cree que la cambió y luego no entra. Arreglo en iOS, Mac y web: decir las
   cuatro reglas en la pantalla, validarlas antes de enviar y mostrar el mensaje del servidor. De
   paso, el Mac dice «código de seis cifras» y el proyecto manda **8** (Email OTP Length): quitar el
   número del texto. La contraseña del revisor se puso por SQL (se salta la política) y NO está en
   el repo.
   **Y la app no comparte contraseñas con tamio.church.** Sin `webcredentials:tamio.church` en
   Associated Domains ni `/.well-known/apple-app-site-association` en el sitio (da 404), la
   contraseña que el iPhone guarda al activar la cuenta en `invitacion.html` —a menudo una
   «Contraseña segura» que Safari pone solo— no se ofrece al entrar en la app. Visto el 25-sep con
   `+cliente1`: la contraseña se guardó bien (15:28:55) y los dos intentos de entrar fallaron.
   Arreglo: el permiso en la app y el archivo en `docs/.well-known/` de la rama `pages`.
   **HECHO el 25-sep:** `1950035` en la app (va en el 2026092501) y `a226ff1` en `pages` de
   `Tamio-app` (clon en `~/Desktop/Tamio-app`): el AASA responde 200 e `invitacion.html` es un
   <form> con el correo como `username`. El Mac Studio quedó registrado en la cuenta. **Visto de punta a
   punta el 25-sep** en el iPhone con el 2026092501: invitación desde la app a
   `ivanngarcia82+cliente2@gmail.com` (tesorero en la iglesia de prueba), contraseña guardada en
   `invitacion.html` y ofrecida por el Llavero al entrar en Tamio. Iván usa 1Password: también sirve,
   si el elemento lleva el sitio `tamio.church`.
6. **La caída del Mac del 23-sep** (`_postWindowNeedsUpdateConstraints`) sigue sin causa, pero es de
   la familia que se provocó y se quitó el 24-sep. Regla: **en el Mac no se miden anchos en un
   `@State`**; `ViewThatFits`. **Revisado el 25-sep:** ningún `GeometryReader` del Mac guarda medidas en
   un `@State`. El sospechoso que queda es el inspector que se quita y se pone al cambiar de sección
   (`seccionAlimentaElInspector`, desde `56c018c`, 22-sep 10:38; la caída fue al día siguiente).
   No se reproduce: 1,120 cambios de sección con el DMG a 3500, 1150 y 1080 de ancho, mezclando
   ⌘I, cero caídas. El informe `.ips` ya no está en el Mac. Sin reproducirla no se toca.
7. **HECHO el 26-sep, `f792c28`:** `LlaveroMac` en `Tamio/Support/Supabase.swift` guarda la
   sesión del Mac en el llavero de protección de datos (iPhone e iPad siguen con el de la
   librería). **Sin mudanza** desde el antiguo: `kSecUseAuthenticationUIFail` NO quita el aviso
   (probado: salió igual), así que quien venga del DMG 2026092502 entra otra vez, una vez. Visto
   con el build de desarrollo: pantalla de acceso sin aviso, Iván entró, ⌘Q, y al reabrir entró
   directo en «Iglesia de prueba» sin aviso. No probado: cerrar sesión (borra la base del Mac).
   El diagnóstico original:
   **La sesión del Mac vive en el Llavero antiguo** (supabase-swift no usa
   `kSecUseDataProtectionKeychain`), y su permiso queda atado a la firma que lo creó. Visto el 25-sep:
   un build de desarrollo pedía «Tamio quiere usar información confidencial… supabase.gotrue.swift»
   en cada lectura. Quien pase del DMG (Developer ID) a la Mac App Store vería ese aviso. Arreglo
   posible: un `AuthLocalStorage` propio con el llavero de protección de datos (obliga a entrar
   otra vez una vez).
8. **HECHO el 26-sep, `9bb8653`** (visto en pantalla con la maqueta, en claro, a 1391 y 1920 de
   ancho): Intro ya envía la hoja, y «To review» llena el panel con o sin tarjetas. La franja salía
   también CON tarjetas, con la barra de desplazamiento a media pantalla. Lo original:
   **Detalles del recorrido del 25-sep en el Mac:** Intro no envía en la hoja «Reset your password»
   (al botón le falta `.keyboardShortcut(.defaultAction)`); «To review» vacío deja una franja
   blanca a cada lado del fondo gris.

## Cuando se corra la suite en los aparatos

- **Que el aparato NO tenga abierta la iglesia del revisor.** `aparato.sh` ya se niega.
- **iPhone por Wi-Fi:** Bloqueo automático en «Nunca» durante la corrida.
- **Boca abajo** si se prueba el candado: Face ID desbloquea la app solo.
- **Copiar antes la base y las preferencias** del aparato con `devicectl device copy from`.
- **Rojas que se esperan:** las de importar, la ventana del iPad que no se estrecha, AX1 y las que
  buscan filas de la maqueta.
- **Después, mirar qué dejó en la iglesia de prueba** con una consulta a Supabase.

## Para conducir el Mac sin sustos

- Cerrar antes la app de Tamio en los simuladores: System Events confunde los dos procesos «Tamio».
- Navegar por **atajos** (⌘1…⌘9, ⌘0, ⌘,) o por **posición** de fila, nunca por índice: el guion de
  la barra lateral llegó a pulsar «Preparar un respaldo».
- En el Mac, la sincronización corre al arrancar y al volver la app al frente.
