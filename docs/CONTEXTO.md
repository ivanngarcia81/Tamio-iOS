# Contexto de trabajo · Tamio-iOS

Este archivo existe para que una sesión nueva —o una persona que vuelve dentro
de un mes— no empiece de cero. **No es documentación del código**: eso ya está
en los comentarios y en los mensajes de commit, que en este proyecto explican
el porqué y no el qué. Aquí va lo que NO se deduce leyendo el repo.

Última actualización: **5 de septiembre de 2026**.

---

## 1. Dónde está el trabajo

Rama viva: **`liquid-glass`**, sincronizada con `origin/liquid-glass`. Es donde
está todo; `main` se quedó muy atrás.

Ramas viejas ya absorbidas aquí, no hace falta volver a ellas:
`arreglos-interfaz`, `arreglos-revision-iphone`, `revision-y-motor-offline`.
`supabase-wip-respaldo` existe **solo en el Mac**, nunca se subió.

---

## 2. Tres avisos que cuestan caro

### 2.1 NUNCA correr `xcodegen generate` en este repo

**Comprobado el 5 de septiembre, no es una leyenda.** El `project.yml` **no
declara los paquetes SPM**: GRDB y supabase-swift se añadieron a mano desde
Xcode y viven solo en el `.pbxproj`. Al regenerar, el proyecto sale sin ellos y
la compilación muere con `unable to resolve module dependency: 'GRDB'`.

El `.pbxproj` está editado a mano y hay que seguir editándolo a mano al añadir
archivos nuevos. **Si puedes, evita el archivo nuevo**: mete el código en un
archivo que ya exista y el `.pbxproj` no se toca. Así se añadió
`sinBotonVolver()` dentro de `Support/NavHeader.swift`.

### 2.2 El modo revisión está ENCENDIDO

`Support/ModoRevision.swift` tiene `activada = true`: la app salta el login y
sirve datos de ejemplo. Con él encendido **no se ejercita nada de Supabase** —
ni folios, ni sincronización, ni subida de comprobantes—, y los repositorios
que se inyectan son los `Mock*`, no los `Offline*`.

Para probar de verdad hay que ponerlo en `false` y entrar con la cuenta real.
Está dentro de `#if DEBUG`, así que un olvido no llega a la App Store.

### 2.3 Compilar no es verificar

Casi todo lo escrito en las últimas semanas está **verificado solo por
compilación**. Ha pasado ya al menos una vez que algo compilaba, no daba ni
error ni aviso, y estaba roto en pantalla: el sistema descartó en silencio la
quinta cápsula de la barra y Ingresos se quedó **sin botón de crear**.

---

## 3. Cómo verificar en la app corriendo sin tocar el `.pbxproj`

Receta que funcionó el 5 de septiembre y que conviene repetir tal cual:

1. Copiar el repo a un directorio temporal (`rsync -a --exclude .git
   --exclude Tamio.xcodeproj`).
2. En la COPIA, añadir al `project.yml` un target de `bundle.ui-testing` con
   `GENERATE_INFOPLIST_FILE: YES`, **y los paquetes que faltan**:

   ```yaml
   packages:
     GRDB:     { url: https://github.com/groue/GRDB.swift,        majorVersion: 6.29.0 }
     Supabase: { url: https://github.com/supabase/supabase-swift, majorVersion: 2.5.1 }
   ```

3. `xcodegen generate` **en la copia** (nunca en el repo), compilar y correr
   XCUITest ahí.

Detalles que hacen perder tiempo si no se saben:

- Hay varios simuladores arrancados a la vez: `xcrun simctl io booted
  screenshot` coge el equivocado. **Usar siempre el UDID.**
- Al añadir un archivo de test hay que volver a correr `xcodegen` en la copia,
  o el test no entra en el bundle y sale "Executed 0 tests".
- Para fotografiar un estado transitorio: que el test imprima una marca y se
  duerma, y desde el shell esperar la marca y disparar `simctl io <udid>
  screenshot`.
- Las filas del hub no se localizan por su título: su etiqueta de
  accesibilidad es `"Transactions, 28 records · 19 undeposited"`. Usar
  `label BEGINSWITH`.
- El iPhone más estrecho con iOS 26 disponible es el **17e** (390 pt). Probar
  ahí y **en inglés**, que es donde las etiquetas son más largas.

---

## 4. Cosas ya medidas · no volver a discutirlas

- **`navigationBarBackButtonHidden` apaga el gesto de volver** en iOS 26.
  Medido con XCUITest: con botón visible el deslizamiento vuelve, ocultándolo
  no. Por eso existe `sinBotonVolver()` en `Support/NavHeader.swift`, que lo
  oculta Y devuelve el reconocedor. **No poner el delegado a `nil`**: eso deja
  el gesto armado también en la raíz, donde no hay nada que desapilar.
