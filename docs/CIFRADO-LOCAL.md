# Cifrado de la base local — análisis

**Estado: DECISIÓN PENDIENTE.** Escrito el 2026-09-04 a petición de Iván, que
pidió analizarlo sin construir nada todavía. No se ha tocado ninguna
dependencia ni ningún archivo de la app.

La pregunta era: *«SQLCipher se necesita para guardar local, en caso que no haya
red»*. Este documento contesta qué haría falta, qué protege de verdad, y qué se
rompe por el camino.

---

## 1. Qué hay hoy

La app guarda **toda la contabilidad de la iglesia** en
`Application Support/tamio.sqlite`, sin cifrado propio: movimientos, aportantes,
cortes, depósitos, categorías y la configuración. Es la fuente de verdad de la
app —se lee y escribe siempre de ahí, haya red o no— y por eso el archivo tiene
todo lo que tendría el servidor.

Junto a ella:

| Archivo | Dónde | Cifrado propio |
|---|---|---|
| `tamio.sqlite` | Application Support | no |
| `recibos/` (fotos del banco) | Application Support | no |
| `firmas/` (PNG del tesorero y del pastor) | Application Support | no |
| `tamio-AAAA-MM-DD.zip` (respaldo) | temporal → donde el usuario lo mande | **no** |
| CSV de movimientos y aportantes | temporal → donde el usuario los mande | **no** |

**Lo que sí hay: Data Protection de iOS.** El sistema cifra los archivos de la
app con una clave ligada al código del aparato. Por omisión la clase es
*Complete Until First User Authentication*: un iPhone apagado, o encendido pero
que nadie ha desbloqueado desde el arranque, no suelta nada. A partir del primer
desbloqueo la clave está en memoria y el archivo es legible para el sistema.

> **Sin verificar.** El simulador no implementa Data Protection, así que la
> clase real de `tamio.sqlite` **no se ha comprobado en un aparato**. Se mide en
> el iPad con
> `FileManager.default.attributesOfItem(atPath:)[.protectionKey]`.
> Conviene hacerlo antes de decidir nada: si por lo que sea saliera `None`, el
> punto de partida es peor de lo que dice este documento.

---

## 2. De qué protege cada cosa

| Amenaza | Data Protection hoy | SQLCipher |
|---|---|---|
| Teléfono apagado o robado sin desbloquear | **protege** | protege |
| Teléfono desbloqueado en manos ajenas, con la app abierta | no protege | **tampoco**: la base está abierta |
| Copia del archivo desde un aparato con jailbreak, ya desbloqueado | no protege | protege |
| El `.zip` de respaldo mandado por correo o WhatsApp | **no protege** | protege (el archivo va cifrado) |
| Los CSV exportados | no protege | **tampoco**: se generan en claro por diseño, son para Excel |
| Alguien que entra con otra cuenta al mismo teléfono | no aplica: al cerrar sesión se borra la base local | igual |

Dos conclusiones que conviene no perder:

1. **En el aparato, SQLCipher añade menos de lo que parece.** El caso que la
   gente imagina —"me roban el teléfono"— ya lo cubre Data Protection. Lo que
   añade SQLCipher es el aparato comprometido y desbloqueado.
2. **Fuera del aparato añade mucho, pero por accidente.** El respaldo es el
   único archivo que sale, y hoy sale en claro. Eso sí es un agujero real, y se
   puede tapar sin SQLCipher (ver opción B).

---

## 3. El coste real: GRDB con SPM no lleva SQLCipher

Este es el dato que decide.

- El proyecto usa **SPM**: GRDB 6.29.3 y supabase-swift 2.55.1.
- El `Package.swift` de GRDB 6.29.3 declara `CSQLite` como `systemLibrary`: se
  enlaza **el SQLite del sistema**, que no tiene codec de cifrado. No hay ningún
  producto de SQLCipher.
- El README de GRDB solo documenta SQLCipher **por CocoaPods**:
  `pod 'GRDB.swift/SQLCipher'` + `pod 'SQLCipher'`, y avisa de que ese debe ser
  el ÚNICO pod de GRDB del proyecto o hay errores de enlazado por el choque
  entre SQLCipher y el SQLite del sistema.
- En el GRDB actual (rama principal, tools 6.1) las líneas de SQLCipher **siguen
  comentadas** en su `Package.swift`, con un "descomenta estas líneas" y una
  dependencia hacia `github.com/sqlcipher/SQLCipher.swift`.

Para una dependencia remota no se pueden descomentar líneas. Así que la vía
SQLCipher obliga a una de estas:

