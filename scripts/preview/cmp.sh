#!/bin/sh
# Compares a render (shots.sh output) with the committed reference pictures.
#   scripts/preview/cmp.sh <new dir>            exits 1 on any difference
#   scripts/preview/cmp.sh --update <new dir>   makes <new dir> the reference
# manifest.txt lists "<scene> <tolerance in px> <sha256 of the reference>".
# Tolerance 0 means byte-identical (a hash check, then `cmp`). The scenes
# with the sand and the float moving carry a few pixels of rendering noise
# between two runs of the same code (measured 0 to 7 px), so they get a
# small tolerance instead of 0. Their "-reduce" twins are at 0, except
# panel-4-reduce and panel-ringing-reduce, which still showed 3 and 5 px in
# some of 6 runs (an eased element of the panel), so they get 10.
cd "$(dirname "$0")" || exit 1
update=0
[ "$1" = "--update" ] && { update=1; shift; }
new=$(realpath "${1:?usage: cmp.sh [--update] <new dir>}")
if [ $update = 1 ]; then
  mkdir -p reference
  : > manifest.new
  while read -r scene tol _; do
    cp "$new/$scene.png" "reference/$scene.png" || exit 1
    echo "$scene $tol $(sha256sum "reference/$scene.png" | cut -d' ' -f1)" >> manifest.new
  done < manifest.txt
  mv manifest.new manifest.txt
  echo "reference updated"
  exit 0
fi
bad=0
while read -r scene tol sum; do
  ref="reference/$scene.png"
  [ -f "$new/$scene.png" ] || { echo "MISSING $scene"; bad=1; continue; }
  [ "$(sha256sum "$ref" | cut -d' ' -f1)" = "$sum" ] || { echo "REFERENCE ALTERED $scene (hash differs from manifest)"; bad=1; continue; }
  cmp -s "$ref" "$new/$scene.png" && continue
  diff=$(magick compare -metric AE "$ref" "$new/$scene.png" null: 2>&1 | cut -d' ' -f1 | cut -d. -f1)
  case "$diff" in *[!0-9]*|"") echo "DIFF $scene: pictures cannot be compared (size?)"; bad=1; continue ;; esac
  [ "$diff" -le "$tol" ] || { echo "DIFF $scene: $diff px (tolerance $tol)"; bad=1; }
done < manifest.txt
[ $bad = 0 ] && echo "all scenes match the reference"
exit $bad
