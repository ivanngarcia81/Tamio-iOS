# Lo que hay que acordar con el chat del web

Escrito el **13 de septiembre de 2026**, tras la segunda pasada de QA del
iPhone (`docs/ROTURAS-IPHONE-2.md`). Son tres cosas que **no se pueden arreglar
desde iOS solo**, porque las dos apps escriben en las mismas columnas de
Supabase: tocar un lado sin el otro mueve el problema en vez de cerrarlo.

Van por orden de gravedad. Todas las cifras están medidas en la base de la
iglesia; ninguna se ha cambiado.

---

## 1 · El dinero está en dos unidades distintas · factor de CIEN

> **RESUELTO en iOS el 13-sep, y el web no tiene que tocar nada.** Se quitaron
> las siete conversiones del lado iOS: ahora sube y lee **céntimos**, que es lo
> que el web ya hacía. Queda abierto solo qué hacer con lo ya guardado — ver
> «Lo ya guardado» al final de esta sección.
>
> **Por qué cedió iOS y no el web:** las dos bases locales están en céntimos,
> `iglesias.saldo_inicial` ya es `bigint`, y el céntimo entero es la regla que
> la propia app se escribió. El que se salía era iOS al subir. Que el web no
> tuviera que cambiar es lo que permitió hacerlo sin él.

**Es lo más grave de la pasada.** No es un rótulo: es el importe.

| | qué sube a `transactions.monto` | $500.00 se guarda como |
|---|---|---|
| **iOS** | **unidades** — `Double(fila.monto) / 100.0` (`MotorSincronizacion:2474`, `:2710`) | `500` |
| **web** | **céntimos** — copia la columna tal cual, sin dividir (`sync.ts:520`) | `50000` |

Las dos apps guardan céntimos en su base local. La diferencia está en la
subida: iOS divide, el web no.

**Lo que se ve, medido el 13-sep sobre las 38 filas vivas:**

| origen | filas | mínimo | máximo | con decimales |
|---|---|---|---|---|
| web / semilla | 20 | 10.000 | 1.000.000 | **0** |
| iOS | 18 | 1 | 2.500 | 3 |

Dos poblaciones sin un solo solape. Un movimiento que el web guardó como
**$500.00 el iPhone lo enseña como $50.000**; uno que el iPhone guardó como
**$300.00 el web lo enseña como $3.00**.

**Qué hay que decidir:** cuál de las dos unidades es la buena para
`transactions.monto`. Y después, **convertir las filas del lado que ceda** —son
20 o 18, según lo que se elija—.

**Aviso para no equivocarse al convertir:** las dos poblaciones se distinguen
hoy porque los importes del web son enteros grandes y los de iOS llevan
decimales, pero **eso es una casualidad de estos datos, no una regla**. Un
movimiento de iOS de exactamente $10.000,00 subiría como `10000` y sería
indistinguible de uno del web de $100,00. La conversión hay que hacerla por un
criterio que no dependa de la forma del número: la fecha de corte, el
`registrado_por`, o una columna nueva que diga en qué unidad está.

### Lo ya guardado

**Y aquí la recomendación cambió al mirar los datos de cerca.** No hay dos
poblaciones limpias sino **al menos tres**, y los indicios se contradicen:

| forma de la fecha | autor | filas | mín | máx | con decimales |
|---|---|---|---|---|---|
| ISO con Z | **con** autor | 31 | 1 | 2.500 | 16 |
| ISO con Z | sin autor | 20 | 10.000 | 1.000.000 | 0 |
| sin Z | sin autor | 38 | 20 | 100.000 | 1 |

El grupo de en medio tiene fecha con forma de iOS e importes con forma de
céntimos: son las filas sembradas del **14 y 15 de agosto** —«Carne», «comida»,
«Diezmo», «Luz»—. Y el tercero, del web, tiene un importe con decimales, que en
una columna de céntimos enteros no debería existir.

**Así que no hay una regla segura que separe las unidades fila por fila**, y una
migración a ciegas sobre noventa filas es el tipo de cosa que estropea unos
libros para salvar unas cifras que además son inventadas.

**La recomendación es no migrar: vaciar y volver a sembrar.** Todos los datos
son de prueba —está dicho dos veces en el traspaso—, el código ya escribe bien,
y sembrar de nuevo cuesta menos que revisar noventa filas de procedencia
ambigua. Si por alguna razón hubiera que conservarlas, la migración tendría que
hacerse con **lista explícita de uids revisada a ojo**, nunca con un criterio
basado en la forma del número: un movimiento de iOS de $10.000,00 subía como
`10000`, indistinguible de uno del web de $100,00.

---

## 2 · La categoría se guarda de tres formas, y dos claves significan otra cosa

### El problema, en dos capas

