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
- **Capturas:** `docs/capturas-tienda/` (fuera de git): `telefono`, `ipad` → es-MX; `telefono-en`,
  `ipad-en` → en-US; `mac`, `mac-en` → solo con el paquete del Mac.
- **Un build nuevo necesita un número mayor que 2026092402.**

## Lo que hace Iván en App Store Connect

1. ~~Crear la ficha~~ **Hecho el 24-sep:** «Tamio Church», Apple ID 6815859389, SKU `TAMIO-IOS-001`.
2. ~~Subir el IPA~~ **Hecho** (2026092402). Faltan las capturas por idioma.
   **El web dice «Tamio Iglesia»** en la privacidad y en soporte: cambiarlo a «Tamio Church».
3. **Los tres cuestionarios** (privacidad, edad, exportación): respuestas en `APP-STORE.md` y
   `FICHA-APP-STORE.md`.
4. **Notas para el revisor:** la cuenta `ivanngarcia82+prueba@gmail.com` y su contraseña (va en
   blanco en el repo a propósito), y la cuenta «Courtesy» explicada con la 3.1.3(c).
5. **Antes de enviar, revisar la iglesia del revisor** (`809d3b50…`): «New Life Church», Houston,
   USD, 14 miembros, 34 movimientos; cifras al final de `docs/demo-revision.sql`.
6. **Comprobar que la política de privacidad publicada** en tamio.church ya no dice que la app no
   tiene inicio de sesión (el reemplazo está en `docs/privacidad-propuesta.html`). Eso sí bloquea.

## Lo que queda

1. **Correr en el iPhone físico** `TextoBruto`, `DobleToque` y `FichaAlDia`, ya con la maqueta.
   El iPhone tiene la versión de desarrollo de `fe54076` y sesión con la iglesia de prueba.
2. **Ver en pantalla lo que aún no se ha visto:** el padrón vacío de Membresía (I8 · M6), el aviso
   de sin conexión del «Hecho» de importar, y la vista previa del acta y de la carta en iOS en
   oscuro.
3. **El concepto vacío de un aporte importado** sale como «Aporte», que no es del catálogo. Se
   decide con un archivo real.
4. **En el Mac, guardar la ficha de la iglesia no dispara la sincronización**: sube al volver la app
   al frente o al arrancar. Era así antes; decidir si se sube al momento.
5. **La caída del Mac del 23-sep** (`_postWindowNeedsUpdateConstraints`) sigue sin causa, pero es de
   la familia que se provocó y se quitó el 24-sep. Regla: **en el Mac no se miden anchos en un
   `@State`**; `ViewThatFits`.

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
