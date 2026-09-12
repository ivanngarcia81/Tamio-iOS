# Roturas del iPhone · segunda pasada de QA · 12 de septiembre de 2026

> **En curso.** Medido **en el iPhone 17 Pro Max de Iván** (iOS 27.0, UDID de
> hardware `00008150-0005793E3EC0401C`), con su cuenta y sus datos, sobre
> `liquid-glass` en `66d6f3e`. Los datos del aparato son ficticios.
>
> El instrumental de aparato quedó rehecho y es reutilizable:
> `pruebas/aparato.sh`. La tabla de con-qué-se-sustituye-cada-cosa está en
> `pruebas/LEEME.md`, «El instrumental DE APARATO, sustituido».

## Cuatro premisas del encargo que no se sostuvieron

El encargo avisaba de que sus propias líneas había que tratarlas como
sospechosas, porque su v1 ya había tenido una premisa falsa. Tuvo cuatro más.
Van primero porque es la mitad del valor de la pasada.

1. **«Los 18 commits del 11-sep están sin empujar.»** Lo decía la memoria de
   sesión. `origin/liquid-glass` está al día en `66d6f3e`: se empujaron.

2. **«Según el traspaso del 10-sep no hay ninguna cuenta de secretaria.»** El
   encargo pedía confirmarlo antes de darlo por cierto, y hacía bien: **sí la
   hay**. En `perfiles` hay 4 administradores, 2 tesoreros y **1 secretaria**
   (`Ivang`). El Z1·5 no estaba bloqueado esperando a que Iván creara una
   cuenta.

3. **«Las cuatro pruebas de aparato están escritas y nunca se han corrido.»**
   **Tres ya corrieron**, el 11-sep desde el iPad, y están apuntadas en
   `pruebas/LEEME.md`: `ActualizarLlegaAlServidorTests` (4,6 s),
   `CorreccionLlegaAlServidorTests` (2,9 s) y `PDFDeVerdadTests` con los tres
   documentos mirados. La que faltaba era `CortesYDepositosUITests`, y **hoy
   pasa en el teléfono**, por la forma del teléfono (`QA-FORMA:telefono`).
   La que de verdad estaba escrita y sin correr era otra: `InterfazAparatoUITests`.

4. **«A los movimientos la fecha que retrocede NO les alcanza.»** Es el hallazgo
   nº 1 de abajo. La v1 del encargo dijo «toda fecha», la v2 lo corrigió a «los
   movimientos no», y la v2 también se equivocaba.

---

## Los hallazgos, por severidad

### 1 · 38 de 84 movimientos enseñan el día Y la hora equivocados · pierde datos

**Severidad: alta.** Es contabilidad de una congregación y la fecha del apunte
está mal en casi la mitad de las filas.

**La premisa que lo tapaba.** El traspaso tenía escrito que a los movimientos
no les alcanza, porque guardan `fecha` como `timeIntervalSince1970` —un
instante— y formatearlo en la zona del aparato es lo correcto. El razonamiento
es bueno; la premisa de la que salía, no. Se apoyaba en una medida del 10-sep:
*«`transactions` es la ÚNICA tabla cuyas fechas llevan hora, 34 de 34»*.

**Lo que hay hoy.** `transactions.fecha` es **`text`** —ni `date` ni
`timestamptz`—, así que la base no le impone forma a nadie y cada cliente
escribe la suya. 84 filas, tres formas:

| forma | filas | quién la escribe |
|---|---|---|
| `2026-09-11T13:16:07Z` | 46 | la app nativa |
| `2026-07-12 02:28` | 33 | la app web |
| `2026-07-27` | 5 | la app web |

`Fechas.desdeTexto` (`Support/Fechas.swift:88`) prueba
`yyyy-MM-dd'T'HH:mm:ss`, `yyyy-MM-dd HH:mm:ss` y `yyyy-MM-dd`. **Ninguno es
`yyyy-MM-dd HH:mm`**: la forma de la web no casa con la que pide segundos,
`DateFormatter` acepta solo el prefijo del día y devuelve **medianoche UTC**.

