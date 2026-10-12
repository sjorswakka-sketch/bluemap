#!/bin/sh
# Draait alle speltests (tests/*_test.gd). Mislukt ook als er een scriptfout in het spel optreedt.
# Eerst smoke_test, dan playthrough_test, daarna de rest op alfabet (de tests van de uitbreidingen).
# Een test is geslaagd als hij eindigt met een regel als "SMOKE TEST OK" of "PLAYTHROUGH OK" (HOOFDLETTERS + " OK").
# Gebruik:  sh tools/run_tests.sh [pad/naar/godot]
GODOT="${1:-godot}"
cd "$(dirname "$0")/.." || exit 1
# Eigen opslagmap voor de tests, zodat ze nooit in je echte spel of in een andere testrun schrijven.
XDG_DATA_HOME="$(pwd)/.testdata"
export XDG_DATA_HOME
# De tests controleren Nederlandse tekst: het spel draait in het Nederlands (zie scripts/core/lang.gd). Een taalkeuze
# die een eerdere (afgebroken) testrun in de instellingen heeft laten staan, gooien we weg: die zou voorgaan.
BLUEMAP_LANG=nl
export BLUEMAP_LANG
rm -f "$XDG_DATA_HOME/godot/app_userdata/Bluemap Quest/settings.cfg"
"$GODOT" --headless --path . --import > /dev/null 2>&1
ORDER="smoke_test playthrough_test"
for FILE in tests/*_test.gd; do
  NAME=$(basename "$FILE" .gd)
  case " $ORDER " in *" $NAME "*) ;; *) ORDER="$ORDER $NAME" ;; esac
done
for NAME in $ORDER; do
  [ -f "tests/$NAME.gd" ] || continue
  echo "== tests/$NAME.gd"
  LOG=$(mktemp)
  "$GODOT" --headless --fixed-fps 60 --path . -s "tests/$NAME.gd" 2>&1 | grep -vE "ALSA|audio driver|at: cleanup|ObjectDB instances|resources still in use|at: clear|^Godot Engine" | tee "$LOG"
  if grep -qE "SCRIPT ERROR|Parse Error|FAIL " "$LOG"; then
    echo "TESTS MISLUKT in $NAME (zie fouten hierboven)"
    rm -f "$LOG"
    exit 1
  fi
  grep -qE "^[A-Z][A-Z0-9 _-]* OK$" "$LOG" || { echo "TESTS MISLUKT: $NAME is niet afgemaakt"; rm -f "$LOG"; exit 1; }
  rm -f "$LOG"
done
echo "ALLE TESTS GESLAAGD"
