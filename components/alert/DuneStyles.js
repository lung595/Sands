.pragma library

// The three sand styles of the "Rising dune" alert. The saved value is the
// key; the label and the help line are what the settings row shows.
var DEFAULT = "grains";

var STYLES = [
    { value: "grains", label: "Last grains", help: "A thread of sand falls and the dune heaps up from the centre." },
    { value: "wind", label: "Wind dune", help: "The sand front crosses the screen with a crest and flying grains." },
    { value: "wave", label: "Flat wave", help: "A smooth wave of sand that springs up and bounces." }
];

// One scene file per style that can be drawn today. A style without an entry
// is known (its saved value is kept) but shows the default until its scene
// lands: the settings row greys it instead of promising it.
var SCENES = {
    "grains": "GrainsScene.qml"
};

function isDrawn(value) {
    return Object.prototype.hasOwnProperty.call(SCENES, value);
}

// The style really drawn for a saved value
function drawnOf(value) {
    const key = resolve(value);
    return isDrawn(key) ? key : DEFAULT;
}

// The cards of the settings row: every style, the ones without a scene greyed
function choices() {
    return STYLES.map(s => ({
        "label": s.label,
        "value": s.value,
        "help": s.help,
        "enabled": isDrawn(s.value),
        "reason": "Not available yet"
    }));
}

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
