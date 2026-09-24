# El texto de la ficha · App Store Connect

**Para copiar y pegar.** `docs/APP-STORE.md` dice qué CONTESTAR en el
cuestionario de privacidad, de exportación y de venta; esto es lo otro: lo que
se ESCRIBE en la ficha. Se separan porque se tocan en pantallas distintas de
App Store Connect y en momentos distintos —el cuestionario una vez, el texto en
cada versión— y mezclarlos es como se pierde un párrafo al actualizar.

Redactado el **18 de septiembre de 2026**, para `church.tamio.native` 1.0.0 (1).

> **Las dos cosas que caducaban, resueltas el 19-sep-2026.** Se dejan escritas
> porque saber que YA están comprobadas ahorra volver a comprobarlas.
>
> - **Las dos URL están vivas.** Daban 404 cuando se redactó esto. Verificadas
>   con `curl` el 19-sep: `privacidad.html` y `soporte.html` responden 200, y la
>   política que sirven es la NUEVA —la que cubre las dos apps y declara la
>   información religiosa como sensible—, no la de julio.
> - **El correo oficial es `ivanngarcia82@gmail.com`.** Era el que ya usaban el
>   sitio y la política vivas, así que se eligió ese y no `ig07644@gmail.com`.
>   Es el que va en App Store Connect.

---

## 1 · Información de la app · se escribe UNA vez

| Campo | Qué poner |
|---|---|
| **Nombre** | `Tamio Iglesia` |
| **Bundle ID** | `church.tamio.native` |
| **SKU** | `TAMIO-IOS-001` |
| **Idioma principal** | Español (México) |
| **Categoría principal** | **Negocios** |
| **Categoría secundaria** | Finanzas |
| **Derechos de autor** | `2026 Iván García` |
| **Clasificación por edad** | 4+ |

### Por qué Negocios y no Finanzas de principal

Parece al revés —la mitad de la app es un libro de ingresos y gastos— y se
eligió a conciencia:

- **Sostiene el encuadre del que depende no llevar compra integrada.** Toda la
  defensa de `docs/APP-STORE.md` se apoya en **3.1.3(c) Enterprise Services**:
  se vende *a organizaciones*, no a consumidores. Una ficha en Finanzas se lee
  como app personal; en Negocios dice lo mismo que la directriz que se invoca.
  No es decorativo: es el único punto flojo que ese apartado se apunta a sí
  mismo.
- **Finanzas atrae escrutinio que aquí no aplica y hay que contestar igual.**
  Esa categoría convive con banca y con inversión, y las preguntas de la
  revisión van por ahí. Esto no mueve dinero: lo anota.

Se deja Finanzas de **secundaria** porque la búsqueda de "tesorería" y
"contabilidad" sí vive ahí, y la secundaria también indexa.

### La clasificación por edad: 4+, y las dos casillas que confunden

Todo lo demás en «Ninguno». Las dos que hacen dudar:

- **«Contenido generado por usuarios sin restricciones» → NO.** Los datos son
  de la propia congregación, visibles solo para los perfiles de esa iglesia, y
  no hay canal público ni entre iglesias. Contestar que sí obliga a moderación,
  bloqueo y denuncia (**1.2**) para algo que no existe.
- **«Temas religiosos» no es una casilla.** No hay ninguna. El cuestionario
  pregunta por violencia, sexo, drogas, juego y sustos; nada de eso aplica.

---

## 2 · Los enlaces

| Campo | Valor |
|---|---|
| **Política de privacidad** | `https://tamio.church/privacidad.html` |
| **URL de soporte** | `https://tamio.church/soporte.html` |
| **URL de marketing** | `https://tamio.church` |

**Las tres responden 200**, verificado el 19-sep-2026. Se pegan tal cual, con
el `.html` incluido: `/soporte` a secas sigue dando 404.

