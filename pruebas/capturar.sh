#!/bin/zsh
# Dispara una captura por cada "MARCA:" que imprima la prueba.
# El adjunto de XCUITest en apaisado sale rotado y recortado (§0.0), asi que
# las capturas se toman desde fuera con simctl y se rotan con sips.
UDID=$1; LOG=$2; DEST=$3; ROTAR=${4:-si}
mkdir -p $DEST
vistas=""
while true; do
  sleep 1
  [[ -f $LOG ]] || continue
  marcas=$(grep -o 'MARCA: [A-Za-z0-9_·-]*' $LOG 2>/dev/null | sed 's/MARCA: //')
  for m in ${(f)marcas}; do
    if [[ ! " $vistas " == *" $m "* ]]; then
      vistas="$vistas $m"
      out=$DEST/$m.png
      xcrun simctl io $UDID screenshot $out >/dev/null 2>&1
      if [[ $ROTAR == si && -f $out ]]; then sips -r -90 $out >/dev/null 2>&1; fi
      echo "  capturada: $m"
    fi
  done
  # fin cuando el log dice que acabo
  if grep -qE "TEST (SUCCEEDED|FAILED)" $LOG 2>/dev/null; then break; fi
done
