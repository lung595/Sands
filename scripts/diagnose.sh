#!/bin/sh
# Prints the anonymous Sands diagnostic report, to read and paste in a GitHub
# issue (docs/DEBUGGING.md). It asks the running plugin for its report, and
# adds the latest Quickshell crash folder if there is one. Nothing is sent
# anywhere, nothing is written to disk, no network, no argument is read.
#
#   sh scripts/diagnose.sh
#
# Everything printed goes through reduce() first: the home folder, the login
# name, the host name, addresses and long secrets-looking runs are replaced.
set -u

# A line is cut at this many characters, as Redact.js does (MAX_LINE)
max_line=240
# The plugin needs about this many seconds to build its report
collect_wait=2
# Journal lines read, and how many of Sands' own are kept (as Gather.js and Report.js)
journal_read=300
journal_kept=50
# Lines read at the start of each text file of a crash folder
crash_lines=40

# Replaces every occurrence of a fixed text (not a pattern: a "." in a host
# name or a "/" in a path must mean itself). The text travels in the
# environment, so no program is ever built from it. Under 3 characters it
# would hide too much: it is left alone, or with "word" as third argument
# (a login, a host name) replaced only where it stands as a whole word.
replace_fixed() {
    FROM="$1" TO="$2" WORD="${3:-}" awk '
        BEGIN { from = ENVIRON["FROM"]; to = ENVIRON["TO"]; n = length(from); short = n < 3 }
        n == 0 || (short && ENVIRON["WORD"] == "") { print; next }
        {
            out = ""
            last = ""
            while ((i = index($0, from)) > 0) {
                before = i > 1 ? substr($0, i - 1, 1) : last
                whole = before !~ /[A-Za-z0-9_-]/ && substr($0, i + n, 1) !~ /[A-Za-z0-9_-]/
                out = out substr($0, 1, i - 1) (short && !whole ? from : to)
                $0 = substr($0, i + n)
                last = substr(from, n, 1)
            }
            print out $0
        }'
}

# Picture extensions whose scale mark ("icon@2x.png") is not an address. Same
# list as the e-mail rule of diagnostics/Redact.js: change both together.
pictures='png|jpe?g|webp|svg|gif|avif|bmp|ico'

# The reduction, as a filter. The plugin's own report is already clean; this
# is the second wall for what only the shell or the journal knows. The rules
# are those of diagnostics/Redact.js, in the same order: change both together.
# sed has no lookahead, so the character after an IPv6 address is captured and
# given back, and a picture's scale mark is set aside under a placeholder while
# the e-mail rule runs. The host name is hidden in its full and its short form.
reduce() {
    user=$(id -un 2>/dev/null || echo "")
    host=$(hostname 2>/dev/null || echo "")
    [ -n "$host" ] || host=$(uname -n 2>/dev/null || echo "")
    replace_fixed "${HOME:-}" "~" |
        sed -E \
            -e 's#\b(token|secret|passw(or)?d|passwd|pwd|auth[-_]?key|api[-_]?key|credential)s?([[:space:]]*[=:][[:space:]]*)("[^"]*"|'\''[^'\'']*'\''|[^[:space:]]+)#\1\3<secret>#gI' \
            -e 's#\bBearer[[:space:]]+[^[:space:]]+#Bearer <secret>#gI' \
            -e 's#\b(tskey|ghp|gho|ghu|ghs|ghr|github_pat|glpat|xox[abprs]|sk|pk|AKIA)[-_][A-Za-z0-9_-]{8,}#<secret>#g' \
            -e 's#\b[0-9A-Fa-f]{32,}\b#<secret>#g' \
            -e 's#[A-Za-z0-9+_-]{40,}={0,2}#<secret>#g' \
            -e 's#\b([a-z][a-z0-9+.-]*://)[^[:space:]/@]+@#\1<secret>@#gI' \
            -e "s#@([0-9]+x\.($pictures))([^A-Za-z0-9.-]|\$)#<scale-mark>\1\3#gI" \
            -e 's#[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}#<email>#g' \
            -e 's#<scale-mark>#@#g' \
            -e 's#([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}#<mac>#g' \
            -e 's#([0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}#<mac>#g' \
            -e 's#(^|[^0-9A-Za-z:])([0-9a-f]{1,4}:){7}[0-9a-f]{1,4}([^0-9A-Za-z:]|$)#\1<ip>\3#gI' \
            -e 's#(^|[^0-9A-Za-z:])([0-9a-f]{1,4}:){1,7}:([0-9a-f]{1,4}(:[0-9a-f]{1,4}){0,6})?(%[0-9A-Za-z]+)?([^0-9A-Za-z:]|$)#\1<ip>\6#gI' \
            -e 's#(^|[^0-9A-Za-z:])::[0-9a-f]{1,4}(:[0-9a-f]{1,4}){0,6}([^0-9A-Za-z:]|$)#\1<ip>\3#gI' \
            -e 's#\b([0-9]{1,3}\.){3}[0-9]{1,3}\b#<ip>#g' \
            -e 's#\b[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.(local|lan|home|internal|localdomain|home\.arpa|ts\.net)\b#<host>#gI' \
            -e 's#(/var)?/(home)/[^/[:space:]:'\''"]+#~#g' \
            -e 's#/Users/[^/[:space:]:'\''"]+#~#g' \
            -e 's#/root\b#~#g' \
            -e 's#(/(run/)?media/)[^/[:space:]:'\''"]+#\1<user>#g' \
            -e 's#/run/user/[0-9]+#/run/user/<uid>#g' |
        replace_fixed "$user" "user" word |
        replace_fixed "$host" "host" word |
        replace_fixed "${host%%.*}" "host" word
}

