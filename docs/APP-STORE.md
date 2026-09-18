# Lo que hay que responder en App Store Connect

Este archivo existe por una razón concreta: **el manifiesto de privacidad del
paquete y las respuestas del cuestionario de App Store Connect tienen que decir
lo mismo.** El manifiesto vive en el repo y se revisa solo; el cuestionario se
contesta a mano en una web, se olvida, y ahí es donde se separan.

Al día del **17 de septiembre de 2026**. Lo de privacidad y venta sigue siendo
del 8-sep y no ha cambiado; lo del bundle id, la firma y la ficha es de hoy.

## Privacidad · qué contestar

Los nueve tipos que declara `Tamio/PrivacyInfo.xcprivacy`. Todos con **"se usa
para funcionalidad de la app"**, todos **vinculados a la identidad** y
**ninguno para seguimiento**:

| Tipo | De dónde sale |
|---|---|
| Nombre | `members.nombre`, y los del tesorero, pastor y secretaria |
| Correo | la cuenta que entra, y `members.email` |
| Teléfono | `members.telefono` y los de tesorero y pastor |
| Domicilio | `members.direccion` y la dirección del membrete |
| Otra información financiera | `transactions`: ingresos, gastos, diezmos, ofrendas |
| Fotos o vídeos | los comprobantes del banco y el logo, en Supabase Storage |
| Otro contenido del usuario | actas, cartas, notas del padrón y de seguimiento |
| **Información sensible** | **ver abajo** |
| ID de usuario | el `auth.uid()` con el que se firma cada apunte del registro |

**La información sensible es la que hay que saber defender.** La categoría de
Apple abarca expresamente las creencias religiosas, y el padrón guarda bautismo
en agua y en espíritu, estado de membresía y ministerios — de personas que
además **no son quien usa la app**. Se declara. Omitirlo es lo que se sanciona;
declararlo de más no cuesta nada.

**Lo que NO se recoge**, comprobado en el código: contactos, ubicación, salud,
identificadores de publicidad, datos de diagnóstico. No se importa `Contacts`,
`CoreLocation`, `HealthKit`, `AdSupport` ni `AppTrackingTransparency`, y
ninguna de las ocho dependencias es de analítica o publicidad.

## Cumplimiento de exportación

`ITSAppUsesNonExemptEncryption` va en `false` dentro de `Config/Info.plist`, así
que no lo pregunta en cada subida. Lo que se cifra son los respaldos con AES-GCM
de CryptoKit, más la protección de datos de iOS y HTTPS: cifrado del sistema con
algoritmos estándar. No hay criptografía propia en el repo.

## El modelo de venta

**No se usa compra integrada, y hay dos directrices que lo permiten.** Se
verificaron contra el texto vigente el 8 de septiembre de 2026:

- **3.1.3(c) Enterprise Services** — se vende a organizaciones (por iglesia), no
  a consumidores.
- **3.1.3(f) Free Stand-alone Apps** — app gratis compañera de una herramienta
  de pago web, *"provided there is no purchasing inside the app, or calls to
  action for purchase outside of the app"*.

**Lo que eso obliga:** la app no dice en ninguna parte dónde se paga. El pie del
plan dice solo que aquí no se cambia. **No añadir un enlace de compra ni un
"contacta a soporte para tu plan"** sin volver a leer la directriz.

**El punto flojo:** 3.1.3(c) añade que *"Consumer, single user, or family sales
must use in-app purchase"*. La ficha y la web deben dejar claro que Tamio se
vende **a iglesias**, no a personas.

**3.1.3(b) Multiplatform Services NO sirve** como alternativa: honrar lo
comprado en la web exige que esos mismos artículos estén también como compra
integrada.

## La cuenta de revisión

El revisor **va a probar el borrado de cuenta** —es el requisito 5.1.1(v)— y la
app no tiene registro, así que hay que darle credenciales.

**Esa cuenta debe vivir en una iglesia con datos de ejemplo Y con un segundo
perfil administrador.** Si es el único perfil de su iglesia, al probar el
borrado **destruye la demo entera** (la Edge Function borra la iglesia en
cascada cuando se queda sin perfiles) y hay que rehacerla para la siguiente
ronda.

### «Iglesia de prueba» NO sirve · comprobado el 18-sep-2026

Es la candidata obvia —5 perfiles, 30 miembros, 114 movimientos, ya hecha— y
hay que descartarla. Lo que se midió:

- De sus **30 miembros, 14 tienen teléfono y los 14 son distintos**, de 8 a 10
  dígitos; solo 2 son del tipo `1234` o `5555`. Nueve tienen forma de número
  real.
- Uno de sus cinco perfiles es un **tesorero con correo de una congregación**,
  con sesión iniciada el 8 de septiembre.
- Y ese padrón guarda bautismo, estado de membresía y ministerios, que es
  exactamente lo que este archivo declara arriba como **información sensible**
  en el cuestionario de privacidad.

No se puede demostrar desde aquí que esas personas sean reales, pero la forma
de los datos no es la de una semilla. **Darle esas credenciales a Apple sería
mandarle datos personales sensibles de gente que no publica la app.** Cuesta
media hora hacer una iglesia inventada; no hacerla no se puede justificar
después.

### Cómo se monta la iglesia de demostración

