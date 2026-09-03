# Guion de verificación — pendiente de hacer en casa

Todo lo de abajo está escrito y compilando, pero **verificado solo por
compilación**: nadie ha tocado aún estas pantallas con el dedo. Este es el
recorrido que lo confirma.

## 0. Antes de empezar

1. Reinstalar desde Xcode (⌘R con el iPhone como destino). La build que había
   en el teléfono es anterior a todos estos cambios.
2. Comprobar que arriba sale la franja naranja **MODO REVISIÓN**. Si no está,
   la instalación no se actualizó y nada de lo de abajo aplica.

> El modo revisión salta el inicio de sesión y usa datos de ejemplo. Para
> probar lo que toca Supabase de verdad (folios, sincronización, comprobantes)
> hay que apagarlo: `activada = false` en `Tamio/Support/ModoRevision.swift`,
> y entrar con la cuenta real.

## 1. Inicio

- [ ] "Ver todos" (Últimos movimientos) abre Ingresos.
- [ ] "Agenda" (Esta semana) abre la Agenda.
- [ ] La tarjeta "Por revisar" abre la bandeja. En iPad la tarjeta **entera**
      debe ser tocable, no solo el texto del pie.
- [ ] En iPad, esos enlaces mueven la selección de la sidebar.

Los tres eran texto plano pintado de azul: no hacían nada.

## 2. Tesorería

- [ ] Los cuatro enlaces abren su pantalla (Movimientos, Aportantes,
      Depósitos, Reportes).

Ojo: los números de esta pantalla ("132 registros · 14 sin depositar", el
badge de 1 en Depósitos, "Banorte ••4821") **siguen escritos a mano en el
código**. No cambian nunca. Está pendiente de decidir.

## 3. Hoja de captura — los tres ingresos de prueba

Con el modo revisión **apagado** y sesión iniciada.

| # | Qué capturar |
|---|---|
| 1 | Diezmo · $1,000.00 · 3 sep 2026 · Efectivo · Carlos Martínez · constancia SÍ · nota "Diezmo correspondiente a septiembre" |
| 2 | Donativo · $2,500.00 · 2 sep 2026 · Transferencia · María López (visitante) · concepto "Fondo de construcción" · constancia SÍ · adjuntar PDF |
| 3 | Otro / subcategoría "Reembolso" · $685.50 · 1 sep 2026 · Cheque · State Farm · constancia NO · nota "Cheque número 3842" · adjuntar imagen |

- [ ] El menú de **Aportante** trae los miembros reales (Brenda rosado, Carlos
      paz, Juan Martinez, Susana ortiz…), no los cinco nombres inventados.
- [ ] La opción "Otra persona o entidad…" abre un campo para escribir el
      nombre (María López, State Farm).
- [ ] "Dar constancia anual" **no** se bloquea con un visitante.
- [ ] Existe el campo **Subcategoría**.
- [ ] Al adjuntar, el botón dice "Subiendo…" y luego el nombre del archivo.
      Si falla, sale el error en rojo y **no** se queda ninguna ruta guardada.
- [ ] Los folios salen correlativos y sin repetirse.

Carlos Martínez **no está en el padrón**. O se da de alta como miembro (queda
vinculado a su ficha y acumula) o se escribe como "otra persona" (se guarda el
nombre, sin acumulado).

## 4. El motor offline — la prueba que importa

Modo revisión **apagado** y sesión iniciada.

1. [ ] Con red, abrir Ingresos y esperar a que cargue.
2. [ ] **Activar modo avión.**
3. [ ] Capturar un movimiento. Debe guardarse **sin error** y aparecer en la
       lista con folio **`P-…`** (provisional).
4. [ ] **Cerrar la app del todo** y volver a abrirla, aún en modo avión.
       El movimiento debe seguir ahí. Antes esto era imposible: sin red la
       lista salía vacía.
5. [ ] En Ajustes → Sincronización debe verse el número de **cambios sin subir**.
6. [ ] **Quitar el modo avión.** Al volver la app al primer plano sincroniza
       sola (o pulsar "Sincronizar ahora").
7. [ ] El folio `P-…` se convierte en el **definitivo** del servidor.
8. [ ] "Cambios sin subir" vuelve a 0.
9. [ ] Comprobar en Supabase que la fila está en `transactions`.

### Lo que se sabe que aún NO funciona sin red

- **Adjuntar un comprobante**: se sube en el momento de elegirlo. Sin señal
  falla y avisa. Encolar los archivos es el siguiente paso.
- Solo **Movimientos** usa el motor. Las otras 12 pantallas siguen con datos
  de ejemplo.

## 5. Cerrar sesión

- [ ] El botón funciona en iPhone y en iPad (antes no hacía nada).
- [ ] Pide confirmación.
- [ ] Al volver a entrar, no quedan datos de la sesión anterior.

## Datos de prueba en Supabase

Hay tres movimientos con `uid` `prueba-ing-1`, `prueba-ing-2` y `prueba-ing-3`,
metidos por SQL para probar el contador de folios. Aparecerán en Ingresos.
Para borrarlos:

```sql
delete from public.transactions where uid like 'prueba-ing-%';
```
