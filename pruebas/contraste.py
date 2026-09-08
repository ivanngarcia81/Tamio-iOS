#!/usr/bin/env python3
"""Contraste WCAG leído del PNG de `simctl io screenshot`, sin dependencias.

    python3 pruebas/contraste.py captura.png rect X0 Y0 X1 Y1

Imprime los ocho colores más frecuentes del rectángulo (en píxeles del PNG,
no en puntos: en el iPhone 17e multiplicar los puntos por 3) y la relación de
contraste entre el más oscuro y el más claro de ellos. Los mínimos: 4.5:1 para
texto normal, 3:1 para texto grande (≥ 18 pt, o ≥ 14 pt en negrita).

Se escribió el 8 de septiembre de 2026 para la pasada de interfaz del iPhone.
Es un lector de PNG en Python puro —zlib y los cinco filtros—, porque el Mac
de desarrollo no tiene PIL ni numpy y no hace falta instalarlos para esto.

**Medir el MISMO rótulo en dos alturas distintas** es lo que distingue una
causa de otra: la primera cabecera de Ingresos medía 1.78:1 y parecía el
desvanecido de la barra de cristal; "LUNES 7 SEP", a media pantalla, medía
1.74:1, así que no era la barra: era el gris aplicado dos veces (§4).
"""
import zlib, struct, sys

def leer(path):
    d = open(path,'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    pos = 8; idat = b''; w=h=bd=ct=None
    while pos < len(d):
        ln = struct.unpack('>I', d[pos:pos+4])[0]; typ = d[pos+4:pos+8]
        data = d[pos+8:pos+8+ln]; pos += 12+ln
        if typ == b'IHDR':
            w,h,bd,ct,comp,filt,inter = struct.unpack('>IIBBBBB', data)
            assert bd==8 and inter==0, (bd,inter)
        elif typ == b'IDAT': idat += data
        elif typ == b'IEND': break
    raw = zlib.decompress(idat)
    canales = {0:1,2:3,3:1,4:2,6:4}[ct]
    stride = w*canales
    out = bytearray(h*stride); prev = bytearray(stride); p=0
    for y in range(h):
        f = raw[p]; p+=1
        linea = bytearray(raw[p:p+stride]); p+=stride
        for i in range(stride):
            a = linea[i-canales] if i>=canales else 0
            b = prev[i]; c = prev[i-canales] if i>=canales else 0
            if f==1: linea[i]=(linea[i]+a)&255
            elif f==2: linea[i]=(linea[i]+b)&255
            elif f==3: linea[i]=(linea[i]+(a+b)//2)&255
            elif f==4:
                pa=abs(b-c); pb=abs(a-c); pc=abs(a+b-2*c)
                pr = a if (pa<=pb and pa<=pc) else (b if pb<=pc else c)
                linea[i]=(linea[i]+pr)&255
        out[y*stride:(y+1)*stride] = linea; prev = linea
    return w,h,canales,out

def px(img, x, y):
    w,h,c,data = img
    i = (y*w+x)*c
    if c>=3: return data[i],data[i+1],data[i+2]
    return (data[i],)*3

def lum(rgb):
    def f(v):
        v/=255.0
        return v/12.92 if v<=0.03928 else ((v+0.055)/1.055)**2.4
    r,g,b = rgb
    return .2126*f(r)+.7152*f(g)+.0722*f(b)

def contraste(a,b):
    la,lb = lum(a),lum(b)
    if la<lb: la,lb = lb,la
    return (la+0.05)/(lb+0.05)

if __name__ == '__main__':
    img = leer(sys.argv[1])
    modo = sys.argv[2]
    if modo == 'rect':
        x0,y0,x1,y1 = map(int, sys.argv[3:7])
        cuenta = {}
        for y in range(y0,y1):
            for x in range(x0,x1):
                p = px(img,x,y); cuenta[p] = cuenta.get(p,0)+1
        top = sorted(cuenta.items(), key=lambda kv:-kv[1])[:8]
        for p,n in top: print(p, n)
        # el más oscuro y el más claro entre los frecuentes
        frec = [p for p,n in top]
        osc = min(frec, key=lum); cla = max(frec, key=lum)
        print("min", osc, "max", cla, "contraste %.2f:1" % contraste(osc,cla))
