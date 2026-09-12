#!/bin/zsh
# Monta la COPIA con la que se corren las pruebas EN EL APARATO, y las lanza.
#
# Por que una copia: el `.pbxproj` de este repo esta editado a mano y NO declara
# los paquetes SPM (§2.1 del traspaso). Correr `xcodegen` aqui borraria GRDB y
# Supabase del proyecto. Asi que se genera un proyecto aparte y el repo no se
# toca nunca.
#
# Por que el bundle id REAL (`church.tamio.native`) y no uno propio: en un
# aparato fisico el llavero NO se comparte entre apps, al contrario que en el
# simulador. Con un id propio la copia arranca en la pantalla de acceso y sin
# datos, y las pruebas que necesitan sesion no prueban nada. El precio es que la
# copia PISA la app instalada: hacer el respaldo antes.
#
# Uso:  pruebas/aparato.sh [--limpio] <UDID-hardware> [-only-testing:PruebasUIAparato/Clase]
#
# El UDID de hardware es el de la columna Identifier de `devicectl list devices`
# para la fila `physical`. NO es el mismo que el `--device` de `devicectl`, que
# es otro identificador del mismo aparato. Y cuidado: hay un SIMULADOR llamado
# igual que el telefono, asi que por nombre se coge el equivocado.
#
# `--limpio` rehace la copia desde cero. Sin ella se REUTILIZA: se sincroniza
# encima y se conservan el `.build` de SPM y el DerivedData de la copia, que es
# lo que se lleva casi todos los minutos. Rehacerla de cero en cada vuelta
# cuesta ~8 min por corrida y no hace falta cuando lo único que cambió es una
# prueba. Con `--limpio` cuando se toque el `project.yml`, un paquete, o cuando
# algo huela a caché.
set -e

# **Un cerrojo, porque dos corridas se pisan de verdad.** Comparten la copia, el
# log y el aparato: lanzar una segunda mientras la primera corre deja a las dos
# con «Executed 0 tests» y un log que es de la otra. Pasó el 12-sep y costó
# media hora de diagnóstico sobre resultados que no eran del código que creía
# estar midiendo.
CERROJO="${TMPDIR:-/tmp}/tamio-aparato.lock"
if ! /bin/mkdir "$CERROJO" 2>/dev/null; then
  echo "!! ya hay una corrida en marcha (cerrojo: $CERROJO)." >&2
  echo "   Espera a que termine, o bórralo si quedó huérfano." >&2
  exit 75
fi
trap '/bin/rmdir "$CERROJO" 2>/dev/null' EXIT

LIMPIO=0
if [[ "$1" == "--limpio" ]]; then LIMPIO=1; shift; fi
UDID="${1:?falta el UDID de hardware (devicectl list devices, fila physical)}"
shift
REPO="${0:A:h:h}"
COPIA="${TMPDIR:-/tmp}/tamio-aparato"

if (( LIMPIO )) || [[ ! -d "$COPIA" ]]; then
  echo "--- copia NUEVA en $COPIA"
  rm -rf "$COPIA"; mkdir -p "$COPIA"
else
  echo "--- REUTILIZANDO la copia de $COPIA (usa --limpio para rehacerla)"
fi
# `--delete` para que un archivo borrado en el repo no siga vivo en la copia y
# se compile a la espalda de uno. Se protegen lo generado y lo descargado.
rsync -a --delete \
      --exclude .git --exclude Tamio.xcodeproj --exclude 'DerivedData*' \
      --exclude 'Tamio.xcodeproj/' --exclude '.build/' --exclude '*.xcresult' \
      --exclude 'prueba.log' \
      "$REPO/" "$COPIA/"

python3 "$REPO/pruebas/aparato_yaml.py" "$COPIA/project.yml"

cd "$COPIA"
xcodegen generate      # en la COPIA, nunca en el repo

# NO pasar xcodebuild por un grep ni por un tail: el codigo de salida pasa a ser
# el del ultimo comando de la tuberia. Una compilacion fallida da "exit 0" y las
# pruebas corren con el paquete VIEJO. Se redirige a un archivo y se confirma el
# `TEST BUILD SUCCEEDED` aparte.
LOG="$COPIA/prueba.log"
# `xcodebuild` se niega a pisar un `.xcresult` que ya existe —"Existing file at
# -resultBundlePath"—, y al reutilizar la copia el de la vuelta anterior sigue
# ahí. Se borra aquí y no con el `--delete` del rsync, porque el rsync lo
# protege a propósito: si la corrida falla, el bundle de la anterior es lo único
# que queda para mirar.
rm -rf "$COPIA/resultado.xcresult"
set +e
xcodebuild test -scheme Tamio -destination "id=$UDID" \
  -allowProvisioningUpdates -resultBundlePath "$COPIA/resultado.xcresult" \
  "$@" > "$LOG" 2>&1
EXIT=$?
set -e

echo "--- exit $EXIT"
echo "--- log:       $LOG"
echo "--- resultado: $COPIA/resultado.xcresult"
# Contar las pruebas EJECUTADAS, no fiarse del "passed": un `-only-testing` que
# no casa con ninguna clase se salta en silencio.
/usr/bin/grep -E "TEST BUILD (SUCCEEDED|FAILED)|Executed [0-9]+ test|Testing failed|error:|QA-" "$LOG" \
  | sort -u | head -60
exit $EXIT
