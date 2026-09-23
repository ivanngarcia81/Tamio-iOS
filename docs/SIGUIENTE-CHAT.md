# Para el siguiente chat · desde el 23 de septiembre de 2026

Resumen del chat del 22 al 23 de septiembre para seguir en otro. El detalle está en `CONTEXTO.md`
(§0.-22, §0.-23 y §0.-24) y en `docs/ROJAS-SEPTIEMBRE.md`. Esto es solo el mapa.

**Cómo entrar:** «revisa el repo de Tamio-iOS, rama mac-target, lee `docs/SIGUIENTE-CHAT.md` y
sigamos con los tres puntos».

## Dónde está todo

- **Rama de trabajo:** `mac-target`.
- **Commits sin empujar:** `8540113` (el plan con los rótulos del web) y `74ea547` (fuera el
  «Andamiaje»).
- **`main` y `liquid-glass` van por detrás**, en `0fd3b99`. Hay que avanzarlas con avance rápido
  cuando Iván lo diga.
- **Hay otra sesión, «ivangarcia-c3»**, que también trabaja en el repo: la bienvenida del Mac, el
  icono y la doble cápsula de «Approve». Antes de commitear, mira `git status` y no subas lo suyo.

## Qué se hizo en este chat

1. **Las 44 rojas del iPhone:** ninguna era de la app (`ROJAS-SEPTIEMBRE.md`). La suite ya omite en
   cada aparato las pruebas del otro y lleva `-modoRevision` donde toca.
2. **Fallos reales arreglados:**
   - la configuración inicial se relee después de sincronizar;
   - `titular` (de `Movimiento` y de `Tx`) traduce la categoría: no más «diezmo» con la app en inglés;
   - `destinatarioTipo` guarda la clave y no el rótulo;
   - «Guardar» ya no guarda dos veces;
   - en el iPad, la fila de la firma se toca entera y la sección Institución se puede editar;
   - el plan sale con los rótulos del web.
3. **El Prompt 2** (el equipo que construye el Mac): Traslados, Informes con «Rango», firmar actas,
   Reportes con «Compartir», Duplicar ⌘D e Importar aportantes.
4. **Los PDF que faltaban** (`Tamio/Support`): la hoja de culto, el corte de caja y el acta en el
   Mac. Las piezas de papel viven ahora en `PiezasPDF.swift` y compilan en los dos targets. El
   encargo está en `docs/ENCARGO-HOJA-DE-CULTO.md`.
5. **El Mac, recorrido con capturas:**
   - la sombra salía impresa en el PDF de Reportes;
   - las barras de categorías salían mal proporcionadas;
   - había halos en las vistas previas;
   - los anchos de Reportes y Actas estaban mal.
6. **Las suites en el iPhone y el iPad físicos:** las 253 pruebas de unidad pasan en los dos. De
   las rojas de interfaz, las que quedan son del instrumento o de datos. Hay dos falsos positivos
   documentados en §0.-24: `DobleToque` y el candado.

## Los tres puntos para seguir

### 1. Lo que un usuario vería y no debería
- [x] El «Andamiaje» de la barra de estado (`74ea547`).
- [ ] **Reportes no cabe en media pantalla**: pide unos 1060 pt, desde `5f2b070`, para dejar de
  romperse. Hacerlo caber es rediseño: plegar la lista de tipos. **Lo decide Iván.**
- [ ] **Configuración pide 961 pt**, y media MacBook son 900. Es diseño.
- [ ] La pantalla de acceso no es la del handoff. La bienvenida ya la hizo la otra sesión.

### 2. Decisiones de Iván que siguen abiertas
- [ ] **Los botones que mueven dinero:** Aprobar ⌘R, Marcar depositado ⇧⌘B, Devolver a la bandeja,
  «Nuevo depósito…» desde el Mac y, en Por revisar, «Aprobar todo lo seguro» y «Pedir datos».
- [ ] **Inicio con el inspector abierto:** la propuesta de poner las cuatro tarjetas en 2×2
  (§0.-23).
- [ ] Del zip del diseño: el programa de antes del culto (1b), los otros seis PDF (recibo, padrón,
  informe de membresía, registro de cultos, directorio y bitácora) y «Tamio for Mac», que no se ha
  leído.

### 3. Probar de punta a punta lo que escribe (en la iglesia de prueba)
- [ ] Firmar un acta desde el Mac y que llegue a la web como «aprobada».
- [ ] Importar aportantes hasta el final, no solo abrir la hoja.
- [ ] Una nota de Seguimiento que llegue a la base. Ojo: si el miembro no está en `vm.items`, se
  pierde sin avisar.
- [ ] La configuración inicial en un Mac recién estrenado. Solo está compilada.
- [ ] Informes con «Rango»: las cifras se siguen contando por año, en el ViewModel compartido.

## Cuando Iván tenga el iPhone y el iPad en casa
- La suite completa en los dos, cada aparato con su `TMPDIR`: ver §0.-24.
- **Con el iPhone boca abajo** si se prueba el candado, porque Face ID desbloquea la app solo.
- Ver en el aparato los botones de la hoja de culto y del corte, y la página 2 de la hoja: hace
  falta un culto con más de 11 puntos de orden.
- `testEnIPadSigueLaTabla` falla en el simulador y pasaba en el iPad físico.
- Sembrar los CSV en los aparatos para las pruebas de importar.

## Pequeños pendientes
- Quitar `Tamio/Views/Components/LogoMembrete.swift` del `.pbxproj`: quedó vacío.
- El ancla de «Compartir» del Mac está copiada tres veces (Reportes, Actas y Corte). Merece un
  archivo común.
- La vista previa del acta y de la carta en iOS en modo oscuro: sin comprobar.
- Las pruebas que escriben en la iglesia en cada corrida, como `DobleToque`: ¿pasarlas a la
  maqueta?
- Las notas para el revisor de Apple: la cuenta sale como «Courtesy» y debe explicarse con la
  3.1.3(c) (`docs/APP-STORE.md`).