**La reproducción**, medida en el aparato con `pruebas/FechasDelServidorTests.swift`,
5 pruebas en verde en `America/New_York`:

```
QA-ZONA: America/New_York desvío -14400s        ← control positivo
QA-SINSEG: 2026-07-12 02:28 -> 2026-07-12T00:00:00Z
QA-DIA: 2026-07-27 -> local «Jul 26, 2026» · UTC «Jul 27, 2026»
QA-DISCREPA: desdeTexto «Jul 26, 2026» · diaDeCalendario «Jul 27, 2026»
```

**Y no se queda en el día.** `MotorSincronizacion.swift:2843-2859` deriva la
hora del mismo instante con un `DateFormatter` **sin zona**:

```swift
let fechaDate = Fechas.desdeTexto(fecha) ?? Date()
let hf = DateFormatter()          // ← sin timeZone: la del aparato
hf.dateFormat = "HH:mm"
... hora: hf.string(from: fechaDate),
    fecha: fechaDate.timeIntervalSince1970
```

Así que un movimiento que la web guardó el **12 de julio a las 02:28** el
teléfono lo enseña el **11 de julio a las 20:00**. No es un día desplazado: son
el día y la hora perdidos, y la hora **no se recupera** porque nunca llegó.

**Cómo quedó: MEDIDO Y NO ARREGLADO, a propósito.** Arreglarlo es fijar la
convención de fechas de las **dos** apps, y son 38 filas ya escritas. La media
solución está escrita desde el 10-sep —`Fechas.diaDeCalendario` (`:130`),
medianoche **local** para la forma canónica— y hoy solo la usa
`Miembro.swift:475`. Su comentario explica por qué la alternativa obvia no
sirve: pasar la escritura a UTC rompe la nota nueva, que nace con `Date()`.

**Los sitios que parsean un día de calendario por el camino viejo** —que es el
inventario que faltaba, porque el encargo listaba los sitios de FORMATEO y el
defecto está en el PARSEO—:

| sitio | qué lee |
|---|---|
| `Views/MembresiaView.swift:1010, 1012, 1014, 1021, 1261` | ingreso, nacimiento, congregación, baja, y un campo genérico |
| `Data/ImportadorAportes.swift:117` | la previa del importador de aportes |
| `Data/AgendaRepository.swift:106` | la fecha del evento de agenda |
| `Models/Secretaria.swift:200, 212, 896` | tres sitios |
| `ViewModels/InformesMembresiaViewModel.swift:338` | la última asistencia |
| `Data/ServiciosRepository.swift:385` | la clave de mes, `"\(clave)-01"` |
| `Data/Local/MotorSincronizacion.swift:2843` | **la fecha del movimiento** |

`Data/Local/BaseLocal.swift:482` **no** cuenta: solo comprueba validez
(`== nil`). Y `Models/Miembro.swift:475` es el único ya arreglado.

**Lo que bloquea el arreglo y es decisión de Iván:** el iOS no puede arreglar
esto solo. Las 38 filas las escribió la app web, así que la convención se
acuerda con el otro chat antes de tocar nada aquí.

**La lección, que es de caducidad:** *una medida sobre los datos no es una regla
sobre el esquema.* La del 10-sep era cierta cuando se tomó —34 de 34— y dejó de
serlo al crecer la tabla a 84. La conclusión que colgaba de ella sobrevivió a la
medida que la sostenía.

---

### 2 · El barrido visual del aparato pasaba en verde midiendo 2 de 15 secciones

**Severidad: instrumento, y de los caros.** `pruebas/InterfazAparatoUITests.swift`
se escribió el 11-sep para el iPad y quedó **compilada y sin correr** porque el
iPad contestaba *«Timed out while enabling automation mode»*. Hoy corrió en el
iPhone, y su prueba de barrido **pasó en 228 segundos**:

