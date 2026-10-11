#!/bin/sh
# Builds the single before/after page of the settings rows: every width, store and
# palette, rendered offscreen from made-up data. "Before" is the settings page of the
# given commit, laid out with the same stand-ins. Usage: before-after.sh <before-commit> <out.html>
set -eu
before=$1
out=$2
root=$(git rev-parse --show-toplevel)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A copy of the working tree whose settings page is the old one
mkdir "$work/before" "$work/after"
git -C "$root" ls-files -z --cached --others --exclude-standard | (cd "$root" && xargs -0 cp --parents -t "$work/after")
cp -r "$work/after/." "$work/before/"
git -C "$root" show "$before:TimerSettings.qml" > "$work/before/TimerSettings.qml"

for side in before after; do
    for theme in dark light; do
        for w in 228 404; do
            for p in 0 1 2 3; do
                (cd "$work/$side/scripts/preview" && QT_QPA_PLATFORM=offscreen timeout 60 \
                    qml-qt6 -I imports settings-shot.qml -- "$w" "$p" "$theme" "$work/$side-$theme-$w-$p.png" 2>/dev/null)
            done
        done
    done
done
python3 -I "$root/scripts/preview/before-after.py" "$work" "$out"
