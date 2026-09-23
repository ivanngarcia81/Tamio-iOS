# Prompts para el agent team de Tamio

Abre Claude Code en la carpeta de Tamio-iOS, en la rama `mac-target`.
Pega UN prompt. Usa el primero antes que el segundo.

---

## Prompt 1 · Equipo de investigación (solo lectura, sin riesgo)

Crea un agent team para investigar, SIN editar código de la app.
Contexto: las pruebas de interfaz del iPhone dan 44 rojas "de verdad" en 26 clases
(docs/CONTEXTO.md §0.-22). Solo 7 están demostradas como no nuestras; la comparación
de las otras 37 contra `2555d99` quedó cortada.

Spawn 3 teammates, con estos nombres:
- "datos": clasifica qué rojas fallan porque buscan datos de maqueta
  (Ana Lucía Torres Beltrán, Tithe, Mission offering…) que la iglesia real no tiene.
- "navegacion": investiga las que mueren navegando ("no se llegó a Cartas",
  "Failed to tap Membership reports") y por qué testElActaTienePDF pasa y
  testLaCartaCompleta falla en la misma clase.
- "abogado": intenta refutar las conclusiones de los otros dos.

Reglas: leer código y docs, NO correr xcodebuild ni pruebas, NO editar archivos.
Que se lleven la contraria entre ellos. Al final, tú (lead) escribes un informe en
docs/ROJAS-SEPTIEMBRE.md con: clase → causa → ¿es de la app? → arreglo propuesto.
Espera a que terminen antes de escribir.

---

## Prompt 2 · Equipo de construcción del Mac (dueños por archivo)

Tareas sacadas del repo el 22-sep-2026 (`docs/AUDITORIA-HANDOFF.md`,
`docs/LO-QUE-EL-HANDOFF-NO-TRAE.md`, `CONTEXTO.md` §0.-21/§0.-22 y comentarios
del código de `TamioMac/`). Antes de pegarlo, lee "Decisiones de Iván" al final.

---

Crea un agent team para avanzar la app de Mac (target TamioMac, rama mac-target).
Lee primero CLAUDE.md. Tú eres el lead: coordinas, no programas. Solo tú tocas
el .pbxproj, Tamio/Data, Tamio/Models, SeccionMac.swift, ComandosTamio.swift,
InspectorTamio.swift, VentanaPrincipal.swift y docs/CONTEXTO.md.

Regla para todos: la auditoría del 21-sep se quedó vieja el mismo día. Antes de
escribir nada, cada teammate comprueba en el código si lo que le toca ya existe.
Si ya está, lo reporta y pasa a la siguiente tarea. Nada se da por ausente sin
mirar.

Spawn 3 teammates con estos nombres y DUEÑOS EXCLUSIVOS:

### "tesoreria-mac"
Archivos: TamioMac/PantallaReportes.swift, TablaMovimientos.swift,
TablaDepositos.swift, TablaAportantes.swift, TablaRegistro.swift,
PantallaRevisar.swift, HojaDeInforme.swift, PantallaInicio.swift.

