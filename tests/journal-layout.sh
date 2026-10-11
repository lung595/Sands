#!/bin/sh
# Offscreen layout test of the time journal: every state in both looks, at the
# narrow and the wide width, light and dark. journal.qml exits 1 and prints
# OVERLAP when a text leaves the panel or runs into another one.
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d)
cd "$here/../scripts/preview" || exit 1
export TZ=UTC QT_QPA_PLATFORM=offscreen
for look in strata threads; do
  for state in empty one five long many; do
    for extra in "" "narrow" "narrow light reduce"; do
      # shellcheck disable=SC2086
      if ! log=$(timeout 40 qml-qt6 -I imports journal.qml -- "$state" "$look" "$out/j.png" $extra 2>&1); then
        echo "FAIL journal $state $look $extra"; echo "$log" | grep -E 'OVERLAP|rror' | head -5
        rm -rf "$out"; exit 1
      fi
    done
  done
done
rm -rf "$out"
echo "ok journal layout"
