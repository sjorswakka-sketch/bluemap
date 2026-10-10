#!/bin/sh
# Draait de speltest. Mislukt ook als er een scriptfout in het spel optreedt.
# Gebruik:  sh tools/run_tests.sh [pad/naar/godot]
GODOT="${1:-godot}"
cd "$(dirname "$0")/.." || exit 1
"$GODOT" --headless --path . --import > /dev/null 2>&1
for TEST in smoke_test:"SMOKE TEST OK" playthrough_test:"PLAYTHROUGH OK"; do
  NAME="${TEST%%:*}"
  OK="${TEST#*:}"
  echo "== tests/$NAME.gd"
  LOG=$(mktemp)
  "$GODOT" --headless --fixed-fps 60 --path . -s "tests/$NAME.gd" 2>&1 | grep -vE "ALSA|audio driver|at: cleanup|ObjectDB instances|resources still in use|at: clear|^Godot Engine" | tee "$LOG"
  if grep -qE "SCRIPT ERROR|Parse Error|FAIL " "$LOG"; then
    echo "TESTS MISLUKT in $NAME (zie fouten hierboven)"
    rm -f "$LOG"
    exit 1
  fi
  grep -q "$OK" "$LOG" || { echo "TESTS MISLUKT: $NAME is niet afgemaakt"; rm -f "$LOG"; exit 1; }
  rm -f "$LOG"
done
echo "ALLE TESTS GESLAAGD"
