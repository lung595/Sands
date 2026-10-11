.pragma library

// The DMS settings host a row sits in: the nearest ancestor that can load and
// save a value. Null until the row is parented (DMS reparents its children).
function find(item) {
    for (let p = item ? item.parent : null; p; p = p.parent) {
        if (typeof p.loadValue === "function" && typeof p.saveValue === "function")
            return p;
    }
    return null;
}

// Reads the saved value into the row, then marks it ready. The read itself is never
// written back: the row saves only once `ready` is set.
function load(row) {
    const host = find(row);
    if (!host)
        return;
    row.value = host.loadValue(row.settingKey, row.defaultValue);
    row.ready = true;
}

// Writes the row's value under its own key, and only after the saved value was read.
function save(row) {
    const host = row.ready ? find(row) : null;
    if (host)
        host.saveValue(row.settingKey, row.value);
}
