#!/bin/zsh
# Genera el juego de capturas de la ficha de App Store, en el SIMULADOR.
#
# Uso:  pruebas/capturas-tienda.sh telefono|ipad [--limpio]
#
# Sale en  docs/capturas-tienda/<telefono|ipad>/NN-nombre.png
#
# ── Por qué una copia y no el repo ──────────────────────────────────────────
# Hacen falta dos cambios que NO pueden quedarse en el repo:
#
#   1. `ModoRevision.activada = true`, o la app abre en la pantalla de acceso:
#      el simulador no tiene sesión (el llavero del aparato no viaja aquí).
#   2. **El aviso naranja de modo revisión, apagado.** Va fijo en lo alto de
#      TODAS las pantallas —a propósito: un modo que salta la autenticación no
#      puede ser invisible— y saldría en las diez capturas de la ficha.
#
# El segundo es el que importa y es el que se olvida: encender el modo revisión
# sin apagar el aviso da diez capturas perfectas con una franja naranja que dice
# "datos de ejemplo" encima. Por eso el parche de abajo FALLA si no encuentra
# su texto, en vez de seguir: un `sed` que no casa no dice nada, y el fallo
# aparece ocho minutos después, en el PNG.
#
# Y por eso también el repo se queda limpio: `git status` después de esto no
# enseña nada, así que no hay forma de subir el modo revisión encendido.
set -e

# **Un cerrojo, por lo mismo que `aparato.sh`.** Las dos corridas —teléfono e
# iPad— comparten la misma copia y el mismo log, así que lanzar la segunda sin
# esperar a la primera deja a las dos revueltas: el `rsync --delete` le quita
# los archivos a la que está compilando y el capturador de una fotografía el
# simulador de la otra. Allí costó media hora el 12-sep; aquí saldría en los
# PNG, que es peor porque se ve tarde.
CERROJO="${TMPDIR:-/tmp}/tamio-tienda.lock"
if ! /bin/mkdir "$CERROJO" 2>/dev/null; then
  echo "!! ya hay una corrida de capturas en marcha (cerrojo: $CERROJO)." >&2
  echo "   Espera a que acabe, o bórralo si quedó huérfano." >&2
  exit 75
fi
trap '/bin/rmdir "$CERROJO" 2>/dev/null' EXIT

QUE="${1:?telefono o ipad}"
LIMPIO=0
[[ "$2" == "--limpio" ]] && LIMPIO=1

REPO="${0:A:h:h}"
COPIA="${TMPDIR:-/tmp}/tamio-tienda"
DEST="$REPO/docs/capturas-tienda/$QUE"

case "$QUE" in
  telefono) SIM="iPhone 17 Pro Max"; PRUEBA="testTelefono"; ROTAR=no ;;
  ipad)     SIM="iPad Pro 13-inch (M5)"; PRUEBA="testIPad"; ROTAR=no ;;
  *) echo "!! primer argumento: telefono o ipad" >&2; exit 2 ;;
esac

# El simulador se busca por nombre, y hay más de uno con el mismo nombre en
# runtimes distintos. Se coge el primero disponible y se dice cuál, que si no
# se pasa media hora mirando por qué la captura es de otra pantalla.
UDID=$(xcrun simctl list devices available \
       | grep -F "$SIM (" | head -1 | sed -E 's/.*\(([-0-9A-F]{36})\).*/\1/')
[[ -n "$UDID" ]] || { echo "!! no hay simulador «$SIM»" >&2; exit 1; }
echo "--- simulador: $SIM  $UDID"

# ── La copia ────────────────────────────────────────────────────────────────
if (( LIMPIO )) || [[ ! -d "$COPIA" ]]; then
  echo "--- copia NUEVA en $COPIA"; rm -rf "$COPIA"; mkdir -p "$COPIA"
else
  echo "--- REUTILIZANDO $COPIA (--limpio para rehacerla)"
fi
rsync -a --delete \
      --exclude .git --exclude Tamio.xcodeproj --exclude 'DerivedData*' \
      --exclude '.build/' --exclude '*.xcresult' --exclude 'prueba.log' \
      --exclude 'docs/capturas-tienda' \
      "$REPO/" "$COPIA/"

python3 - "$COPIA" <<'PY'
import sys, pathlib
copia = pathlib.Path(sys.argv[1])

def parchar(rel, viejo, nuevo, porque):
    f = copia / rel
    s = f.read_text()
    if viejo not in s:
        sys.exit(f"!! el parche de «{porque}» no encontró su texto en {rel}.\n"
                 f"   Se para aquí a propósito: seguir daría capturas mudas.\n"
                 f"   Buscaba: {viejo!r}")
    f.write_text(s.replace(viejo, nuevo, 1))
    print(f"    parchado en la copia: {porque}")

parchar("Tamio/Support/ModoRevision.swift",
        "private static let activada = false",
        "private static let activada = true",
        "modo revisión encendido")

parchar("Tamio/Views/RootView.swift",
        '        if ModoRevision.sinLogin {\n            Text(L.t("MODO REVISIÓN',
        '        if false {  // capturas-tienda.sh\n            Text(L.t("MODO REVISIÓN',
        "aviso naranja apagado")
PY

python3 "$REPO/pruebas/aparato_yaml.py" "$COPIA/project.yml"
cd "$COPIA"
xcodegen generate

# ── El simulador ────────────────────────────────────────────────────────────
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
# La barra de estado de fábrica enseña la hora real y la batería del Mac. No es
# motivo de rechazo, pero una ficha con "3:47 · 23%" se ve a la primera.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 \
  --dataNetwork wifi 2>/dev/null || true
xcrun simctl ui "$UDID" appearance light 2>/dev/null || true

# ── La corrida ──────────────────────────────────────────────────────────────
rm -rf "$COPIA/tienda.xcresult"
LOG="$COPIA/tienda.log"; : > "$LOG"
mkdir -p "$DEST"

# El capturador va POR DETRÁS y mira el log: arranca antes que xcodebuild, o se
# pierde las primeras marcas. Y `xcodebuild` no se pasa por una tubería: el
# código de salida pasaría a ser el del último comando y una compilación
# fallida saldría como éxito.
"$REPO/pruebas/capturar.sh" "$UDID" "$LOG" "$DEST" "$ROTAR" &
CAP=$!

set +e
xcodebuild test -scheme Tamio -destination "id=$UDID" \
  -only-testing:"PruebasUIAparato/CapturasTienda/$PRUEBA" \
  -resultBundlePath "$COPIA/tienda.xcresult" > "$LOG" 2>&1
EXIT=$?
set -e
wait $CAP 2>/dev/null || true

xcrun simctl status_bar "$UDID" clear 2>/dev/null || true

echo "--- exit $EXIT · log: $LOG"
/usr/bin/grep -E "TEST BUILD (SUCCEEDED|FAILED)|Executed [0-9]+ test|error:|!! " "$LOG" \
  | sort -u | head -30
echo "--- capturas en $DEST"
ls -1 "$DEST" 2>/dev/null | sed 's/^/    /'
exit $EXIT