**Y la política que sirven es la buena.** Esto importaba de verdad: la que había
el 18-sep era la de julio, que decía *«ni inicio de sesión, no enviamos tu
información a ningún servidor»* — enviar con ella era entregarle al revisor la
contradicción por escrito, porque esta app exige cuenta y guarda en Supabase. La
viva de hoy pone las dos apps una al lado de la otra («¿Hace falta cuenta?» ·
*No, no hay inicio de sesión* · **Sí, es obligatoria**) y declara la información
religiosa como sensible.

Los borradores `docs/privacidad-propuesta.html` y `docs/soporte-propuesta.html`
ya están publicados; se quedan como referencia de lo que se envió.

---

## 3 · Español (México) · el texto que se ve

### Subtítulo · 30 caracteres

    Tesorería y padrón de iglesia

(29 con el espacio final que no lleva. Contado.)

### Texto promocional · 170 caracteres · se puede cambiar sin nueva versión

    El tesorero captura, el pastor aprueba y la secretaria lleva el padrón.
    Los mismos libros en el iPhone y en el iPad, y sin internet también.

### Palabras clave · 100 caracteres, separadas por coma y SIN espacio

    diezmo,ofrenda,congregacion,tesoreria,padron,membresia,actas,contabilidad,iglesias,pastor

Tres reglas que se aplicaron y que no son obvias:

- **No se repiten el nombre ni el subtítulo.** «Tamio», «iglesia» y «padrón» ya
  están indexados por el título y el subtítulo; gastar caracteres en ellos es
  perderlos. Va «iglesias» en plural porque el singular ya lo da el subtítulo.
- **Sin acentos en las claves.** La búsqueda de App Store los normaliza, y
  escribirlos gasta bytes en UTF-8 sin ganar nada.
- **Nada de «gratis», «mejor» ni nombres de la competencia**, que es lo que la
  **2.3.7** rechaza.

### Descripción

    Tamio lleva la tesorería y el padrón de una congregación en el iPhone y en
    el iPad, con los mismos libros para todo el equipo.

    QUIÉN HACE QUÉ
    Tres perfiles con permisos propios sobre la misma información: el tesorero
    captura ingresos y gastos, el pastor revisa y aprueba, y la secretaria
    lleva el padrón, las actas y la agenda. Cada quien ve su parte, y nadie
    tiene que pasarle el teléfono a nadie.

    LA TESORERÍA
    • Ingresos y gastos con folio, categoría, método de pago y comprobante.
    • Diezmos y ofrendas ligados al aportante, con su histórico del año.
    • Cortes y depósitos: se arma el corte con el dinero sin depositar y el
      total nunca se desvía de la suma de sus movimientos.
    • Movimientos recurrentes, que se generan solos al entrar el mes.
    • Estado financiero, informe anual y reportes por categoría.
    • Bandeja «Por revisar»: nada queda aprobado porque sí.

    LA SECRETARÍA
    • Padrón con bautismo, estado de membresía, ministerios y notas.
    • Actas con firmas de quien preside, de quien las redacta y del testigo.
    • Cartas y traslados con folio y plantilla.
    • Registro de servicios y asistencia.
    • Agenda de actividades, por mes, por semana y en lista.

    CADA PESO LLEVA SU HISTORIA
    Todo movimiento guarda quién lo capturó, cuándo y qué se le cambió después.
    Cuando alguien pregunte por una cifra de hace ocho meses, la respuesta está
    en la propia ficha y no en la memoria de nadie.

    FUNCIONA SIN SEÑAL
    Se captura en el momento, esté o no el internet del templo. Lo capturado se
    guarda en el aparato y sube solo cuando hay red; Ajustes dice siempre
    cuánto queda por subir, y avisa si algo no pudo subir.

    EN EL IPHONE Y EN EL IPAD
    No es la misma pantalla estirada: en el iPad el padrón y la ficha se ven a
    la vez, y los informes se leen como se leen en papel.

    EN ESPAÑOL Y EN INGLÉS
    Se cambia dentro de la app, sin volver a entrar.

    LO QUE TAMIO NO HACE
    No mueve dinero, no cobra y no se conecta al banco: anota lo que ya pasó.
    Y no vende ni comparte los datos de la congregación con nadie.

    Tamio se contrata por iglesia. La cuenta se crea desde tamio.church.