- **`.disabled` sobre `.buttonStyle(.glass)` da 1.70:1 de contraste** (el
  mínimo para texto normal es 4.5:1): la etiqueta se borra. No es culpa del
  `tint` —sin él sale el mismo número— y `.secondary` tampoco basta: 3.29:1.
  Lo que sí funciona es `.primary` rebajado: 8.4:1 en claro y 8.3:1 en oscuro.
- **El ancho del segmentado NO era la causa** de que la barra truncara. Se
  probó dos veces, y a 160 pt fijos truncaba igual. Sobraba un control.

---

## 5. Estado por zonas

### Recurrentes — escrito entero, sin probar en aparato

Cuatro commits del 4 de septiembre: modelo (`MovimientoRecurrente`, tabla
propia, **v14** local + `movimientos_recurrentes` en Supabase),
materializador, sincronización e interfaz.

**Lo que falta comprobar, y solo se ve con dos aparatos reales:**

- Que la migración **v14** corre sobre una base que ya tiene datos.
- Que la definición sube y baja de Supabase.
- **La idempotencia entre aparatos**: que al cerrar el mes la renta se genera
  UNA vez y no una por aparato. La marca `ultimoMesGenerado` la puede mover
  otro aparato; por eso la definición baja ANTES de materializar.

### Barra y pie de las listas — hecho y verificado el 5 de septiembre

El chevron se fue de las pantallas que cuelgan de un hub (la pestaña lleva al
mismo sitio), los filtros volvieron arriba y el pie de lista desapareció.

Verificado con la app corriendo en iPhone 17e y en inglés: el `+` está visible
y pulsable en Ingresos y en Gastos, el segmentado se lee entero y el gesto de
volver funciona.

Dónde acabó cada dato del pie:

| Pantalla | Antes, en el pie | Ahora |
|---|---|---|
| Ingresos/Gastos | conteo · mes · total | total y conteo encabezan la hoja de filtros; el mes ya estaba dentro |
| Aportantes | conteo · año · total | conteo en la etiqueta del menú (`Activos (9)`); año y total en su cabecera. **En iPad el pie se queda** |
| Depósitos | cortes pendientes · monto | a la cabecera, y no se dibuja con cero |

### Depósitos — un corte NO se llena solo

Preguntado y confirmado en el código el 5 de septiembre. "Nuevo corte" pide
**solo título y cuenta**; nace **vacío, en $0**. Se llena desde su ficha con
**"Agregar dinero sin depositar"**, que ofrece los ingresos que no estén ya en
otro corte (`LEFT JOIN corteMovimiento ... where cm.id is null`).

Es deliberado: un corte es *"este dinero concreto que llevo al banco hoy"*, y
casi siempre es parcial. La tabla puente en Supabase son dos columnas,
`corte_uid` y `tx_uid`, sin monto ni copia: el total nunca puede desviarse de
la suma de sus movimientos.

### Cifrado local — decisión pendiente

Ver `docs/CIFRADO-LOCAL.md`. Recomendación escrita: **opción A ahora, B cuando
exista restaurar**. Faltan dos medidas antes de decidir: la clase de
protección real de `tamio.sqlite` **en el iPad** (el simulador no implementa
Data Protection) y qué protección le queda al respaldo en iCloud Drive.

---

## 6. Pendientes concretos

1. **El mes es invisible en Ingresos.** Al quitar el pie, el mes solo se lee
   abriendo la hoja de filtros: en agosto las cabeceras dicen "VIERNES 29" y el
   mes no aparece en ninguna parte. Y `filtrosActivos` **no cuenta el periodo**,
   así que el botón no se tiñe al mirar un mes que no es el actual — una lista
   corta no se explica sola. Se arregla sumando el mes al contador.
2. **El total de Movimientos en iPad** ya solo vive en la hoja de filtros. Allí
   el pie no causaba ninguno de los tres problemas del teléfono.
3. **Verificar los recurrentes en aparato** (§5). Es el riesgo real que queda.
4. **Las dos medidas del cifrado** (§5).
5. Observación sin acción: el hub dice "Transacciones · 29 registros" y la
   lista dice "16 movimientos". No es un error —una suma ingresos y gastos, la
   otra solo el tipo activo— pero se leen como el mismo número.

---

## 7. Cómo se escribe aquí

Los mensajes de commit son **frases que cuentan el problema**, no resúmenes del
cambio: *"El interruptor decía que se repetía y el mes siguiente no aparecía
nada"*. El cuerpo explica el porqué, lo que se descartó y con qué medida se
decidió. Los comentarios del código siguen el mismo criterio: dicen por qué
está así, no qué hace.

Los números se miden, no se estiman. Cuando un comentario dice "medido en
pantalla", es que se midió de verdad.
