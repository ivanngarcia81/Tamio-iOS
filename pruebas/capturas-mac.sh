#!/bin/zsh
# Las diez capturas de la ficha del Mac, con la maqueta (`-modoRevision YES`), a 1440×900.
#
# Uso:  pruebas/capturas-mac.sh en|es
#
# Sale en docs/capturas-tienda/mac-en/ o docs/capturas-tienda/mac/.
#
# A diferencia de `capturas-tienda.sh`, no hace falta copia ni parche: el Mac no pinta el
# aviso naranja del modo revisión, y el argumento enciende la maqueta en la app de Debug
# ya instalada en /Applications. En inglés la maqueta es «New Life Church», Houston: la
# iglesia del revisor de Apple.
#
# Lo que hay que saber (24-sep):
# - La ventana se coloca en {100, 60} y las filas de la barra lateral sin atajo (Cartas,
#   Agenda) se clican por POSICIÓN, con los dos grupos desplegados. Por índice no: el guion
#   de la barra lateral cuenta también los botones del contenido y llegó a pulsar
#   «Preparar un respaldo».
# - Cerrar antes la app de Tamio en los simuladores: System Events confunde los dos
#   procesos que se llaman «Tamio».
# - Ingresos y Cartas eligen su primera fila: sin ella el inspector dice «Nothing
#   selected» y la hoja de la carta sale vacía.
# - 1440×900 es uno de los tamaños que acepta la Mac App Store; en una pantalla 1x sale a
#   1440×900 píxeles.
IDI=$1
DEST="${0:A:h:h}/docs/capturas-tienda/mac"; [[ $IDI == en ]] && DEST=$DEST-en
mkdir -p $DEST; rm -f $DEST/*.png(N)
if [[ $IDI == en ]]; then A=(-prefs.idioma ingles -AppleLanguages "(en-US)" -AppleLocale en_US)
else A=(-prefs.idioma espanol -AppleLanguages "(es-MX)" -AppleLocale es_MX); fi
osascript -e 'tell application "Tamio" to quit' 2>/dev/null
for i in {1..15}; do pgrep -f '/Applications/Tamio.app/Contents/MacOS/Tamio' >/dev/null || break; sleep 1; done
open -a /Applications/Tamio.app --args -modoRevision YES -bloqueo.biometrico NO -prefs.bienvenidaVista YES $A
for i in {1..40}; do osascript -e 'tell application "System Events" to tell process "Tamio" to count windows' 2>/dev/null | grep -q '^[1-9]' && break; sleep 1; done
sleep 4
osascript -e 'tell application "System Events" to tell process "Tamio" to set position of window 1 to {100, 60}' -e 'tell application "System Events" to tell process "Tamio" to set size of window 1 to {1440, 900}'
tk(){ osascript -e 'tell application "Tamio" to activate' -e "tell application \"System Events\" to keystroke \"$1\" using command down" >/dev/null; }
tk 1; sleep 1
# El inspector, abierto como columna (a 1440 cabe).
# El menú se llama «View» o «Visualización» según el idioma.
for menu in View Visualización; do
  osascript -e "tell application \"System Events\" to tell process \"Tamio\" to get name of every menu item of menu \"$menu\" of menu bar 1" 2>/dev/null \
    | grep -qE 'Show inspector|Mostrar inspector' && { tk i; sleep 1; }
done
foto(){ osascript -e 'tell application "System Events" to tell process "Tamio" to set size of window 1 to {1440, 900}' >/dev/null; sleep 2.5
  n=$(osascript -e 'tell application "System Events" to tell process "Tamio" to get name of window 1'); echo "$1 · $n"
  screencapture -x -o -R 100,60,1440,900 $DEST/$1.png; }
tk 1; foto 01-inicio
tk 2; sleep 1.5; ~/.claude/herramientas/clic 1000 196 >/dev/null; sleep 1; foto 02-ingresos
tk 6; foto 03-depositos
tk 5; foto 04-reportes
tk 7; foto 05-por-revisar
tk 8; foto 06-membresia
tk 9; foto 07-actas
~/.claude/herramientas/clic 180 582 >/dev/null; sleep 1.5; ~/.claude/herramientas/clic 421 192 >/dev/null; sleep 1; foto 08-cartas
~/.claude/herramientas/clic 180 613 >/dev/null; foto 09-agenda
tk 0; foto 10-registro
sips -g pixelWidth -g pixelHeight $DEST/01-inicio.png | tail -2
