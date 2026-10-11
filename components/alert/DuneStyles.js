.pragma library

// The three sand styles of the "Rising dune" alert. The saved value is the
// key; the label and the help line are what the settings row shows.
var DEFAULT = "grains";

var STYLES = [
    { value: "grains", label: "Last grains", help: "A thread of sand falls and the dune heaps up from the centre." },
    { value: "wind", label: "Wind dune", help: "The sand front crosses the screen with a crest and flying grains." },
    { value: "wave", label: "Flat wave", help: "A smooth wave of sand that springs up and bounces." }
];

// A saved value that is missing, mistyped or from a later version falls back
// to the default instead of drawing nothing (value 10: never blocked).
function resolve(value) {
    for (let i = 0; i < STYLES.length; i++)
        if (STYLES[i].value === value)
            return value;
    return DEFAULT;
}

function entryOf(value) {
    const key = resolve(value);
    return STYLES.find(s => s.value === key);
}

function labelOf(value) {
    return entryOf(value).label;
}

function helpOf(value) {
    return entryOf(value).help;
}
