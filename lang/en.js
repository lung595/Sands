.pragma library

// English words of the natural-language parser (TimeParser.js) and of the
// launcher commands (Commands.js). Every entry is a regular-expression
// fragment over the normalized text: lowercase, no accents, straight
// apostrophes (see TimeParser.normalize). The parser builds its regexes from
// the union of every pack, so a French and an English word can sit in the
// same sentence. A new language is one more file of the same shape, listed
// in TimeParser.PACKS (tests/parser.test.js checks the shape).

var NAME = "en";

// A word that asks for a timer: « timer 5 »
var KEYWORDS = ["timer", "countdown", "alarm", "reminder"];

// Spelled-out numbers. ARTICLES count as one but never in a compound
// (« twenty a » is nothing); NUMBER_LINKS join tens and units (none in
// English: « twenty-five », « twenty five »); NUMBER_EXTRA are compounds the
// tens rule does not cover.
var NUMBERS = {
    "zero": 0, "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4,
    "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
    "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
    "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60
};
var ARTICLES = ["a", "an"];
var NUMBER_LINKS = [];
var NUMBER_EXTRA = [];

// Units. TYPO_UNITS are the words a one-letter typo is matched against
// (« minuts », « hurs »), with the short unit they stand for.
var HOURS = ["hours?", "hrs?", "h"];
var MINUTES = ["minutes?", "mins?", "m"];
var SECONDS = ["seconds?", "secs?", "s"];
var TYPO_UNITS = [["minute", "min"], ["minutes", "min"], ["hour", "h"], ["hours", "h"],
                  ["second", "s"], ["seconds", "s"]];
// Three letters: only two swapped letters are fixed (« mni », « esc »)
var TYPO_ABBREVIATIONS = [["min", "min"], ["sec", "s"]];
// Real words one letter off a unit, kept as words
var TYPO_STOPWORDS = [];

// « 2 hours and a half », « 1 hour and a quarter »
var AND = ["and"];
var HALF = ["a half", "half"];
var QUARTER = ["a quarter", "quarter"];
// Whole phrases: « half an hour », « three quarters of an hour »
var HALF_HOUR = ["half[- ](?:an[- ])?hour"];
var QUARTER_HOUR = ["quarters?(?:\\s+of)?(?:\\s+an)?[- ]hour"];
// After a fraction: « 3/4 of an hour », « 1/2 h »
var FRACTION_HOUR = ["(?:of\\s+)?(?:an?\\s+)?hours?", "h"];

// Clock times
var CLOCK_PREPOSITIONS = ["at", "until", "@"];
// The unit that makes a number an hour of the day: « at 7h »
var CLOCK_HOURS = ["h"];
var NOON = ["noon"];
var MIDNIGHT = ["midnight"];
var PERIOD_AM = ["am", "a\\.m\\.", "in\\s+the\\s+morning"];
var PERIOD_PM = ["pm", "p\\.m\\.", "in\\s+the\\s+(?:evening|afternoon)"];
// shift: days added; pm: 1–11 read as afternoon or evening; night: 12 is midnight
var DAY_WORDS = {
    "tomorrow": { shift: 1 },
    "tonight": { shift: 0, pm: true, night: true },
    "this evening": { shift: 0, pm: true, night: true },
    "this afternoon": { shift: 0, pm: true },
    "this morning": { shift: 0 },
    "today": { shift: 0 }
};

// « about 20 min », « 1 h or so »: dropped when they touch the time
var APPROX = ["about", "around", "roughly", "approximately", "or so", "-?ish"];

// Verbs that only introduce the request, never part of the label
var CONTEXT = [
    "remind me",
    "wake(?:\\s+me)?(?:\\s+up)?",
    "(?:set|start|create|add|put)\\s+(?:me\\s+)?(?:an?\\s+|the\\s+|my\\s+)?(?:timer|alarm|reminder|countdown)"
];
// The word that may follow them: « remind me to … »
var CONTEXT_LINKS = ["for", "to", "of", "about", "that"];
var CONTEXT_ELISIONS = [];
// Left at the start of the label when the time came first: « remind me in 20 min to … »
var LABEL_LINKS = ["to", "that", "about"];
var LABEL_ELISIONS = [];
// Small words trimmed from the ends of a label: « pasta for 12 min »
var LABEL_HEAD = ["for", "in", "and", "a", "at", "the"];
var LABEL_TAIL = ["for", "in", "and", "a", "at"];
var LABEL_ELISIONS_EDGE = [];

// Launcher commands (Commands.js)
var COMMANDS = {
    pause: ["pause", "hold"],
    resume: ["resume", "unpause", "continue"],
    snooze: ["snooze"],
    rename: ["rename"],
    renameTo: ["to", "as"]
};

// What the launcher shows before Enter. %1 name, %2 amount, %3 clock time,
// %4 new name.
var PREVIEW = {
    adjust: "%2 to %1 (ends %3)",
    pause: "Pause %1",
    resume: "Resume %1 (ends %3)",
    snooze: "Snooze %1 %2 (rings %3)",
    rename: "%1 → %4",
    timer: "Timer",
    alarm: "Alarm"
};
