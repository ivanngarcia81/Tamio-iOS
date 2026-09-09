# Comprobación del camino del dinero · en el iPad, con la cuenta real

Esta lista existe porque **hay cosas que un simulador no puede contestar**. Todo
lo que se podía automatizar está en `pruebas/` y corre solo; lo de aquí abajo
no, y hasta que alguien lo haga la respuesta a "¿está lista la app?" es "no se
sabe".

Va en el orden en que se nota usando la app un domingo. **Anota lo que veas,
aunque salga bien**: media lista marcada no sirve de nada.

---

## 0. Antes de empezar

- [ ] La app instalada desde `liquid-glass`, **con el modo revisión apagado**
      (`ModoRevision.activada = false`, que es como está en el repo).
- [ ] Sesión iniciada con la cuenta real de la iglesia.
- [ ] Si puedes, ten a mano el web (`Tamio-app`) abierto en otra pantalla: la
      mitad de las comprobaciones son "¿dice lo mismo en los dos sitios?".
- [ ] Apunta la **hora y la zona horaria** del iPad. Varias de las trampas de
      abajo solo se ven fuera de UTC, y Monterrey va seis horas por detrás.

---

## 1. Un ingreso, de principio a fin

- [ ] Registra un ingreso con un importe raro y fácil de buscar (`$1,234.56`).
- [ ] **La lista lo enseña con ese importe exacto**, sin redondear ni cambiar de
      signo.
- [ ] El total de la pantalla **subió exactamente esa cantidad**.
- [ ] Ábrelo, edítale el importe, guarda. **La lista y el detalle enseñan el
      importe nuevo sin salir y volver a entrar.**

> Ese último punto está aquí por algo concreto: ver el §4.

---

## 2. La fecha — **la comprobación más importante de la lista**

Se sabe que la app mezcla dos formas de guardar fechas, y una de las dos se
corre un día en cuanto el aparato no está en UTC. Medido en el importador; falta
saber **hasta dónde llega**.

- [ ] Crea un movimiento con fecha **de hoy**. ¿El detalle dice hoy?
- [ ] Crea uno con fecha **de otro día** (elige un día 1 de mes, que es donde más
      canta). ¿Dice ese día?
- [ ] **Crea un movimiento en el web** con una fecha concreta, sincroniza, y
      ábrelo en el iPad. ¿Dice la misma fecha que el web?
- [ ] Lo mismo al revés: uno creado en el iPad, mirado en el web.
- [ ] Importa un CSV de aportes con una fecha conocida y mira la ficha del
      aportante. **Hoy sale un día antes** — está medido, se espera que falle.
- [ ] Haz una de estas pruebas **después de las 18:00**, que es cuando la
      diferencia entre la hora local y UTC cambia de día.

Si alguna sale corrida, anota **cuál pantalla y en qué sentido**: eso decide si
es un formateo o un dato mal guardado.

---

## 3. Corte, depósito y firma

- [ ] Haz un corte con billetes y monedas. **La suma que enseña es la que sale a
      mano.**
- [ ] Regístralo como depósito, con foto del comprobante.
- [ ] Fírmalo. Cierra la app **del todo** (deslizar hacia arriba, no solo al
      fondo) y vuelve a abrirla: **la firma sigue ahí y el comprobante también**.
- [ ] Míralo en el web. ¿Mismo importe, misma fecha, mismo estado?

---

## 4. La pantalla que no se entera

Está medido en el importador y **no es solo del importador**: ocho modelos de la
app —`Aportante`, `Movimiento`, `Acta`, `Servicio`, `Corte`, `Miembro`,
`Apunte`, `Revision`— dicen que dos fichas son iguales si **tienen el mismo id**,
sin mirar el contenido. Para SwiftUI eso significa "no ha cambiado nada, no lo
vuelvo a dibujar".

Se nota así: **cambias algo y la pantalla sigue enseñando lo de antes**, hasta
que sales a otra ficha y vuelves.

- [ ] Con una ficha abierta al lado (iPad en apaisado), edita esa misma ficha
      desde la lista. ¿Se actualiza el panel de la derecha?
- [ ] Importa aportes de alguien que tengas abierto. ¿Sube su total?
- [ ] Marca un movimiento como depositado con el detalle abierto. ¿Cambia?
- [ ] Cierra un acta con el acta abierta. ¿Cambia la pastilla de estado?

Cada uno que falle es un sitio donde el tesorero cree que no se guardó y lo hace
dos veces.

---

## 5. La sincronización, en los dos sentidos

- [ ] Con **el modo avión puesto**: crea dos movimientos y edita uno. Quítalo y
      espera. ¿Suben los tres cambios?
- [ ] Cambia lo mismo en el web y en el iPad **a la vez** y sincroniza. ¿Cuál
      gana? ¿Se pierde algo sin avisar?
- [ ] Borra algo en el web. ¿Desaparece del iPad?
- [ ] Mira el importe de algo que hayas subido: **céntimos exactos**, no
      redondeados.

---

## 6. Teclado físico

Nada de esto se pudo medir: las teclas no le llegan a la app en el simulador.

- [ ] Abre cualquier hoja y pulsa **Esc**. ¿Se cierra? (Si no, el arreglo está
      escrito y probado a medias: `.keyboardShortcut(.cancelAction)` en los
      treinta botones de cancelar.)
- [ ] Pulsa **⌘K**. La sidebar lo anuncia al lado del buscador y **ese atajo no
      existe en el código**: o se conecta o se borra el rótulo.
- [ ] Tab entre los campos de una hoja: ¿va en un orden que tenga sentido?

---

## 7. Accesibilidad, con el candado puesto

- [ ] Enciende VoiceOver, pon el candado (Ajustes · Cuenta) y **escucha** la
      pantalla de bloqueo. ¿Lee las cifras de Inicio que hay por debajo?

Esto **no se puede medir con pruebas automáticas** —XCUITest lista los elementos
aunque estén marcados como ocultos, comprobado— así que hace falta VoiceOver de
verdad. Si los lee, hay que taparlos.

---

## 8. Cuando algo falle

Anota tres cosas y con eso se arregla en una sesión:

1. **Qué hiciste**, en pasos, desde abrir la app.
2. **Qué esperabas y qué salió** — con captura si es de pantalla, y con el
      importe/fecha exactos si es de datos.
3. **Si se repite**: hazlo otra vez. Un fallo intermitente y uno seguro se
      arreglan de forma distinta, y no se descarta uno intermitente con una
      corrida buena.
