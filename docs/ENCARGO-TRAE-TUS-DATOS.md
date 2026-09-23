# «Trae tus datos» · encargo de diseño

Escrito el 23-sep-2026 para pedírselo al diseño. Es para **los tres aparatos**:
Mac, iPad e iPhone. Cada uno tiene su propia forma; no son copias el uno del
otro.

## Qué es

Cuando una iglesia empieza con Tamio, casi siempre trae su padrón de otro sitio:
un Excel, una hoja de Google o un listado exportado de otro sistema. Hoy Tamio
ya sabe importarlo, pero la función está escondida en un menú y quien acaba de
crear su iglesia no la encuentra. Empieza con la app vacía y tiene que dar de
alta a las personas una por una.

«Trae tus datos» es **un paso que se ofrece al empezar** para meter de golpe a
las personas de la iglesia, y opcionalmente sus aportes de años anteriores. Así
la app arranca con su gente dentro desde el primer día.

## Cuándo aparece

- **Justo después de la bienvenida**, que ya está diseñada para los tres
  aparatos.
- **Solo si el padrón de la iglesia está vacío.** No depende de que sea la
  primera vez que se abre la app: una secretaria que instala Tamio en su segundo
  aparato, con la iglesia ya montada, no debe verlo.
- **Solo a quien puede dar de alta personas**: el administrador y la secretaria.
  Al tesorero solo en el plan «solo Tesorería», donde no hay secretaría.
- **Siempre se puede saltar** («Lo haré después»), y la misma función tiene que
  poder encontrarse más tarde. Hace falta que el diseño diga **dónde vive
  después**: en Configuración, en Membresía o en Aportantes.

## El recorrido

### 1. La invitación
Una pantalla que ofrece traer los datos, con tres salidas:
- **Importar mi lista de personas**, el camino principal;
- **Descargar la plantilla**, para quien no tiene nada ordenado;
- **Lo haré después**.

Tiene que explicar en una frase qué tipo de archivo sirve. Hoy es **CSV**, y en
Excel se obtiene con Archivo › Guardar como › CSV. Casi nadie sabe qué es un
CSV, así que esa frase importa. Si más adelante se lee el Excel directamente, la
pantalla tiene que poder decirlo sin rediseñarse.

### 2. Elegir el archivo
- **Mac:** el selector de archivos del sistema.
- **iPhone y iPad:** Archivos, iCloud, o el archivo que llega desde otra app o
  desde el correo.

### 3. Relacionar columnas
Tamio ya reconoce solas muchas columnas por su nombre, en español y en inglés.
Las que no reconoce, se eligen a mano. Solo **Nombre** es obligatorio.

Los campos que Tamio sabe importar hoy, en este orden:

| Campo | Obligatorio | Nombres que reconoce solo (ejemplos) |
|---|---|---|
| Nombre | **Sí** | nombre, name, nombre completo, miembro |
| Identificador | | id, código |
| Identificación fiscal | | RFC, tax id |
| Estado | | estado, status |
| Tipo de aporte | | tipo |
| Teléfono | | teléfono, celular, móvil |
| Correo | | correo, email |
| Domicilio | | dirección, domicilio, calle |
| Nacimiento | | fecha de nacimiento, cumpleaños |
| Estado civil | | estado civil |
| Miembro desde | | fecha de ingreso, alta |
| Congrega desde | | fecha de congregación |
| Frecuencia | | frecuencia |

- Cada campo lleva un selector con las columnas del archivo y la opción
  «— No importar —».
- Los que se reconocieron solos ya vienen elegidos.

### 4. Qué va a pasar (antes de tocar nada)
Nada se escribe hasta confirmar. La pantalla enseña:
- **N personas nuevas**;
- **N que ya existen y se actualizarán**. Se reconocen por id, identificación
  fiscal o nombre. Reimportar el mismo archivo no duplica a nadie;
- **N filas con problemas, que se omitirán**, una por una, con su número de
  línea y el motivo, para poder arreglar el archivo. Los motivos que existen hoy
  son «Sin nombre» y «Repetido en el archivo».

El botón dice cuántas se van a importar: **«Importar 48»**.

### 5. Hecho
- Confirmación con el número de personas que entraron.
- Qué hacer ahora: ir a Membresía, o pasar al paso opcional de aportes.

### 6. Opcional: los aportes de años anteriores
Para que los informes y las constancias anuales salgan completos desde el
primer día. Es el mismo recorrido de columnas y resumen, con estos campos:

| Campo | Obligatorio |
|---|---|
| Fecha | **Sí** |
| Importe | **Sí** |
| Aportante (nombre) | |
| Id del aportante | |
| Concepto | |

- **Va después de las personas, nunca antes.** Cada aporte se apunta a una
  persona que ya exista; si no, esa fila sale como problema («No hay ningún
  aportante con ese nombre»).
- Los otros motivos de fila omitida son «Fecha no válida» e «Importe no
  válido».
- Los aportes que ya están registrados se reconocen y salen como
  **duplicados**, no se meten dos veces.
- Es **dinero**: la pantalla de resumen tiene que dejar muy claro qué se va a
  sumar antes de confirmar.

## La plantilla
Un archivo descargable con las columnas de la tabla de arriba y una o dos filas
de ejemplo. El diseño decide:
- dónde se ofrece (en la invitación y junto al selector de archivo);
- qué nombre tiene el archivo;
- si va en español o en inglés según el idioma de la app. Los encabezados se
  reconocen en los dos.

## Por aparato

- **Mac:** hoy la importación ya es **una sola hoja** que junta las columnas y el
  resumen: al cambiar una columna se ve al momento cuántas filas se caen. Esa
  hoja existe y se puede reutilizar tal cual. Lo que falta es la invitación, el
  «Hecho» y el paso de aportes.
- **iPad:** con sitio para columnas a la izquierda y resumen a la derecha, como
  en el Mac, o en pasos, como en el iPhone. Lo decide el diseño.
- **iPhone:** hoy son dos pantallas seguidas, primero las columnas y luego el
  resumen. Hace falta que se pueda hacer con una mano y que las filas con
  problema se lean bien en pantalla pequeña.

## Estados que hay que dibujar

- Archivo que no se puede leer: vacío, sin filas o con otro formato.
- Archivo sin ninguna fila válida: el botón de importar no puede quedar activo
  prometiendo algo.
- Archivo grande, con cientos de personas: cómo se ve la lista de problemas
  larga.
- Importando: puede tardar unos segundos.
- Sin conexión: la importación se guarda en el aparato y sube después. Hay que
  decirlo sin asustar.
- Idiomas: español e inglés, en los tres aparatos.
- Modo claro y modo oscuro.

## Lo que NO entra (y por qué)

- **Leer el Excel (.xlsx) directamente**: hoy solo se lee CSV. Se puede
  construir, pero es trabajo aparte. El diseño debe servir para los dos casos,
  y la frase del tipo de archivo es la única que cambia.
- **Otras columnas del padrón** —ministerios, cargos, bautismo, familia—: la
  base las tiene, pero el importador todavía no. Si el diseño quiere ofrecerlas,
  que lo diga y se construye; no se deben dibujar como si ya existieran.
- **Movimientos de tesorería** (gastos, depósitos): no hay importador y no se
  pide.

## Lo que devuelve el diseño

Para cada aparato:
1. La invitación.
2. Columnas y resumen, juntos o en pasos.
3. Las filas con problema.
4. El «Hecho».
5. El paso de aportes.
6. Dónde vive la función después de saltarla.

Con los textos exactos en español y en inglés, y los estados de la lista de
arriba.