# What a file nobody wrote for a report may hold: control characters go (tab
# kept) and a line is cut at max_line characters
plain() {
    tr -d '\000-\010\013-\037\177' | cut -c1-"$max_line"
}

# The plugin's own report: the first call starts it, the second hands it over
# once it is ready (a CPU measure included), with one more wait if it is not
report_from_shell() {
    command -v dms >/dev/null 2>&1 || return 1
    dms ipc call smartTimer diagnostics >/dev/null 2>&1 || return 1
    sleep "$collect_wait"
    out=$(dms ipc call smartTimer diagnostics 2>/dev/null) || return 1
    case $out in
    "Still collecting"*)
        sleep "$collect_wait"
        out=$(dms ipc call smartTimer diagnostics 2>/dev/null) || return 1
        ;;
    esac
    case $out in
    "Sands diagnostic report"*)
        printf '%s\n' "$out"
        ;;
    *) return 1 ;;
    esac
}

# Without the shell or the plugin: versions and the lines Sands left in the
# DMS journal, which is all that survives a restart. "-o cat" asks journalctl
# for the message alone: no date, no machine name, no program, whatever the
# language of the session. Should a line still start with them, the two
# patterns of diagnostics/Report.js (SYSLOG_PREFIX, LOCAL_PREFIX) cut them.
report_without_shell() {
    echo "Sands diagnostic report (anonymous, from the command line: the plugin did not answer)"
    echo "Created      : $(date -u '+%Y-%m-%d %H:%M:%S') UTC"
    echo "DMS          : $(dms version 2>/dev/null | head -n 1)"
    echo "Quickshell   : $(quickshell --version 2>/dev/null | head -n 1)"
    echo "Compositor   : $(niri --version 2>/dev/null | head -n 1)"
    echo "Distribution : $(sed -n 's/^PRETTY_NAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc/os-release 2>/dev/null | head -n 1)"
    echo "Journal lines (last $journal_kept at most):"
    lines=$(journalctl --user -u dms -n "$journal_read" --no-pager -o cat 2>/dev/null | grep -F '[sands]' | tail -n "$journal_kept")
    if [ -n "$lines" ]; then
        printf '%s\n' "$lines" | plain |
            sed -E \
                -e 's#^[A-Za-z]{3} [ 0-9][0-9] [0-9]{2}:[0-9]{2}:[0-9]{2} [^ ]+ [^ ]+: ##' \
                -e 's#^[^][]{0,40}[0-9]{2}:[0-9]{2}:[0-9]{2}[^ ]{0,12}( [A-Z]{2,5})? [^ ]+ [^ ]+\[[0-9]+\]: ##' \
                -e 's/^/  /'
    else
        echo "  none"
    fi
}

# The latest crash folder Quickshell kept: its file names and the start of
# its text description, not the memory dump
crash() {
    dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/crashes"
    [ -d "$dir" ] || return 0
    latest=$(ls -1t "$dir" 2>/dev/null | head -n 1)
    [ -n "$latest" ] || return 0
    echo "Latest Quickshell crash folder (file names and sizes, then the start of its text):"
    ls -l "$dir/$latest" 2>/dev/null | tail -n +2 | awk '{print "  " $5 "  " $9}' | plain
    for f in "$dir/$latest"/*.txt "$dir/$latest/metadata"; do
        [ -f "$f" ] || continue
        echo "  --- $(basename "$f" | plain)"
        head -n "$crash_lines" "$f" | plain | sed 's/^/  /'
    done
}

{
    report_from_shell || report_without_shell
    crash
} | reduce
