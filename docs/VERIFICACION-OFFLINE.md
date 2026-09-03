# Guion de verificación — pendiente de hacer en casa

Todo lo de abajo está escrito y compilando, pero **verificado solo por
compilación**: nadie ha tocado aún estas pantallas con el dedo. Este es el
recorrido que lo confirma.

Rama: `revision-y-motor-offline` (12 commits, también en GitHub).
`main` no tiene nada de esto.

## 0. Antes de empezar

1. En Xcode, comprobar que estás en la rama **`revision-y-motor-offline`**.
2. Si Xcode ya estaba abierto, cerrarlo y volver a abrirlo: el `.xcodeproj`
   cambió (se añadió GRDB y 19 archivos nuevos) y a veces no se entera solo.
3. Reinstalar en el iPhone (⌘R).
4. Comprobar que arriba sale la franja naranja **MODO REVISIÓN**. Si no está,
   la instalación no se actualizó y nada de lo de abajo aplica.

> **El modo revisión usa datos de ejemplo y salta el login.** Sirve para
> recorrer pantallas, pero **no ejercita nada de Supabase**: ni folios, ni
> sincronización, ni subida de comprobantes, ni guardado de ajustes. Para
> probar eso hay que apagarlo (`activada = false` en
> `Tamio/Support/ModoRevision.swift`) y entrar con la cuenta real.
>
> Los bloques marcados **[SIN MODO REVISIÓN]** solo valen con el modo apagado.

---

## 1. Inicio

- [ ] "Ver todos" (Últimos movimientos) abre Ingresos.
- [ ] "Agenda" (Esta semana) abre la Agenda.
- [ ] La tarjeta "Por revisar" abre la bandeja. En iPad la tarjeta **entera**
      debe ser tocable, no solo el texto del pie.
- [ ] En iPad, esos enlaces mueven la selección de la sidebar.

Los tres eran texto plano pintado de azul: no hacían nada.

**Sabido y sin arreglar:** las cifras de Inicio (saldo, ingresos, gastos,
gráficas) siguen saliendo de datos de ejemplo.

## 2. Tesorería

- [ ] Los cuatro enlaces abren su pantalla (Movimientos, Aportantes,
      Depósitos, Reportes).

