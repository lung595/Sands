.pragma library

// Stroke paths of the rail logos, drawn on a 16 x 16 grid, the set of the approved settings page. One per section id
// so the rail does not depend on an icon font and every logo shares one
// stroke weight. Paths of sections not shown yet stay here on purpose: they belong
// with the table in Sections.js and cost nothing until their section is listed.
var PATHS = {
    "timers": "M4 2.5h8M4 13.5h8M5 2.5c0 3 2.6 3.6 3 5.5c.4-1.9 3-2.5 3-5.5M5 13.5c0-3 2.6-3.6 3-5.5c.4 1.9 3 2.5 3 5.5",
    "focus": "M1.5 12.5l3-5 3 5zM8.5 12.5l3-5 3 5zM4.5 4h.01M8 3h.01M11.5 4h.01",
    "appearance": "M8 2.5a5.5 5.5 0 1 0 0 11a5.5 5.5 0 0 0 0-11zM3.5 10.5c2-2.6 4-2.6 5.5-.5s2.5 1 3.5 0",
    "effects": "M2.5 5.5h10v6h-10zM14 7.5v2M4.5 10l5-3",
    "bar": "M1.5 4h13M4 8.5h8a2 2 0 0 1 0 4h-8a2 2 0 0 1 0-4zM6 10.5h.01",
    "desktop": "M2.5 3h11v8h-11zM6 13.5h4M5 9c1.5-2.6 4.5-2.6 6 0",
    "alerts": "M3 11.5c0-6.5 10-6.5 10 0zM8 3.5v2.5M8 14h.01",
    "advanced": "M2.5 4.5h11l-2.5 4.5h-6zM6 12h.01M8 13.5h.01M10 12h.01",
    "help": "M6 6a2 2 0 1 1 3.1 1.7c-.8.5-1.1 1-1.1 1.8M8 12.5h.01M8 1.5a6.5 6.5 0 1 0 0 13a6.5 6.5 0 0 0 0-13z"
};

function pathFor(id) {
    return PATHS[id] || "";
}
