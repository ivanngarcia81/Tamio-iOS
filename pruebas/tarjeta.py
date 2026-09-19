#!/usr/bin/env python3
"""Mide una tarjeta de color en una captura: cuerpo, filo, sombra y contraste.

    python3 pruebas/tarjeta.py captura.png morada|verde|azul [--pt 440]

Es lo que distingue un material de otro en la pantalla DE VERDAD: el cristal y
la tarjeta opaca se parecen en el simulador y hay que ver qué devuelve la P3
del iPhone. Localiza la tarjeta por color —lo de dentro no toca los bordes— y
saca:

- el cuerpo (píxel a media altura, a la derecha del texto),
- el filo del borde superior: cuánto sube el canal dominante justo por dentro,
- la sombra bajo el borde inferior: caída de luminancia saltando el antialias,
  y hasta dónde llega antes de volver al fondo (un SALTO seco = recortada),
- el contraste del título: los dos colores dominantes en la franja de 28 a
  100 pt bajo el borde, a la derecha del icono.

El fondo se toma como el color más frecuente de la columna x=8, que en estas
pantallas nunca lleva contenido. Sin dependencias: usa `contraste.py`.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from contraste import leer, px, lum, contraste

PRED = {
    "morada": lambda c: c[0] > 90 and c[2] > 180 and c[1] < 130,
    "moradaOscura": lambda c: 140 < c[0] < 200 and c[2] > 230 and c[1] < 175,
    "verde": lambda c: c[1] > c[0] + 40 and c[1] > c[2] + 20 and c[1] < 160,
    "verdeOscuro": lambda c: c[1] > c[0] + 60 and c[1] > c[2] + 40 and c[1] >= 160,
    "azul": lambda c: c[2] > c[0] + 40 and c[2] > 150,
}

def medir(ruta, pred, pt_ancho=None, dominante=None):
    img = leer(ruta); W, H = img[0], img[1]
    esc = W / (pt_ancho or {1170: 393, 1320: 440, 1179: 393, 1290: 430}.get(W, W / 3.0))
    cuenta = {}
    for y in range(0, H, 3):
        c = px(img, 8, y)[:3]; cuenta[c] = cuenta.get(c, 0) + 1
    fondo = max(cuenta, key=cuenta.get)
    filas = [y for y in range(int(H * 0.2), int(H * 0.85)) if any(pred(px(img, x, y)[:3]) for x in range(0, W, 3))]
    if not filas: return f"{os.path.basename(ruta)}: no hay tarjeta de ese color"
    a, b = min(filas), max(filas)
    cols = [x for x in range(W) if any(pred(px(img, x, y)[:3]) for y in range(a, b, 3))]
    l, r = min(cols), max(cols)
    cx = (l + r) // 2; colx = r - int(45 * esc)
    cuerpo = px(img, cx, (a + b) // 2 + int(20 * esc))[:3]
    # filo superior: el píxel más LUMINOSO en los 7 px por dentro del borde, en
    # una columna sin texto. Por luminancia y no por canal: en el morado el azul
    # ya está en 236 y no tiene margen, y salía "+-1" con el filo a la vista.
    yt = min(y for y in range(a, b) if pred(px(img, colx, y)[:3]))
    # La ventana empieza 6 px POR ENCIMA del primer píxel que pasa el predicado:
    # un trazo blanco al 55 % sobre morado da (196,166,247), que el predicado
    # del morado rechaza, y el filo quedaba fuera de la ventana. Se excluye lo
    # que sea fondo, para que el fondo de arriba no gane.
    # Y solo píxeles CON COLOR (croma ≥ 25, la misma regla de las placas): el
    # antialias gris del borde contra la sombra, (200,200,204), se colaba como
    # "filo" y no lo es.
    croma = lambda c: max(c) - min(c)
    filo = max((c for c in (px(img, colx, y)[:3] for y in range(yt - 6, yt + 5)) if croma(c) >= 25), key=lum)
    # sombra
    yb = max(y for y in range(a, b + 1) if pred(px(img, cx, y)[:3]))
    peor = fondo
    for d in range(4, int(20 * esc)):
        c = px(img, cx, yb + d)[:3]
        if lum(c) < lum(peor): peor = c
    prev = None; alcance = None
    for d in range(0, int(200 * esc), 2):
        c = px(img, cx, yb + d)[:3]
        if prev is not None and prev != fondo and c == fondo: alcance = (d / esc, prev); break
        prev = c
    # título
    cuenta = {}
    for y in range(yt + int(28 * esc), yt + int(100 * esc)):
        for x in range(l + int(100 * esc), r - int(20 * esc), 2):
            c = px(img, x, y)[:3]; cuenta[c] = cuenta.get(c, 0) + 1
    # Los extremos de luminancia entre los colores con presencia real (≥ 25 px),
    # no los ocho más frecuentes: una tinta negra sobre morado se reparte en
    # decenas de tonos antialiasados y ninguno llegaba al top 8, y salía 1.04:1
    # comparando dos matices del cuerpo entre sí.
    top = [c for c, n in cuenta.items() if n >= 25]
    osc = min(top, key=lum); cla = max(top, key=lum)
    corte = "sin salto" if alcance and max(abs(alcance[1][i] - fondo[i]) for i in range(3)) <= 3 else "no vuelve limpio al fondo: la tapa algo (tarjeta vecina, barra) o está recortada"
    if lum(fondo) < 0.01:
        sombra = "   sombra: no medible sobre negro (una sombra negra sobre negro no existe)"
    elif alcance:
        sombra = f"   sombra: caída {100*(1-lum(peor)/lum(fondo)):.1f} % · llega al fondo a {alcance[0]:.1f} pt · {corte}"
    else:
        sombra = f"   sombra: caída {100*(1-lum(peor)/lum(fondo)):.1f} % · no vuelve al fondo en 200 pt"
    return "\n".join([
        f"{os.path.basename(ruta)}  ({W}x{H} px, {esc:.2f} px/pt, fondo {fondo})",
        f"   tarjeta {(r-l)/esc:.0f}×{(b-a)/esc:.0f} pt · cuerpo {cuerpo}",
        f"   filo superior: {cuerpo} → {filo}  (lum +{lum(filo)-lum(cuerpo):.3f})",
        sombra,
        f"   título: {osc} sobre {cla} → {contraste(osc, cla):.2f}:1   (mínimo 4.5 · meta 5)",
    ])

if __name__ == "__main__":
    if len(sys.argv) < 3: sys.exit(__doc__)
    pt = None
    if "--pt" in sys.argv: pt = float(sys.argv[sys.argv.index("--pt") + 1])
    print(medir(sys.argv[1], PRED[sys.argv[2]], pt))
