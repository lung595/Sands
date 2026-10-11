.pragma library

// Stroke paths of the rail logos, drawn on a 24 x 24 grid. One per section id
// so the rail does not depend on an icon font and every logo shares one
// stroke weight. Paths of sections not shown yet stay here on purpose: they belong
// with the table in Sections.js and cost nothing until their section is listed.
var PATHS = {
    "timers": "M7 3H17M7 21H17M8 3C8 9 12 10 12 12C12 14 8 15 8 21M16 3C16 9 12 10 12 12C12 14 16 15 16 21",
    "focus": "M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1",
    "appearance": "M12 3C7 3 3 7 3 12s4 9 8 9c1.5 0 2-1 1.5-2-.6-1.3.2-2.5 1.7-2.5H18a3 3 0 0 0 3-3C21 7 17 3 12 3zM8 11.5v.01M12 8v.01M16 11.5v.01",
    "effects": "M13 2L5 14H11L10 22L19 9H13z",
    "bar": "M4 15H20V19H4zM8 8H16",
    "desktop": "M3 5H21V16H3zM9 20H15M12 16V20",
    "alerts": "M6 17V11a6 6 0 0 1 12 0v6l2 2H4zM10 21H14",
    "advanced": "M4 7H20M4 17H20M9 4V10M15 14V20",
    "help": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM9.5 9.5a2.5 2.5 0 1 1 3.5 2.3C12.4 12.1 12 12.6 12 13.5M12 17v.01"
};

function pathFor(id) {
    return PATHS[id] || "";
}
