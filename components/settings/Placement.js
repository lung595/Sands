.pragma library

// Is the Sands widget in a bar? Read (never written) from SettingsData.barConfigs.
// Enabling the plugin is not enough to see a timer: the pill and the panel only
// exist from a widget placed in a bar, so the settings open on "Getting started"
// while it is in none. A bar's sections are every key ending in "Widgets" (left,
// center, right today); an entry is a bare id or an object with `id`, and one
// switched off (enabled: false), or on a disabled bar, does not count.

function _list(x) {
    return x && typeof x.length === "number" && typeof x !== "string" ? Array.from(x) : [];
}

function _on(entry, id) {
    if (typeof entry === "string")
        return entry === id;
    return !!entry && entry.enabled !== false && entry.id === id;
}

function inBar(bars, pluginId) {
    return _list(bars).some(b => !!b && b.enabled !== false
        && Object.keys(b).some(k => /Widgets$/.test(k) && _list(b[k]).some(w => _on(w, pluginId))));
}
