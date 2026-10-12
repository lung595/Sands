.pragma library

// What the "Copy report" row says in each state (design: docs/design/copy-report.md).
// Pure, so a test pins every word. The row only draws this.

// Opened on click or key press only; never carries the report (value 5, D450)
var GITHUB_URL = "https://github.com/lung595/Sands/issues/new/choose";

var TITLE = "Anonymous report";
var HELP = "Versions, states and error codes only. It stays on this PC until you paste it.";
var HELP_COPIED = "Report copied. Read it, then paste it in a GitHub issue.";
// Only the fallback (dms clipboard copy) worked: the text is in the history too
var HELP_IN_HISTORY = "Report copied, and kept in the DMS clipboard history: delete it there once pasted.";
// The GitHub mark: what a screen reader says, and the label shown when it is
// focused or pointed at
var MARK_NAME = "Open a new issue for Sands on GitHub";
var MARK_LABEL = "Open an issue on GitHub";

// The guided message when no clipboard tool worked (value 10); it names the
// command that always works and links the guide section.
var NO_TOOL = {
    "title": "The report could not be copied",
    "hint": "Install wl-clipboard, or run dms ipc call smartTimer diagnostics in a terminal.",
    "anchor": "report-a-problem",
    "link": "Open the guide: Report a problem"
};

// phase: "idle", "collecting" (building or copying), "copied" or "none";
// inHistory: the copy went through the tool that cannot keep it out of the
// clipboard history, which the row must say
function view(phase, inHistory) {
    var copied = phase === "copied";
    return {
        "state": phase === "collecting" || copied || phase === "none" ? phase : "rest",
        "button": phase === "collecting" ? "Collecting…" : (copied ? "Copied" : "Copy report"),
        "help": copied ? (inHistory === true ? HELP_IN_HISTORY : HELP_COPIED) : HELP,
        "note": phase === "none" ? NO_TOOL : null,
        "markActive": copied
    };
}

// One phase out of the service (busy) and the clipboard result
function phaseOf(busy, result) {
    if (busy || result === "copying")
        return "collecting";
    return result === "copied" || result === "none" ? result : "idle";
}
