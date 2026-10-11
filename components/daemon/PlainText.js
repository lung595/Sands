.pragma library

// Text shown to the user never holds an em or en dash (house rule). A label
// the user typed may, so it is replaced when displayed; the stored label is
// never touched.
function plain(text) {
    return String(text).replace(/\s*(?:[\u2013\u2014]\s*)+/g, " - ");
}