**Lo último es lo que hay que dejar tal cual.** Dice que se contrata por
iglesia —que es lo que sostiene la 3.1.3(c)— y **no dice dónde se paga ni
invita a pagar**, que es lo que la **3.1.3(f)** prohíbe expresamente. Es una
frase sola porque cualquier añadido —«contacta a soporte para tu plan», un
precio, un enlace a la página de planes— la convierte en la llamada a la compra
que la directriz nombra. Ya está escrito en `docs/APP-STORE.md`; se repite aquí
porque el sitio donde se rompe es este texto.

### Novedades de esta versión

    Primera versión.

---

## 4 · Inglés (EE. UU.)

La app es bilingüe de verdad, así que la ficha también. **No es un requisito**
—con es-MX basta para enviar— pero sin esta localización la ficha se enseña en
español a quien tiene el iPhone en inglés, y eso incluye a buena parte de las
congregaciones hispanas de Estados Unidos, que son el mercado que hay al lado.

### Subtitle · 30 caracteres

    Church books and membership

### Promotional text

    The treasurer records, the pastor approves, the secretary keeps the roll.
    The same books on iPhone and iPad, offline too.

### Keywords

    tithe,offering,congregation,treasury,bookkeeping,membership,minutes,roll,parish,pastor

### Description

    Tamio keeps a congregation's books and membership roll on iPhone and iPad,
    with the same records for the whole team.

    WHO DOES WHAT
    Three roles with their own permissions over the same information: the
    treasurer records income and expenses, the pastor reviews and approves, and
    the secretary keeps the roll, the minutes and the calendar.

    THE BOOKS
    • Income and expenses with folio, category, payment method and receipt.
    • Tithes and offerings linked to the contributor, with the year's history.
    • Deposits: build a deposit from undeposited money, and the total can never
      drift from the sum of its entries.
    • Recurring entries that post themselves when the month turns.
    • Financial statement, annual report and reports by category.
    • A "To review" tray, so nothing is approved by default.

    THE SECRETARY'S SIDE
    • Roll with baptism, membership status, ministries and notes.
    • Minutes signed by the chair, the recording secretary and the witness.
    • Letters and transfers with folio and template.
    • Service log and attendance.
    • Activity calendar by month, by week and as a list.

    EVERY ENTRY KEEPS ITS HISTORY
    Every entry records who captured it, when, and what changed afterwards.

    WORKS WITHOUT A SIGNAL
    Record it on the spot, whether or not the building has internet. Settings
    always says how much is left to upload, and speaks up if something failed.

    ON IPHONE AND IPAD
    Not the same screen stretched: on iPad the roll and the record show at once.

    WHAT TAMIO DOES NOT DO
    It does not move money, charge anyone, or connect to a bank: it records what
    already happened. And it does not sell or share the congregation's data.

    Tamio is licensed per church. Accounts are created at tamio.church.

### What's New

    First release.

---

## 5 · La nota para el revisor · lo que más pesa de todo esto

