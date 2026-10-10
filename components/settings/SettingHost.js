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