La semilla está escrita y comprobada contra el esquema:
**`docs/demo-revision.sql`**. Catorce miembros inventados, 34 movimientos de
tres meses, tres cortes, dos actas, tres cultos con asistencia y ocho
actividades. Los teléfonos van en el bloque 555 y los correos en
`example.com`, que la RFC 2606 reserva para que no puedan ser de nadie. La
iglesia se llama **«Iglesia Nueva Vida», en Monterrey**, que es el mismo nombre
que sale en las capturas de la ficha: si el revisor las compara con lo que ve
al entrar, tiene que reconocerlo.

Los tres pasos, en este orden —y **los dos primeros los hace Iván**, porque uno
pide el panel y el otro pide la app:

1. **Dar de alta la cuenta del revisor.** Panel de Supabase →
   *Authentication → Users → Add user*, con **Auto Confirm User** puesto (sin
   eso no puede entrar). El correo, uno que Iván reciba: `…+revision@gmail.com`.
   El disparador `al_crear_usuario` **le crea una iglesia vacía sola**; esa es
   la de la demo. Apuntar su `church_id`:

       select p.id, p.rol, p.church_id from perfiles p
       join auth.users u on u.id = p.id where u.email = '…+revision@gmail.com';

   Y ponerle el rol y el nombre, que nacen en blanco:

       update perfiles set rol = 'administrador', nombre = 'Revisión App Store'
       where id = '<el id de arriba>';

2. **Correr `docs/demo-revision.sql`** con ese `church_id` pegado en su línea.
   Se para sola si el id apunta a una de las tres iglesias reales o a una que
   ya tenga datos de otro.

3. **El SEGUNDO administrador, desde la app.** Entrar con la cuenta del revisor
   e invitar a un `…+revision2@gmail.com` como **administrador**. Lo hace la
   función `invitar-usuario`, que suma a la persona a la iglesia de quien
   invita. **No hace falta que nadie acepte la invitación**: el perfil se crea
   en el momento, y lo que protege a la demo es que la fila exista, no que
   alguien entre con ella.

**Y la comprobación que decide si la demo aguanta la revisión**, al final del
propio SQL:

    select count(*) from perfiles where church_id = '<el id>';   -- ≥ 2

Con **uno solo**, el revisor prueba el borrado —que es justo lo que va a
hacer— y `borrar-cuenta` se lleva la iglesia en cascada. Con dos, borra su
perfil, la iglesia sobrevive, y la demo sigue en pie para la ronda siguiente.
Ese número es el que hay que mirar antes de mandar nada.

## El bundle id, y la ficha · CERRADO el 17-sep-2026

**`church.tamio.native`, ficha NUEVA.** Ya no es provisional y esa línea de
`project.yml` no se toca. El razonamiento entero está ahí, en su comentario; en
corto: la publicada es gratis, sin cuenta y local, y mandarle esta encima como
actualización rompe la app a quien la tenga, sin nada que migrar.

**El nombre de la ficha: «Tamio Iglesia».** Decidido el 17-sep. «Tamio» a
secas lo ocupa la app de Tauri, que sigue publicada
(`apps.apple.com/us/app/tamio/id6794741319`), y el nombre es único en toda la
tienda. Se descartó «Tamio Pro»: la **4.3** va contra dos fichas del mismo
producto y su remedio expreso es *una sola app con compra integrada*, que es lo
que este proyecto evita apoyándose en 3.1.3(c) y (f) — un nombre de gama regala
ese encuadre al revisor.

**Y de ahí sale una nota obligatoria para el revisor:** decir por qué hay dos
apps. Una es de un solo aparato, sin cuenta y local; la otra es multiusuario,
para que el tesorero, el pastor y la secretaria trabajen sobre los mismos
libros con permisos por rol. Eso es lo que desactiva un 4.3; el nombre solo
puede estorbar.

**Lo que se registró en la cuenta de Apple al exportar** (17-sep):

- App ID `4N9XEU7F4P.church.tamio.native`.
- Perfil `iOS Team Store Provisioning Profile: church.tamio.native`, hasta el
  25 de julio de 2027.

**Y el error que sale si se sube antes de crear la ficha**, que cuesta un rato
entender porque suena a problema de firma y no lo es:

    Could not create a temporary .itmsp package for the app "Tamio.ipa".
    No suitable application records were found. Verify your bundle identifier
    "church.tamio.native" is correct.

El App ID del portal de desarrollador y la FICHA de App Store Connect son dos
cosas distintas. El primero sirve para firmar; a la segunda se sube el binario,
y hay que crearla a mano: Apps → `+` → Nueva app, con ese bundle id en el
desplegable.

**El nombre de la ficha es único en toda la tienda.** Si la app de Tauri ya
ocupa "Tamio", esta necesita otro o hay que renombrar aquella primera.

**La vieja no se borra.** Sigue publicada y funcionando; la mudanza se hace
cuando haya a quién mudar, con una última actualización suya que diga dónde
está esta. Borrarla deja tirado a quien la tenga.

## Antes de la primera subida

- ~~El bundle id.~~ **Cerrado el 17-sep**, arriba.
- **El número de compilación.** `CURRENT_PROJECT_VERSION` es `1`, y con ficha
  nueva `1.0.0 (1)` es correcto. Lo que sí hay que recordar: **cada subida a
  App Store Connect necesita un número MAYOR que el anterior**, aunque la
  anterior se rechazara o se borrara. El primero que se suba quema el `1`.
- **Las capturas y el texto de la ficha**, que no están en este repo.
