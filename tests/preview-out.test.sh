#!/bin/sh
# Test of where the offscreen renders go: scripts/preview/shots.sh writes to
# the repository's out/ by default, from any folder, or to the folder given;
# out/ is ignored by git and holds no tracked file. qml-qt6 is a stand-in on
# PATH that only writes the picture it is asked for. Run: sh tests/preview-out.test.sh
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work=$(mktemp -d)
scene="zz-preview-out-test-$$"
trap 'rm -rf "$work"; rm -f "$root/out/$scene.png" "$root/out/$scene.log"' EXIT
fails=0
check() {
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got $2, want $3)"; fails=$((fails + 1)); fi
}

mkdir "$work/bin"
cat > "$work/bin/qml-qt6" <<'EOF'
#!/bin/sh
# qml-qt6 -I imports shot.qml -- <scene> <out.png>
printf 'png' > "$6"
EOF
chmod +x "$work/bin/qml-qt6"

(cd "$work" && PATH="$work/bin:$PATH" sh "$root/scripts/preview/shots.sh" "" "$scene" >/dev/null 2>&1)
check "by default the picture lands in the repository's out/, run from another folder" "$(cat "$root/out/$scene.png" 2>/dev/null)" png
check "and nowhere in the current folder" "$(ls "$work" | grep -c '^out$')" 0

PATH="$work/bin:$PATH" sh "$root/scripts/preview/shots.sh" "$work/given" "$scene" >/dev/null 2>&1
check "a folder given gets the picture" "$(cat "$work/given/$scene.png" 2>/dev/null)" png

git -C "$root" check-ignore -q "out/$scene.png"
check "out/ is ignored by git" "$?" 0
check "out/ holds no tracked file" "$(git -C "$root" ls-files out | wc -l)" 0

[ "$fails" -eq 0 ] && echo "all preview output tests passed" || { echo "$fails preview output tests failed"; exit 1; }