```
QA-BARRIDO (antes): SALTADA ×13 de 15 · SECCIÓN Inicio · SECCIÓN Por revisar
VENTANA: (440.0, 956.0)
```

Dos causas, las dos de forma y ninguna del producto:

- **`vaA` buscaba botones de primer nivel**, que es el patrón de la **sidebar**
  del iPad. El teléfono tiene cinco pestañas —Inicio, Tesorería, Por revisar,
  Secretaría, Ajustes— y las quince secciones cuelgan de un hub dentro de cada
  una. Es el mismo tropiezo que `CortesYDepositosUITests` ya tenía documentado
  al revés, y que allí se arregló distinguiendo la forma.
- **Forzaba apaisado.** `XCUIDevice.shared.orientation = .landscapeLeft` en el
  iPhone **no rota nada y no falla**, porque el teléfono es solo vertical a
  propósito (`project.yml:69`). La prueba se creía midiendo otra postura.

Y el silencio, que es lo que la hacía inútil: el barrido hacía `continue` en
cada sección que no encontraba y **no afirmaba nada**. Trece saltadas y verde.
Es la misma familia que el `-only-testing` que no casa con ninguna clase.

**Cómo quedó: ARREGLADO.** La navegación distingue teléfono de iPad y lleva el
mapa de qué pestaña abre cada sección; cuando una sección no aparece, vuelca los
rótulos del hub para que la vuelta siguiente no adivine. Y el barrido **cuenta
lo medido y falla si falta alguna**: una prueba que se salta su objeto tiene que
fallar, igual que una que lo mira y no le gusta.

Dos avisos que salieron de aquí:

- `Registro` cuelga de **Secretaría**, no de Ajustes (`IPhoneSecretariaView:136`).
  Y `label BEGINSWITH "Registro"` casa **antes** con «Registro de servicios», así
  que abriría la sección equivocada sin decir nada: se compara exacto primero.
- **Dos capturas de dos pruebas distintas salieron byte a byte idénticas**
  (`qa-informes-filtros.png` y `qa-miembro-ficha.png`, mismo md5). Es la forma
  más rápida de saber que la navegación no se movió. Merece ser un control.

---

## Lo que se atacó y aguantó

Una pasada también sirve para dejar de sospechar.

### El importe en coma flotante · riesgo latente, no defecto activo

En Supabase el importe es `double precision`, contra la regla que la app se
escribió. **Medido: 97 importes en las tres tablas, cero desviados.**

```
transactions             84 filas · 0 no exactos · 0 fuera de epsilon · suma 3.147.157,37
depositos_bancarios       9 filas · 0 · 0
movimientos_recurrentes   4 filas · 0 · 0
```

Ni un valor con más de dos decimales, ni uno en notación científica. **Y el
motivo está escrito en el código**, que es lo que lo hace fiable y no suerte:
las tres bajadas redondean al entrar —`Int(((monto ?? 0) * 100).rounded())` en
`MotorSincronizacion:2562`, `:2776` y `:2858`— y las subidas dividen
(`Double(fila.monto) / 100.0`). La fila local guarda `monto` como **`Int`**
(`MovimientoFila.swift`), o sea céntimos: la regla de la app se sostiene en el
cliente y se pierde solo al cruzar a la columna.

**La asimetría que sí conviene escribir con el número delante:** de las cuatro
columnas de dinero del servidor, **`iglesias.saldo_inicial` es `bigint`** y las
otras tres son `double precision`. La regla de la app está aplicada en una de
cuatro. El riesgo no es la deriva de hoy, es que el otro cliente escriba ahí sin
el `.rounded()`.

### El Ajustes del teléfono · la zona que prometía dar algo, y no dio

El encargo tenía razón en el diagnóstico: `Tamio/Views/IPhoneAjustesView.swift`
son **1.895 líneas** y `git log --since=2026-09-11 --` sobre él sale **vacío**,
así que no recibió ninguno de los dieciséis arreglos de la pasada del iPad.
Medido con la vara del iPad, aguanta:

- **Los tres radios son UNA proporción, no deriva.** 10/44 = 0,227 · 7/32 =
  0,219 · 14/64 = 0,219. Dispersión 0,008. El §0.-10 tiene medido que el radio
  de una baldosa de icono es una proporción y no un token, y estos tres la
  cumplen entre sí. Quedan por debajo de la banda del iPad (0,25–0,29), que es
  una inconsistencia entre aparatos de menos de 1 pt por baldosa; tokenizarla
  movería valores para quitar una deriva que no se ve.
- **Cero `frame(height:)` en filas.** La clase de fallo que el iPad dio a
  puñados —«tres filas idénticas a 50 y 52 pt», «las cuatro acciones repartidas
  2-2»— **no puede existir aquí**: el teléfono usa un `List` y deja que el
  sistema mida. Los `padding(.vertical)` se agrupan por rol: 6 en las dos filas
  de perfil, 2 en dos, 5 en dos, 4 en siete.
- **La doble cabecera de perfil no es un duplicado.** La de 44 pt es la fila del
  índice (`IPhoneAjustesView:111`, `NavigationLink` a `.cuenta`) y la de 64 es la
  cabecera de su pantalla destino (`AjustesCuentaView:257`). Mismo rol, escalas
  distintas a propósito. No es el caso de `ConfiguracionView.listaCompacta`.
- **El Dynamic Type no es el problema**, como avisaba el encargo: un solo
  `.system(size:)` y cero `Font.escalada`, y ese único es el glifo de un icono
  dentro de una baldosa de 32 pt fija, donde fijo es lo correcto.

### Cortes y depósitos, abiertos en el teléfono

`CortesYDepositosUITests` **pasa** (54 s), entrando por
`app.tabBars.buttons["Treasury"]`.

**Aviso: su marca no mide lo que su nombre sugiere.** `QA-CELDAS-DEPOSITOS:3`
cuenta `app.cells` filtrado por `isHittable`, o sea celdas **visibles en
pantalla**, no depósitos. El servidor tiene 9 filas en `depositos_bancarios`, 3
borradas y **6 vivas**: el 3 no las contradice. Es el caso de
`ActasTrasSincronizarTests` otra vez —el repositorio filtra `borrado == false`
y parece que pierde datos—, y por eso no es hallazgo.

---

## Lo que queda abierto de esta pasada

- El barrido de las 15 secciones **con la navegación arreglada**, que es lo que
  iba a dar los desbordes de verdad. Bloqueado: el teléfono se bloqueó a mitad
  y `xcodebuild` **espera en silencio**, no falla — *«Run Destination
  Preflight: The destination is not ready … Unlock iPhone to Continue»*, y se
  queda ahí indefinidamente. **Aviso de instrumento nuevo:** un aparato
  bloqueado no da error, cuelga la corrida.
- **Z1·2, la idempotencia del reintento.** Confirmado en el código lo que el
  encargo decía: once subidas pasan por `exigir(_:tabla:_:)`
  (`MotorSincronizacion:463`) y **cinco no** —`cortes` (`:2253`),
  `corte_movimientos` (`:2285`), depósitos (`:2480`), categorías (`:2604`) y
  recurrentes (`:2716`)—, así que suben sin comprobar que tocaron algo. Sin
  ejercitar con red.
- **Z1·5, los roles contra RLS**, que ya no está bloqueado: la cuenta de
  secretaria existe. Faltan las credenciales para entrar con ella.
- Z2 (las diez presentaciones de `CorteDetalle` y `ActasView`), Z3 (los PDF en
  el límite), Z6 (los recurrentes del 1 de octubre) y Z7 (el texto bruto en el
  membrete).
- **Z7 arranca con un silencio ya localizado:** `pruebas/TextoBrutoUITests.swift`
  declara la clase **`TextoBruto`**, así que un `-only-testing` con el nombre
  del archivo no selecciona nada y se salta sin avisar.