- **Fork o vendorizado de GRDB** con esas líneas activas. Deja de ser una
  versión que se sube con un número y pasa a ser código de otro que mantenemos
  nosotros: cada actualización de GRDB hay que rehacerla a mano.
- **Migrar GRDB a CocoaPods** conviviendo con Supabase en SPM. Es la vía
  soportada, pero el `.pbxproj` de este proyecto está **editado a mano** —ver
  `proyecto-xcode-no-regenerar`— y meter un workspace de Pods encima es
  exactamente donde se rompen estas cosas.

---

## 4. Lo que se rompe si ciframos: el respaldo y la clave

Aunque el coste de instalación se aceptara, quedan dos problemas de diseño que
son más serios:

### 4.1 Un respaldo cifrado no se abre en otro aparato

El respaldo existe para poder **restaurar en otro teléfono**. Si la base va
cifrada con una clave que vive solo en el llavero del aparato original, el
`.zip` es un archivo que nadie puede abrir —ni el propio dueño desde su iPad
nuevo—.

Salidas posibles, todas con su precio:

- Que el respaldo se **re-cifre con una contraseña que el usuario escribe** al
  crearlo. Funciona, pero añade una contraseña que hay que recordar durante
  años, y quien la pierda pierde el respaldo.
- Que el respaldo salga **descifrado**. Entonces SQLCipher no está protegiendo
  el único archivo que sale del aparato, que era su mejor argumento.

### 4.2 Si se pierde la clave, se pierde la contabilidad

La clave iría al llavero. Con `kSecAttrAccessibleAfterFirstUnlock`, para que
`MotorSincronizacion` pueda trabajar con la app en segundo plano; con
`WhenUnlocked` la sincronización de fondo dejaría de funcionar.

El llavero sobrevive a reinstalar la app, pero **no** a borrar el aparato ni a
restaurarlo sin llavero. Sin una copia de la clave, esos casos dejan la base
ilegible. Para una app de contabilidad de una iglesia eso es peor que el riesgo
que se quería evitar, y va en contra de la línea que ya se siguió en el candado
biométrico: *nadie se queda fuera de sus propios libros*
(`BloqueoBiometrico`, que cae al código del aparato justo por esto).

---

## 5. Las tres opciones, con su precio

### A — Endurecer lo que hay y cifrar el respaldo *(la más barata)*

- Poner la base en `NSFileProtectionCompleteUnlessOpen`: la clase más fuerte
  compatible con una base siempre abierta y con sincronización en segundo plano.
  Se aplica con `FileManager.setAttributes` sobre el archivo, o con
  `Configuration` de GRDB.
- Aplicar la misma clase a `recibos/` y `firmas/`.
- Pedir una contraseña al crear el respaldo y cifrar el `.zip` con ella.
- **Sin tocar dependencias.** Cierra el agujero que de verdad sale del aparato.
- No protege del aparato comprometido y desbloqueado.

### B — SQLCipher con fork de GRDB

- Vendorizar GRDB con las líneas de SQLCipher activas + `SQLCipher.swift`.
- Clave en el llavero, `AfterFirstUnlock`.
- Migrar la base existente con `sqlcipher_export` (no se puede abrir una base en
  claro con una clave: hay que exportarla a una nueva).
- Manejar el fallo de apertura sin borrar nada: hoy `BaseLocal` cae a una base
  **en memoria** si no puede abrir el archivo, y con cifrado ese camino se
  volvería habitual y silencioso.
- Hay que resolver 4.1 y 4.2 antes, no después.

### C — B más respaldo con contraseña propia

Lo más cerrado y lo más caro. Añade un flujo de restauración que pide
contraseña, que hoy ni siquiera existe (restaurar está sin construir).

---

## 6. Recomendación

**A ahora, B cuando exista restaurar.**

El orden importa: cifrar la base antes de tener restauración deja al usuario con
un respaldo que no sirve y sin forma de comprobarlo. Y la mitad del valor de
SQLCipher —el archivo que sale del aparato— se consigue con A sin forkear nada.

Antes de decidir, dos medidas concretas que faltan:

1. La clase de protección real de `tamio.sqlite` en el iPad (§1).
2. Si el respaldo se guarda en iCloud Drive, comprobar qué protección le queda
   ahí, que ya no depende de nosotros.

---

## 7. Lo que este documento NO cubre

- El servidor. Supabase ya aísla cada iglesia por RLS y esto no lo cambia.
- Los CSV exportados: van en claro a propósito, son para abrirlos en Excel.
- El bucket de comprobantes: es de Supabase y tiene sus propias políticas.