1. Reportes: de los 6 rótulos que la auditoría dio por ausentes (BALANCE,
   PERIOD BALANCE, PERIOD DEPOSITS, ON-SCREEN SUMMARY, Share, "Not included in
   the PDF"), medir cuáles faltan de verdad hoy —"No se incluye en el PDF" ya
   está en la línea ~271— y añadir solo esos, en español e inglés con L.t().
2. Reportes: botón "Compartir" del PDF del estado financiero con
   NSSharingServicePicker, reutilizando el PDF que ya genera "Vista previa PDF".
   No duplicar el generador.
3. Movimientos: añadir "Duplicar ⌘D" al menú contextual. Abre la captura rápida
   con tipo, categoría, método e importe copiados; NO guarda nada solo. Las
   órdenes que mueven dinero (Aprobar, Marcar depositado, Devolver) NO se tocan.
4. Aportantes: "Importar aportantes… (CSV)" usando el importador compartido que
   ya usa iOS (buscar MapeoDeColumnas / ImportarIPadUITests). Si el importador
   vive en Tamio/Data y necesita cambios, pedírselos al lead.
5. Inicio: ancho mínimo 1360 pt. Proponer al lead —sin implementar todavía—
   cómo reorganizar las tiras de indicadores en dos filas por debajo de ~1000 pt.
6. Registro: comprobar que la tabla enseña lo que dice §0.-21 del CONTEXTO
   (el registro guarda copias, no referencias). La cabecera "WHAT WAS SAVED"
   del panel de detalle es del inspector: se la pide al lead, no la escribe.

### "secretaria-mac"
Archivos: TamioMac/PantallaMembresia.swift, PantallaCartas.swift,
PantallaActas.swift, PantallaAgenda.swift, PantallaServicios.swift,
PantallaInformes.swift, HojasDeCulto.swift, Nuevo*.swift, Nueva*.swift.

1. Servicios: "Hoja de culto (PDF)" y el estado vacío de visitantes. Reutilizar
   el generador de PDF compartido de Tamio/Views/Components o Tamio/Support; no
   escribir uno nuevo. Si no existe ninguno para cultos, reportarlo al lead.
2. Actas: ver y exportar el PDF del acta. El generador ya existe en el código
   compartido (testElActaTienePDF pasa en iOS). Enchufarlo en el Mac.
3. Informes de membresía: la tabla de traslados (PantallaInformes.swift ~:152)
   enseña el folio pero sin cabecera FOLIO ni columna de estado, y se titula
   "TRANSFERS" en vez de "TRANSFER MOVEMENTS". RANGE NO es de esa tabla: es la
   banda Desde/Hasta del periodo "Rango", y hoy es un FALLO —el Mac ofrece
   "Rango" pero nadie escribe rangoDesde/rangoHasta, así que se queda en «del
   mes pasado a hoy»—; va bajo el selector (~:67). Y "Exportar CSV" usando el
   exportador compartido que ya usa iOS. (Auditoría puesta al día el 22-sep.)
4. Cartas: verificar contra el handoff que el panel derecho y las tres
   subpestañas (VARIABLES, INTERNAL NOTES, RESOLVED, "Issue the letter") se
   dibujan de verdad. Esto se arregló el 21-sep; solo cerrar lo que quede.
5. Actas: comprobar si "Solicitar segunda firma" y firmar desde el Mac
   funcionan de punta a punta. Si falta, implementarlo con el repositorio
   compartido; no inventar estados de firma nuevos.
6. Membresía: revisar que la subpestaña Seguimiento registra una acción y llega
   a la base (el lead comprueba la fila en el contenedor).

### "verificador"
No edita código. Es el ÚNICO que corre xcodebuild:
  xcodebuild -scheme TamioMac -derivedDataPath /tmp/dd-verificador build
Compila cada vez que un teammate le avise y le devuelve errores y avisos.
Además, antes de cada compilación revisa con git status / git diff --stat que:
- nadie creó archivos nuevos,
- nadie tocó Tamio/Data, Tamio/Models ni el .pbxproj,
- cada teammate cambió solo sus archivos.
Si algo de eso pasa, avisa al lead y no compila hasta que se resuelva.

### Tú, el lead
- Casos nuevos en SeccionMac.altaTitulo y ComandosTamio cuando un teammate los
  necesite (p. ej. "Importar aportantes…").
- Cabecera "WHAT WAS SAVED" en InspectorTamio para el Registro.
- Cambios en Tamio/Data que te pidan, de uno en uno.
- Al final: el verificador compila limpio y tú añades a CONTEXTO.md una sección
  §0.-23 con qué se hizo, qué se compiló y qué falta ver en pantalla.

Reglas: nadie edita un archivo que no es suyo; sin archivos nuevos; sin pruebas
de interfaz; sin git push. Commits pequeños, en español, explicando el porqué.
Espera a que los tres terminen antes de escribir CONTEXTO.md.

---

## Decisiones de Iván (antes de lanzar el Prompt 2)

Estas cosas NO están en las tareas porque mueven dinero o son diseño. Si quieres
que entren, añádelas tú al prompt:

1. **Por revisar**: los botones "Aprobar todo lo seguro" y "Pedir datos" están
   ausentes a propósito. ¿Se escriben ya?
2. **Movimientos**: "Aprobar ⌘R", "Marcar depositado ⇧⌘B", "Devolver a la
   bandeja". Mismo caso.
3. **Depósitos**: "Nuevo depósito…" desde el Mac. Hoy no existe.
4. **Configuración**: cabe en 961 pt, media MacBook de 14" son 900. Bajar más
   pide barra de secciones más estrecha o que se pliegue. Es diseño tuyo.
5. **Cartas**: `destinatarioTipo` — las claves de "portador" y "otra persona"
   no están verificadas contra la tabla. Hay que mirar Supabase antes.
