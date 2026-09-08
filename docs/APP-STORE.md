# Lo que hay que responder en App Store Connect

Este archivo existe por una razón concreta: **el manifiesto de privacidad del
paquete y las respuestas del cuestionario de App Store Connect tienen que decir
lo mismo.** El manifiesto vive en el repo y se revisa solo; el cuestionario se
contesta a mano en una web, se olvida, y ahí es donde se separan.

Al día del **8 de septiembre de 2026**.

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

## Antes de la primera subida

- **El bundle id.** Hoy `church.tamio.native`. Si la app se sube a la ficha de
  `com.tesoreria.app` para reemplazar a la de Tauri, tiene que decir eso — una
  app publicada no cambia de id nunca. Ver §0.-2 del traspaso.
- **El número de compilación.** `CURRENT_PROJECT_VERSION` es `1`. Si se hereda
  aquella ficha, hay que ponerlo por encima del más alto ya subido allí.
- **Las capturas y el texto de la ficha**, que no están en este repo.
