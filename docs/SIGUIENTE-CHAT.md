# Para el siguiente chat · desde el 24 de septiembre de 2026

El mapa para entrar. Lo que pasó en el chat del 23 y 24 de septiembre está en `CONTEXTO.md`,
§0.-25. Aquí solo va lo que hace falta para seguir.

**Cómo entrar:** «revisa el repo de Tamio-iOS, rama mac-target, lee `docs/SIGUIENTE-CHAT.md` y
sigamos».

## Dónde está todo

- **Rama de trabajo:** `mac-target`, empujada a GitHub en `8a4f3da`.
- **`main` y `liquid-glass`** están en `449d684`, por detrás. Se avanzan en avance rápido cuando
  Iván lo diga, y **el push a `main` lo hace Iván** desde su terminal, porque a Claude se lo bloquea
  el clasificador de permisos:
  `! git -C ~/Desktop/Tamio-iOS fetch . mac-target:main mac-target:liquid-glass && git -C ~/Desktop/Tamio-iOS push origin main liquid-glass`
- **Hay otra sesión, «ivangarcia-c3»**, que también commitea en el repo. Antes de commitear, mira
  `git status`.
- **Interruptores de DEBUG para mirar pantallas sin tocar la sesión:**
  - `-mostrarTraerDatos YES`: la invitación de «Trae tus datos», en el Mac y en iOS;
  - `-mostrarAcceso YES`: la pantalla de acceso del Mac;
  - `-modoRevision YES`: la maqueta.

## Antes de mandar la app a Apple

- **Revisar la iglesia del revisor** (`809d3b50-810f-433b-a0d2-f3413ca49637`). Debe ser
  «New Life Church», Houston, USD, con 14 miembros y 34 movimientos. Se contaminó una vez
  (§0.-25) y se restauró el 24-sep. Ese mismo día Iván la pasó al inglés, entera, con
  `docs/demo-revision.sql` (antes era «Iglesia Nueva Vida», Monterrey, MXN). Solo los nombres de
  las personas siguen siendo hispanos. Las cifras que debe dar están al final de ese archivo.
- **Las capturas de la ficha, rehechas el 24-sep**, en español y en inglés
  (`docs/capturas-tienda/{telefono,ipad}{,-en}/`, cuarenta en total). Las de inglés enseñan «New
  Life Church», como la cuenta del revisor. Falta subirlas a App Store Connect.
- **La contraseña del revisor** en la nota de `FICHA-APP-STORE.md`, que va en blanco a propósito.
- **Las notas para el revisor:** explicar la cuenta «Courtesy» con la 3.1.3(c) (`APP-STORE.md`).

## Lo que queda

1. **Las pruebas que escriben en la iglesia, ya en la maqueta** (24-sep): `TextoBruto`, `DobleToque`
   y `FichaAlDia` llevan `-modoRevision YES`, y las cinco pasan en el simulador. `TextoBruto`
   mide ya el nombre largo, y `FichaAlDia` borra con `typeText`, porque `app.keys["Delete"]` no se
   deja pulsar. Falta correrlas en el iPhone físico. La iglesia de prueba puede traer aún el
   nombre que le dejó `TextoBruto` antes del arreglo: mirarlo en Supabase.
2. **Ver en pantalla lo que aún no se ha visto:**
   - el padrón vacío de Membresía (I8 · M6);
   - el aviso de sin conexión del «Hecho» de importar;
   - la vista previa del acta y de la carta en iOS en modo oscuro.
3. **El concepto vacío de un aporte importado** sale como «Aporte», que no es categoría del
   catálogo. Se decide cuando haya un archivo real de una iglesia.
4. **Handoff 8, hecho en el Mac (24-sep):** Reportes y Configuración caben a 900 pt, plegando su
   columna (lista flotante en Reportes, riel de iconos en Configuración), y el Registro de servicios
   apila sus paneles. La pantalla de acceso ya no tenía las dos piezas del §7. Visto a 900 y a
   pantalla completa, y las 15 secciones a 900 sin caída.
5. **Queda para Iván, del Mac:**
   - la tira de 8 indicadores de Membresía recorta seis rótulos a 900 («Remo…», «With a…»), y el
     diseño tampoco lo resuelve (8 columnas fijas);
   - el inspector a 900: el diseño lo hace flotar encima; la app lo deja como está (⌘I).
6. **Las caídas del Mac, `_postWindowNeedsUpdateConstraints` al plegar el inspector o la barra
   lateral.** El 24-sep la primera versión del plegado las provocaba (un `@State` con el ancho medido
   que cambiaba la vista a mitad del layout): 9 idas y vueltas Inicio↔Reportes. Con `ViewThatFits`,
   50 idas y vueltas y 40 pliegues de la barra sin caída. La del 23-sep (10:43, antes de este cambio)
   era de la misma familia y sigue sin causa conocida: **no medir anchos en un `@State`** en el Mac.
7. **La iglesia de prueba volvió a tener el nombre de 500 caracteres** de `TextoBruto` en Supabase
   (subido a las 13:43 UTC del 24-sep, cuando por la mañana decía «Iglesia de prueba»). Algún
   aparato con la ficha vieja la volvió a subir encima. Mirar quién y por qué.

## Cuando se corra la suite en los aparatos

- **Revisar que el aparato NO tenga abierta la iglesia del revisor.** `aparato.sh` ya se niega,
  pero conviene saberlo.
- **iPhone por Wi-Fi:** Bloqueo automático en «Nunca» durante la corrida, o se cae con «Not
  authorized for performing UI testing actions».
- **Boca abajo** si se prueba el candado: Face ID desbloquea la app solo.
- Cada aparato con su `TMPDIR`, y los dos a la vez sin problema.
- **Copiar antes la base y las preferencias** del aparato con `devicectl device copy from`.
- **Rojas que se esperan:** las de importar (faltan los CSV en Archivos del aparato), la ventana del
  iPad que no se estrecha, AX1 y las que buscan filas de la maqueta.
- **Después, mirar qué dejó en la iglesia de prueba** con una consulta a Supabase.
