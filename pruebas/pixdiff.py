"""Diferencia de píxeles entre dos capturas, ignorando la franja superior
(reloj y aviso del modo revisión). Sin dependencias: zlib y los cinco filtros
PNG, como `pruebas/contraste.py`."""
import sys, zlib, struct

def leer(path):
    d = open(path, 'rb').read(); pos = 8; idat = b''
    while pos < len(d):
        l = struct.unpack('>I', d[pos:pos+4])[0]; t = d[pos+4:pos+8]; c = d[pos+8:pos+8+l]
        if t == b'IHDR': w, h, bd, ct = struct.unpack('>IIBB', c[:10])
        if t == b'IDAT': idat += c
        pos += 12 + l
    raw = zlib.decompress(idat); bpp = {2: 3, 6: 4}[ct]; stride = w * bpp
    filas = []; prev = bytearray(stride); i = 0
    for _ in range(h):
        f = raw[i]; i += 1; line = bytearray(raw[i:i+stride]); i += stride
        for x in range(stride):
            a = line[x-bpp] if x >= bpp else 0; b = prev[x]; c2 = prev[x-bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b)//2) & 255
            elif f == 4:
                pa = abs(b-c2); pb = abs(a-c2); pc = abs(a+b-2*c2)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c2)
                line[x] = (line[x] + pr) & 255
        filas.append(bytes(line)); prev = line
    return w, h, bpp, filas

def diff(p1, p2, saltar=140, umbral=12):
    w1, h1, b1, f1 = leer(p1); w2, h2, b2, f2 = leer(p2)
    if (w1, h1) != (w2, h2): return None, f"tamaños distintos {w1}x{h1} vs {w2}x{h2}"
    dist = 0; total = 0; primera = None
    for y in range(saltar, h1):
        r1 = f1[y]; r2 = f2[y]
        for x in range(0, w1*b1, b1):
            total += 1
            if abs(r1[x]-r2[x]) > umbral or abs(r1[x+1]-r2[x+1]) > umbral or abs(r1[x+2]-r2[x+2]) > umbral:
                dist += 1
                if primera is None: primera = (x//b1, y)
    return 100.0*dist/total, primera

if __name__ == '__main__':
    pct, donde = diff(sys.argv[1], sys.argv[2])
    print(f"{pct:.3f}% distinto, primer píxel {donde}" if pct is not None else donde)