**Sabido y sin arreglar:** los números de esta pantalla ("132 registros · 14
sin depositar", el badge de 1 en Depósitos, "Banorte ••4821") están escritos a
mano en el código y no cambian nunca.

## 3. Aportantes · la ficha

- [ ] En la ficha **ya no aparecen** bautismo, ministerios ni cargos: son del
      padrón y ahora solo están en Secretaría.
- [ ] La pestaña que antes era "Asistencia" ahora es **"Constancia"** y muestra
      ritmo esperado, último aporte y retraso.
- [ ] En la lista, arriba, sale el chip naranja **"N sin aportar últimamente"**
      y al pulsarlo filtra.
- [ ] Quien está atrasado lleva su etiqueta en la fila ("3 semanas").
- [ ] Al editar un aportante hay un selector **"Aporta"** (semanal, quincenal,
      mensual, ocasional).
- [ ] Alguien marcado como **ocasional** nunca aparece como atrasado.

En los datos de ejemplo hay gente al día, con retraso pequeño y ya pasada del
umbral (tres periodos), para que se vean los tres casos.

## 4. Familia · en Secretaría, no en Tesorería

- [ ] En la ficha del **aportante** (Tesorería) la pestaña Familia es de solo
      lectura y dice dónde se editan los parentescos.
- [ ] En la ficha del **miembro** (Secretaría · Membresía) hay una sección
      **FAMILIA** con "Añadir pariente" que funciona y un menos rojo para
      quitar.
- [ ] Al añadir, se puede elegir a alguien del padrón **o** escribir un nombre
      libre (para un hijo pequeño o un cónyuge que no congrega).

**Sabido:** esto vive en memoria; al cerrar la app los parentescos se pierden.

## 5. Documentos PDF

Botón **Documentos** en la ficha del aportante.

- [ ] **Reporte de aportes**: selector Semana / Mes / Año / Rango, tabla de
      aportes del periodo y total. **No lleva firmas** (es informativo).
- [ ] Cambiar el periodo cambia lo que se ve **y** el PDF que se comparte.
- [ ] **Constancia anual**: lleva membrete, identificación fiscal de la
      iglesia, desglose por concepto y **firmas**.
- [ ] El selector de año solo ofrece **años con aportes**.
- [ ] Si faltan datos de la iglesia, sale un aviso naranja **antes** de generar,
      diciendo qué falta.
- [ ] El PDF que se comparte es un PDF de verdad, no texto.

## 6. Ajustes · la iglesia

- [ ] El nombre que se escribe en **Ajustes · Iglesia** es el que sale en el
      **membrete de los PDF**.
- [ ] Los nombres de pastor / tesorero / secretario salen como **firmas** en la
      constancia.
- [ ] El interruptor de firmas las quita del documento.
- [ ] **[SIN MODO REVISIÓN]** Lo escrito **sobrevive a cerrar la app**. Antes no
      se guardaba en ningún sitio.
- [ ] **[SIN MODO REVISIÓN]** Lo configurado en el iPhone se ve igual en el
      iPad. Antes cada uno tenía su propia iglesia.

## 7. CSV · exportar

Menú **Archivo** en Aportantes.

- [ ] **Exportar → Aportantes (CSV)** y **Aportes (CSV)** generan archivo y sale
      la hoja para compartir.
- [ ] Exporta **lo que se está viendo**: con un filtro puesto, salen menos.
- [ ] Al abrirlo en Excel/Numbers: **cada dato en su columna** (no todo
      apelotonado en la primera) y **las tildes bien** ("Márquez", no
      "MÃ¡rquez").
- [ ] **Descargar plantilla** da el mismo formato vacío con una fila de ejemplo.

## 8. CSV · importar

- [ ] **Importar aportantes…** con la plantilla rellenada: sale una pantalla
      que dice **qué va a pasar** antes de tocar nada.
- [ ] Importar **el mismo archivo dos veces** no duplica: la segunda vez todos
      salen como "se actualizarán".
- [ ] Una fila sin nombre sale listada como omitida, **con su número de línea**.
- [ ] **Importar aportes…**: el resumen muestra cuántos son y **cuánto suman en
      dinero** (esa cifra es la que hay que comparar con lo esperado).
- [ ] Un aporte cuyo nombre no coincide con nadie se omite, no crea personas.
- [ ] Reimportar el mismo archivo de aportes los marca como duplicados.
- [ ] Un archivo guardado por **Excel en Windows** (saltos CRLF) se lee bien:
      esto fallaba y no daba error, dejaba todo en una sola fila.

**Sabido:** lo importado no persiste; al cerrar la app se pierde.

## 9. El motor offline — la prueba que importa

**[SIN MODO REVISIÓN]**, con sesión iniciada.

1. [ ] Con red, abrir Ingresos y esperar a que cargue.
2. [ ] **Activar modo avión.**
3. [ ] Capturar un movimiento. Debe guardarse **sin error** y aparecer en la
       lista con folio **`P-…`** (provisional).
4. [ ] **Cerrar la app del todo** y volver a abrirla, aún en modo avión.
       El movimiento debe seguir ahí. Antes esto era imposible: sin red la
       lista salía vacía.
5. [ ] En Ajustes → Sincronización debe verse el número de **cambios sin subir**.
6. [ ] **Quitar el modo avión.** Al volver la app al primer plano sincroniza
       sola (o pulsar "Sincronizar ahora").
7. [ ] El folio `P-…` se convierte en el **definitivo** del servidor.
8. [ ] "Cambios sin subir" vuelve a 0.
9. [ ] Comprobar en Supabase que la fila está en `transactions`.

### Lo que se sabe que aún NO funciona sin red

- **Adjuntar un comprobante**: se sube al elegirlo. Sin señal falla y avisa.
- Solo **Movimientos** usa el motor. Las otras 12 pantallas siguen con datos
  de ejemplo.

## 10. Hoja de captura de movimientos

**[SIN MODO REVISIÓN]** para lo de folios y comprobantes.

Los tres ingresos de prueba:

| # | Qué capturar |
|---|---|
| 1 | Diezmo · $1,000.00 · 3 sep 2026 · Efectivo · Carlos Martínez · constancia SÍ |
| 2 | Donativo · $2,500.00 · 2 sep 2026 · Transferencia · María López (visitante) · concepto "Fondo de construcción" · constancia SÍ · adjuntar PDF |
| 3 | Otro / subcategoría "Reembolso" · $685.50 · 1 sep 2026 · Cheque · State Farm · adjuntar imagen |

- [ ] El menú de **Aportante** trae los miembros reales (Brenda rosado, Carlos
      paz, Juan Martinez, Susana ortiz…), no los cinco nombres inventados.
- [ ] "Otra persona o entidad…" abre un campo para escribir el nombre.
- [ ] "Dar constancia anual" **no** se bloquea con un visitante.
- [ ] Existe el campo **Subcategoría**.
- [ ] Al adjuntar, el botón dice "Subiendo…" y luego el nombre del archivo. Si
      falla, error en rojo y **no** se queda ninguna ruta guardada.
- [ ] Los folios salen correlativos y sin repetirse.
- [ ] Editar un ingreso **no borra** el aportante ni la subcategoría.

Carlos Martínez **no está en el padrón**: o se da de alta como miembro (queda
vinculado y acumula) o se escribe como "otra persona" (nombre sin acumulado).

## 11. Cerrar sesión

- [ ] El botón funciona en iPhone y en iPad (antes no hacía nada).
- [ ] Pide confirmación.
- [ ] Al volver a entrar, no quedan datos de la sesión anterior.

---

## Al terminar

1. Poner `activada = false` en `Tamio/Support/ModoRevision.swift` y commitear.
2. Fusionar `revision-y-motor-offline` a `main`.

## Datos de prueba en Supabase

Tres movimientos con `uid` `prueba-ing-1/2/3`, metidos por SQL para probar el
contador de folios. Aparecerán en Ingresos. Para borrarlos:

```sql
delete from public.transactions where uid like 'prueba-ing-%';
```
