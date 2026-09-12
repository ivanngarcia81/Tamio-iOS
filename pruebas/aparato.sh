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
# Uso:  pruebas/aparato.sh <UDID-hardware> [-only-testing:PruebasUIAparato/Clase]
#
# El UDID de hardware es el de la columna Identifier de `devicectl list devices`
# para la fila `physical`. NO es el mismo que el `--device` de `devicectl`, que
# es otro identificador del mismo aparato. Y cuidado: hay un SIMULADOR llamado
# igual que el telefono, asi que por nombre se coge el equivocado.
set -e
UDID="${1:?falta el UDID de hardware (devicectl list devices, fila physical)}"
shift
REPO="${0:A:h:h}"
COPIA="${TMPDIR:-/tmp}/tamio-aparato"

rm -rf "$COPIA"; mkdir -p "$COPIA"
rsync -a --exclude .git --exclude Tamio.xcodeproj --exclude 'DerivedData*' "$REPO/" "$COPIA/"

python3 "$REPO/pruebas/aparato_yaml.py" "$COPIA/project.yml"

cd "$COPIA"
xcodegen generate      # en la COPIA, nunca en el repo

# NO pasar xcodebuild por un grep ni por un tail: el codigo de salida pasa a ser
# el del ultimo comando de la tuberia. Una compilacion fallida da "exit 0" y las
# pruebas corren con el paquete VIEJO. Se redirige a un archivo y se confirma el
# `TEST BUILD SUCCEEDED` aparte.
LOG="$COPIA/prueba.log"
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