Va en **«Notas para la revisión de la app»**. Tiene un trabajo concreto:
**desactivar un 4.3 antes de que se abra**, porque hay dos apps «Tamio» del
mismo autor en la tienda y el revisor lo va a ver. Se escribe en inglés porque
la revisión es en inglés.

    ACCOUNT FOR REVIEW
    Email:    ivanngarcia82+prueba@gmail.com
    Password: <PONER LA QUE SE ELIGIÓ AL CREAR LA CUENTA>

    The app has no sign-up: churches are onboarded by us, so the account above
    is the only way in. It belongs to a sample church with sample data and a
    SECOND administrator profile, so that testing account deletion does not
    destroy the demo.

    ACCOUNT DELETION (5.1.1(v))
    In-app and immediate, on both devices, in the ACCOUNT section next to
    "Sign out" -- not in the Danger zone:
      iPhone -> Settings tab -> Account -> "Delete my account"
      iPad   -> Settings (sidebar) -> Account -> "Delete my account"
    Deleting the last profile of a church deletes the church and its data in
    cascade; deleting one of several leaves the church untouched. The review
    account is not the only profile of its church, so it takes the second path.

    WHY THERE ARE TWO "TAMIO" APPS (4.3)
    "Tamio" (id6794741319) is a single-device app: no account, no server, the
    data lives on that one iPhone. It stays published for the people using it.
    "Tamio Iglesia" is a different product: multi-user, with a treasurer, a
    pastor and a secretary working on the same books under separate roles and
    permissions, synchronised across their devices. They share a name because
    they come from the same project, not because one is a tier of the other.
    They do not share a bundle id, an account system, or any data.

    NO IN-APP PURCHASE (3.1.3(c) and 3.1.3(f))
    Tamio is licensed to churches as organisations, not to individual
    consumers, and the app is free and contains no purchase, no price, and no
    call to action to purchase anywhere outside it.

    SENSITIVE DATA
    The membership roll records baptism, membership status and ministries, so
    religious affiliation is declared as sensitive data in the privacy
    questionnaire. It is entered by the church's own secretary about its own
    members, is visible only to that church's profiles, and is never used for
    tracking or shared with third parties.

    LANGUAGE
    The app ships in Spanish and English and opens in the device language.
    To switch: Settings -> Language.

> **Corregido el 18-sep.** Esta nota decía *Settings → Danger zone → Delete
> account*, y ahí NO está. El código lo dice con todas las letras en los dos
> sitios —`IPhoneAjustesView:334` y `ConfiguracionView:501`—: *«Borrar la
> cuenta va AQUÍ y no en la Zona de riesgo […] quien la busca la busca en
> Cuenta, al lado de cerrar sesión»*. En la Zona de riesgo lo que hay es
> «Borrar datos de este iPad», que es otra cosa: se lleva la copia local y deja
> la cuenta viva.
>
> Mandar al revisor al sitio equivocado en la instrucción de la 5.1.1(v) es
> pedir un rechazo: no la encuentra donde se le dice, prueba lo de al lado, ve
> que la cuenta sigue viva, y reporta que la app no deja borrarla.

### La cuenta de revisión · HECHA el 19-sep-2026

Ya existe, con su iglesia sembrada y comprobada contra las cifras que
`docs/demo-revision.sql` lleva escritas al lado:

| | |
|---|---|
| Correo | `ivanngarcia82+prueba@gmail.com` (confirmada) |
| Perfil | «Revisión App Store», administrador |
| Iglesia | «New Life Church», Houston, USD (hasta el 24-sep, «Iglesia Nueva Vida», Monterrey, MXN), `809d3b50-810f-433b-a0d2-f3413ca49637` |
| Contenido | 14 miembros · 34 movimientos · 3 cortes · 2 actas · 3 cultos · 8 actividades |
| Dinero | ingresos $48,820.00 · gastos $31,520.50 · balance $17,299.50 |
| **Perfiles** | **2** — el segundo es `ivanngarcia82+revision2@gmail.com`, administrador |

**Lo único que falta escribir aquí es la contraseña**, arriba. No está en el
repo a propósito.

**Por qué el correo NO es `revision@tamio.church`**, que es lo que decía esta
nota hasta hoy: esa dirección no existe. Supabase no da buzones —solo guarda el
correo como identificador— y `tamio.church` no tiene servidor de correo, así
que nada dirigido ahí se entrega. Con *Auto Confirm User* el revisor entra sin
recibir nada, pero la app tiene «olvidé mi contraseña»
(`SesionSupabase.swift:149`), y si lo toca el mensaje se pierde. Un `+alias` de
Gmail llega a una bandeja de verdad sin configurar nada.