**Capa 1 — iOS guarda la etiqueta traducida, el web guarda la clave.**
`Catalogos.categorias(_:)` devuelve las etiquetas ya traducidas y el `Picker`
persiste lo seleccionado tal cual, así que lo escrito **depende del idioma que
tuviera la app**. El web escribe el `id` de su catálogo.

Resultado: el mismo concepto en hasta tres cubos.

| concepto | formas en la base | filas vivas |
|---|---|---|
| Diezmo | `diezmo` · `Diezmo` · `Tithe` | 9 + 2 + 3 |
| Donación | `donacion` · `Donation` · `Donativo` | 3 + 2 + 1 |
| Otro | `Otro` · `Other` | 1 + 2 |

**Capa 2 — el catálogo del web tiene `id` que ya no dicen lo que significan.**

```
{ id: "eventos",        nombre: "Alimentos"    }
{ id: "musicos",        nombre: "Suministros"  }
{ id: "pastores",       nombre: "Compensación" }
{ id: "administracion", nombre: "Varios"       }
```

iOS resuelve bien **10 de las 15** claves del web. Falla en cinco:

```
otros          → no la reconoce        (web lo llama «Otros»)
administracion → no la reconoce        (web lo llama «Varios»)
pastores       → lo lee «Pastores»     (web lo llama «Compensación»)
musicos        → lo lee «Músicos»      (web lo llama «Suministros»)
eventos        → lo lee «Eventos»      (web lo llama «Alimentos»)
```

**De las cinco, solo `eventos` tiene dinero dentro hoy**, y los conceptos no
dejan lugar a duda: tres gastos de **«Carne», «comida» y «Carne»** que el web
registró como Alimentos y el iPhone enseña bajo **Eventos** en el estado
financiero.

### Qué hay que decidir

1. **Que se guarde la CLAVE y no la etiqueta.** El cambio en iOS es pequeño;
   lo que no se puede hacer solo es elegir el vocabulario.
2. **Qué clave canónica gana donde las dos apps no coinciden**, aunque estén de
   acuerdo en el significado:

   | concepto | iOS | web |
   |---|---|---|
   | Donación | `donativo` | `donacion` |
   | Otro | `otro` | `otros` |

3. **Qué hacer con los cuatro `id` heredados del web** (`eventos`, `musicos`,
   `pastores`, `administracion`): renombrarlos en el web, o enseñarle a iOS que
   significan otra cosa. Lo primero es más limpio y lo segundo no rompe nada
   guardado.
4. **Si se reúne lo ya partido.** Junta cubos y, en el caso de `eventos`,
   **cambia lo que dice el reporte**. Es reversible —es cambiar una palabra por
   otra, no borrar— pero toca las cifras.

**Lo que hay que mirar antes de convertir nada:** los valores en minúscula son
del web y los que empiezan por mayúscula son de iOS. Hoy eso separa las dos
poblaciones sin error, pero es una regularidad observada y no una garantía:
conviene comprobarla sobre los datos el día que se ejecute.

---

## 3 · Los recurrentes se duplicaban entre aparatos · RESUELTO, y el web no entraba

> **RESUELTO en iOS el 13-sep, y resultó no ser cosa de dos repos.** El web
> **no sincroniza `movimientos_recurrentes`** —sincroniza 22 tablas y esa no
> está—, así que sus series son locales suyas y nunca se cruzaron con las de
> iOS. El duplicado era entre **iPhone y iPad**, los dos iOS, sobre la misma
> definición compartida.
>
> El movimiento generado lleva ahora un id derivado —`rec-<recurrenteUid>-<mes>`—
> en vez de un `UUID()` nuevo por aparato, así que el `upsert onConflict: "uid"`
> los reconoce como el mismo apunte. No es un UUID a propósito:
> `transactions.uid` es `text` y un id legible dice de dónde salió la fila.
>
> **Lo que el arreglo no devuelve: el folio.** Cada aparato pide el suyo al
> generar, así que dos aparatos gastan dos números aunque la fila acabe siendo
> una. Eso no tiene arreglo desde ahí: el folio se reserva antes de saber que la
> fila ya existía.
>
> Queda para el web, si algún día quiere sincronizarlos: **la fórmula del id
> tiene que ser la misma**, `rec-<uid de la definición>-<YYYY-MM>`.

### Lo que era, para cuando haga falta releerlo

El movimiento que genera una definición recurrente nace **sin id**
(`RecurrentesRepository:249`) y cada aparato le pone un `UUID()` propio
(`OfflineMovimientosRepository:48`). `alDia` no consulta si ese mes ya se
generó: solo mira `ultimoMesGenerado`.

Así que **dos aparatos que abran la app antes de que la marca sincronice
generan la misma renta dos veces**, con uids distintos, y `transactions` las
acepta las dos: su única restricción es la clave primaria sobre `uid` —no hay
nada único sobre recurrente + mes—. Dos apuntes del mismo gasto y dos folios
consumidos, que no se recuperan.

