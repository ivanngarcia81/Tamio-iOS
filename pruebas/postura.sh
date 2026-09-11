#!/bin/zsh
# postura.sh <udid> <nombre> <orient> <idioma> <apariencia> <tamano>
UDID=$1; NOM=$2; ORI=$3; IDI=$4; APA=$5; TAM=$6
S=/private/tmp/claude-501/-Users-ivangarcia/67ead6cd-f924-4313-8f7e-cbb86f71c8de/scratchpad
LOG=$S/logs/$NOM.log; DEST=$S/capturas/$NOM
mkdir -p $S/logs $DEST; rm -f $LOG
xcrun simctl ui $UDID appearance $APA >/dev/null 2>&1
xcrun simctl ui $UDID content_size $TAM >/dev/null 2>&1
ROT=si; [[ $ORI == vertical ]] && ROT=no
( $S/capturar.sh $UDID $LOG $DEST $ROT > $S/logs/cap-$NOM.log 2>&1 & )
cd $S/copia
TEST_RUNNER_POSTURA=$NOM TEST_RUNNER_ORIENT=$ORI TEST_RUNNER_IDIOMA=$IDI \
xcodebuild -scheme Tamio -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath $S/dd -only-testing:PruebasIPad/RecorridoIPadUITests \
  test-without-building > $LOG 2>&1
echo "[$NOM] $(grep -cE 'Executed [0-9]+ tests?' $LOG) · capturas: $(ls $DEST 2>/dev/null | wc -l | tr -d ' ')"
