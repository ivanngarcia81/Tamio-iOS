#!/bin/zsh
# Saca a PNG las capturas que una prueba adjuntó con XCTAttachment.
#   pruebas/fotos.sh <resultado.xcresult> <directorio-destino>
# Es la única forma de tener una captura del iPhone FÍSICO desde el Mac:
# `devicectl` no captura pantalla y `simctl` solo ve simuladores.
set -e
RES=${1:?falta el .xcresult}; DEST=${2:?falta el destino}
mkdir -p "$DEST"
# Xcode 16+ exporta todos los adjuntos de una vez con su manifest.json.
if ! xcrun xcresulttool export attachments --path "$RES" --output-path "$DEST" >/dev/null 2>&1; then
  echo "!! xcresulttool no pudo exportar los adjuntos de $RES" >&2; exit 1
fi
# Los archivos salen con nombres generados; se renombran por el `name` del
# adjunto, que es lo que la prueba puso.
python3 - "$DEST" <<'PY'
import json, os, sys
dest = sys.argv[1]
m = json.load(open(os.path.join(dest, "manifest.json")))
n = 0
for prueba in m:
    for a in prueba.get("attachments", []):
        nombre = a.get("suggestedHumanReadableName") or a.get("name") or ""
        exportado = a.get("exportedFileName")
        if not exportado: continue
        base = nombre.split(".")[0] if nombre else exportado
        # el nombre que puso la prueba, sin el sufijo de fecha que añade Xcode
        for k in ("reportes-claro","reportes-oscuro","cartas-claro","cartas-oscuro"):
            if k in nombre or k in exportado: base = k
        ext = os.path.splitext(exportado)[1] or ".png"
        os.replace(os.path.join(dest, exportado), os.path.join(dest, base + ext)); n += 1
print(f"{n} capturas en {dest}: " + ", ".join(sorted(f for f in os.listdir(dest) if f.endswith('.png'))))
PY