Lo único que lo evita hoy es que la marca llegue antes. **Eso es una carrera, no
una garantía.**

**Qué hay que decidir:** el arreglo natural es derivar el id de
`recurrenteId + mes`, con lo que el `upsert onConflict: "uid"` que ya usa todo el
motor los reconocería como el mismo apunte. **Tiene que ser la misma fórmula en
las dos apps**, o el duplicado se mueve en vez de cerrarse — el web genera
recurrentes también, y su `skipMes` está citado en el código de iOS.

**Y corre:** las cuatro definiciones de prueba empiezan a generar solas el
**1 de octubre**. La salida barata mientras se decide es **apagar su
interruptor**, que para la serie sin borrar lo ya registrado.

---

## 4 · La política de privacidad viva contradice a la app nativa · 17-sep

**Esto no es un acuerdo de datos: es algo que hay que publicar en la web antes
de que la app nativa se pueda enviar a revisión.** Va aquí porque el sitio lo
lleva el otro chat.

### El problema

Lo vivo en `tamio.church/privacidad.html` (29 de julio) dice, literal:

> «…ni inicio de sesión, no enviamos tu información a ningún servidor…»

La app nativa **no abre sin cuenta** y sincroniza la iglesia entera contra
Supabase. Un revisor de Apple que compare la pantalla de acceso con esa URL
tiene motivo para rechazarla. Y la propia política del 29 se comprometió a
actualizarse *antes* de lanzar nada que enviara datos fuera del aparato.

Además le faltan, cruzado contra `Tamio/PrivacyInfo.xcprivacy`: las fotos de
comprobantes, la **información sensible de afiliación religiosa** —bautismo,
estado de membresía, ministerios—, Face ID, y que el borrado de cuenta ya se
hace desde dentro de la app y es inmediato.

### Lo que hay escrito y listo para publicar

- **`docs/privacidad-propuesta.html`** — sustituye a la viva. Cubre las DOS
  apps con una tabla que las distingue de entrada, en español e inglés, con el
  mismo armazón y los mismos estilos que la página de hoy: entra sin rehacer
  nada. Comprobada en el navegador.
- **`docs/soporte-propuesta.html`** — la URL de soporte, que **no existe**:
  `/soporte`, `/support`, `/contacto` y `/ayuda` dan 404 hoy, y App Store
  Connect la exige para poder enviar.

### Tres avisos para quien las publique

1. **NO se publican desde `Tamio-web`.** Ese repo tiene en `main` —local y en
   el remoto— la privacidad del **20 de julio**, nueve días más vieja que la
   que está viva. Empujar desde ahí haría RETROCEDER la política. Lo vivo es
   byte a byte `Tamio-app/docs/privacidad.html` (mismo md5, comprobado). De
   dónde publica el sitio de verdad, sin averiguar.
2. **Hay CUATRO privacidades en disco** con cuatro fechas: 19, 20, 27 y 29 de
   julio. Editar la que no es no cambia nada, o peor.
3. **Dos correos distintos.** El sitio y la política viva usan
   `ivanngarcia82@gmail.com`; otras copias usan `ig07644@gmail.com`. Elegir uno
   y que sea el mismo en la ficha de App Store, en la política y en soporte.

### El nombre, ya decidido

La ficha nueva se llama **«Tamio Iglesia»** (17-sep), y así está escrito en las
dos páginas. No es un marcador.

«Tamio» a secas no se puede: lo ocupa la app de Tauri, publicada en iOS
(`apps.apple.com/us/app/tamio/id6794741319`). En toda la tienda no hay ningún
otro «Tamio», solo ese.

Y se descartó **«Tamio Pro»** a conciencia, que es la opción que sale sola: la
directriz **4.3** va contra dos fichas del mismo producto y su remedio expreso
es *una sola app con compra integrada*, que es justo lo que este proyecto
evita apoyándose en 3.1.3(c) y (f). Un nombre de gama anuncia en el título que
son la misma app en dos niveles. «Iglesia» dice lo contrario, que es además lo
cierto: una es de un aparato y sin cuenta, la otra es multiusuario con roles.

---

## Cómo se llegó a esto

Las tres salieron de la misma pasada y por el mismo camino: **mirar qué
significa el dato, no qué forma tiene**. La nº 2 salió de que dos movimientos
capturados en modo avión guardaran `Other` en inglés; la nº 1 salió de tirar del
hilo de la nº 2 y mirar los importes de esas mismas filas.

Merece quedar escrito porque la pasada del 12-sep ya había medido los importes y
los dio por buenos: «97 importes, cero desviados». Esa medida era **cierta y no
servía** — comprobaba que un `double` devuelve el mismo número, no que las dos
apps entiendan lo mismo por ese número. **Que un dato vuelva igual no quiere
decir que signifique lo mismo en los dos lados.**
