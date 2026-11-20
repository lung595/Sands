#!/bin/sh
# qmllint over every QML file of the repository, against a baseline: the
# warnings that were already there are listed in scripts/lint-baseline.txt and
# only new ones make it fail. Run from anywhere, takes about two seconds.
#
#   sh scripts/lint.sh            # exit 1 and print the new warnings, if any
#   sh scripts/lint.sh --update   # rewrite the baseline with today's warnings
#   sh scripts/lint.sh [--update] FILE.qml...   # only these files; the
#                                 # baseline entries of the other files stay
#
# The DMS modules (qs.Common, qs.Widgets...) come from the preview stand-ins in
# scripts/preview/imports; the rule levels are in .qmllint.ini. The preview
# scenes and mocks are left out. A baseline entry is "file, rule, message,
# code": no line number, so moving code around does not touch the baseline,
# and the same warning twice in one file counts twice.
# QMLLINT picks the binary, SANDS_LINT_BASELINE another baseline file (tests).
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
baseline=${SANDS_LINT_BASELINE:-$root/scripts/lint-baseline.txt}
update=0
[ "${1:-}" = "--update" ] && { update=1; shift; }

qmllint=${QMLLINT:-}
if [ -z "$qmllint" ]; then
    for q in /usr/lib64/qt6/bin/qmllint /usr/lib/qt6/bin/qmllint qmllint6 qmllint-qt6 qmllint; do
        command -v "$q" >/dev/null 2>&1 && { qmllint=$q; break; }
    done
fi
[ -n "$qmllint" ] || { echo "lint: qmllint (Qt 6) not found, set QMLLINT" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for f in "$@"; do realpath -m "$f"; done >"$work/files"
cd "$root" || exit 2
if [ $# -eq 0 ]; then
    # Tracked and new (not ignored) files, without the ones deleted in the tree
    { git ls-files --cached --others --exclude-standard -- '*.qml' 2>/dev/null ||
        find . -name '*.qml' -not -path './.git/*' | sed 's|^\./||'; } |
        grep -v '^scripts/preview/' | sort -u | while read -r f; do [ -f "$f" ] && echo "$f"; done >"$work/files"
fi
[ -s "$work/files" ] || { echo "lint: no QML file" >&2; exit 2; }

# qmllint's own exit code says nothing useful here (warnings do not change
# it, a syntax error does): the JSON report is what is read.
# shellcheck disable=SC2046
"$qmllint" -I scripts/preview/imports --json "$work/report.json" $(cat "$work/files") >/dev/null 2>&1

python3 - "$work/report.json" "$baseline" "$update" "$root" "$#" "$work/files" <<'PY'
import collections, json, os, re, sys

report, baseline, update, root = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4]
partial = sys.argv[5] != "0"  # files named on the command line
try:
    files = json.load(open(report))["files"]
except Exception as e:
    print("lint: qmllint wrote no report (%s)" % e, file=sys.stderr)
    sys.exit(2)

def clean(s):
    return re.sub(r"\s+", " ", s.replace(root + "/", "")).strip()

found = []  # (key, "file:line:col") ; info level (unused imports) is not counted
for f in files:
    name = clean(f["filename"])
    try:
        text = open(os.path.join(root, f["filename"]), encoding="utf-8").read()
    except OSError:
        text = ""
    for w in f.get("warnings", []):
        if w.get("type") == "info":
            continue
        code = ""
        if "charOffset" in w and w.get("length"):
            code = clean(text[w["charOffset"]:w["charOffset"] + w["length"]])[:60]
        key = "\t".join([name, w.get("id", "?"), clean(w.get("message", "")), code])
        found.append((key, "%s:%s:%s" % (name, w.get("line", "?"), w.get("column", "?"))))

now = collections.Counter(k for k, _ in found)
try:
    old = collections.Counter(l.rstrip("\n") for l in open(baseline)
                              if l.strip() and not l.startswith("#"))
except OSError:
    old = collections.Counter()
# With named files, the entries of every other file are left alone: kept by
# --update, not compared (nor reported gone) by a check.
others = collections.Counter()
if partial:
    linted = {clean(f["filename"]) for f in files}
    linted |= {clean(l.strip()) for l in open(sys.argv[6]) if l.strip()}
    for k, n in old.items():
        if k.split("\t", 1)[0] not in linted:
            others[k] = n
    old -= others

if update:
    keep = now + others
    with open(baseline, "w") as out:
        out.write("# qmllint warnings already there (scripts/lint.sh --update): file, rule, message, code\n")
        for k in sorted(keep.elements()):
            out.write(k + "\n")
    print("lint: baseline written, %d warnings" % sum(keep.values()))
    sys.exit(0)

new = now - old
gone = sum((old - now).values())
if gone:
    print("lint: %d baseline warnings are gone, run scripts/lint.sh --update to drop them" % gone)
if not new:
    print("lint: ok, %d files, %d known warnings, nothing new" % (len(files), sum(now.values())))
    sys.exit(0)
print("lint: %d new warnings" % sum(new.values()))
for key in sorted(new):
    name, rule, message, code = key.split("\t")
    where = ", ".join(w for k, w in found if k == key)
    extra = " (%d new)" % new[key] if new[key] != now[key] else ""
    print("  %s  %s [%s]%s%s" % (where, message, rule, "  `%s`" % code if code else "", extra))
sys.exit(1)
PY
