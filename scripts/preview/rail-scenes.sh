#!/bin/sh
# Renders the settings page scenes of the rail story offscreen from made-up data:
# default, search with a result, no result, narrow, light, dark and Reduce motion.
# Usage: rail-scenes.sh <out-dir>
set -eu
out=$1
mkdir -p "$out"
cd "$(dirname "$0")"

shot() { # name, extra args before the 5 positional ones, width, theme, query
    name=$1 reduce=$2 w=$3 theme=$4 query=$5
    QT_QPA_PLATFORM=offscreen timeout 60 qml-qt6 -I imports settings-shot.qml -- $reduce \
        "$w" 0 "$theme" "$out/$name.png" "$query" 2>/dev/null
}

for theme in dark light; do
    shot "default-$theme" "" 404 "$theme" ""
    shot "result-$theme" "" 404 "$theme" "sound"
    shot "noresult-$theme" "" 404 "$theme" "zzqqxx"
    shot "narrow-$theme" "" 228 "$theme" ""
done
shot "reduce-motion" reduce 404 dark ""