**Y los dos perfiles son el requisito que es fácil saltarse.** Con uno solo, el
revisor prueba el borrado —que es exactamente lo que va a hacer— y
`borrar-cuenta` se lleva la demo entera por delante en cascada, y hay que
rehacerla para la siguiente ronda. El porqué está en `docs/APP-STORE.md`.

---

## 6 · Las capturas

Se generan con `pruebas/capturas-tienda.sh`, que las deja en
`docs/capturas-tienda/`. Lo que hay que saber antes de subirlas:

- **Obligatorias: iPhone 6.9" y iPad 13".** Con esas dos, App Store Connect
  escala para todo lo demás. El resto de tamaños ya no se piden.
- **Máximo diez por tamaño, y las TRES PRIMERAS son las que se ven** en el
  resultado de búsqueda, sin entrar a la ficha. El orden del recorrido está
  elegido para eso y está explicado en `pruebas/CapturasTiendaUITests.swift`.
- **En español**, porque la localización principal es es-MX. Una captura en
  inglés en la ficha en español es lo que la **2.3.3** rechaza. El recorrido
  arranca la app con `-prefs.idioma espanol`.
- **Sin la franja naranja del modo revisión.** Sale fija en lo alto de todas
  las pantallas y el guion la apaga en la copia. Es el fallo que no se ve
  hasta mirar el PNG: mirar el PNG.
- **Y en inglés, para la localización en-US**:
  `pruebas/capturas-tienda.sh telefono en` (e `ipad en`) las deja en
  `telefono-en/` e `ipad-en/`. En inglés la maqueta es **«New Life Church»,
  Houston, en dólares**, la misma iglesia que ve el revisor al entrar con su
  cuenta (desde el 24-sep). En español sigue siendo «Iglesia Nueva Vida»,
  Monterrey. Coincide el nombre de la iglesia, no las personas: la maqueta
  tiene su propio padrón.
- **No están en el repo**, a propósito: pesan 10 MB y el repo empaquetado pesa
  4,5. Se rehacen en tres minutos con el guion. Están en `.gitignore` con el
  motivo escrito.

### Lo que hay generado, en orden

Las tres primeras de cada juego son las que se ven en el resultado de búsqueda.

| # | iPhone 6.9" | iPad 13" |
|---|---|---|
| **1** | Inicio · saldo, ingresos, gastos y por revisar | Inicio, con la barra lateral entera |
| **2** | Movimientos, agrupados por día | Ingresos |
| **3** | Un movimiento con su nota, su comprobante y su rastro | Depósitos |
| 4 | Un corte por dentro: de qué dinero está hecho | Reportes |
| 5 | Estado financiero, con la dona por categoría | Por revisar |
| 6 | Por revisar: aprobar, devolver, vincular | Membresía |
| 7 | Membresía, con el porcentaje de asistencia | Actas |
| 8 | La ficha de un miembro, entera | Cartas y traslados |
| 9 | Agenda del mes | Agenda |
| 10 | Un acta con sus seis acuerdos | Registro |

**La del iPad nº 1 es la mejor del juego** y conviene que sea la primera: es la
única que enseña de un vistazo que hay tesorería y secretaría, quince
secciones, dos gráficas y dos listas. En el teléfono eso no cabe.

### Y una que se descartó, por si alguien la vuelve a intentar

La Agenda **en vista de lista** enseña los nombres de las actividades, que es
más que la rejilla del mes. Sale peor: seis de las siete del mes ya pasaron y
salen **tachadas y en gris**, y una ficha de tienda con una lista tachada se
lee como cosas canceladas. Queda la rejilla, que es más pobre y no miente.
