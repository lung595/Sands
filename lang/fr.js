.pragma library

// Mots français du parseur (TimeParser.js) et des commandes du launcher
// (Commands.js). Same shape as lang/en.js, whose header explains the format:
// fragments of regular expressions over the normalized text (lowercase, no
// accents, straight apostrophes).

var NAME = "fr";

var KEYWORDS = ["timer", "minuteur", "minuterie", "compte a rebours", "chrono", "alarme", "rappel", "reveil"];

var NUMBERS = {
    "zero": 0, "un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4,
    "cinq": 5, "six": 6, "sept": 7, "huit": 8, "neuf": 9, "dix": 10,
    "onze": 11, "douze": 12, "treize": 13, "quatorze": 14, "quinze": 15,
    "seize": 16, "vingt": 20, "trente": 30, "quarante": 40, "cinquante": 50,
    "soixante": 60
};
var ARTICLES = [];
// « vingt et un », « vingt-et-une »
var NUMBER_LINKS = ["et"];
// « dix-sept », « dix huit »
var NUMBER_EXTRA = ["dix[- ](?:sept|huit|neuf)"];

var HOURS = ["heures?", "h"];
var MINUTES = ["minutes?", "mins?", "mn", "m"];
var SECONDS = ["secondes?", "secs?", "s"];
var TYPO_UNITS = [["minute", "min"], ["minutes", "min"], ["heure", "h"], ["heures", "h"],
                  ["seconde", "s"], ["secondes", "s"]];
var TYPO_ABBREVIATIONS = [["min", "min"], ["sec", "s"]];
// « 2 hors » is « 2 outside », not two hours
var TYPO_STOPWORDS = ["hors"];

// « 2 heures et demie », « 1 h et quart »
var AND = ["et"];
var HALF = ["demie?"];
var QUARTER = ["quart"];
// « une demi-heure », « trois quarts d'heure »
var HALF_HOUR = ["demi[- ]?heure"];
var QUARTER_HOUR = ["quarts?\\s+d'?\\s*heure"];
// « 1/4 d'heure », « 1/2 heure », « 3/4 h »
var FRACTION_HOUR = ["d'?\\s*heures?", "heures?", "h"];

var CLOCK_PREPOSITIONS = ["a", "vers", "jusqu'a"];
var CLOCK_HOURS = ["heures?", "h"];
var NOON = ["midi"];
var MIDNIGHT = ["minuit"];
var PERIOD_AM = ["du\\s+matin"];
var PERIOD_PM = ["du\\s+soir", "de\\s+l'apres[- ]?midi"];
var DAY_WORDS = {
    "demain": { shift: 1 },
    "ce soir": { shift: 0, pm: true, night: true },
    "cet apres-midi": { shift: 0, pm: true },
    "ce matin": { shift: 0 },
    "aujourd'hui": { shift: 0 }
};

// « dans 1 h à peu près », « environ 20 min »
var APPROX = ["a peu pres", "environ", "approximativement", "a peu de choses pres"];

var CONTEXT = [
    "rappelle[sz]?[- ]moi",
    "reveille[sz]?[- ]moi",
    "(?:mets?|lance|lancer|demarre|regle|programme|cree)(?:-moi)?\\s+(?:un|une|le|la)?\\s*(?:timer|minuteur|minuterie|alarme|rappel|compte a rebours|chrono|reveil)"
];
var CONTEXT_LINKS = ["de", "pour", "que"];
var CONTEXT_ELISIONS = ["d'", "qu'"];
var LABEL_LINKS = ["que"];
var LABEL_ELISIONS = ["qu'"];
var LABEL_HEAD = ["pour", "de", "dans", "et", "a", "à", "le", "la", "les"];
var LABEL_TAIL = ["pour", "de", "dans", "et", "a", "à"];
var LABEL_ELISIONS_EDGE = ["d'"];

var COMMANDS = {
    pause: ["pause", "mets? en pause", "suspends?"],
    resume: ["reprendre", "reprends", "continuer?"],
    snooze: ["snooze", "repousse[rz]?"],
    rename: ["renomme[rz]?", "rebaptise[rz]?"],
    renameTo: ["en"]
};

var PREVIEW = {
    adjust: "%2 à %1 (finit à %3)",
    pause: "Pause %1",
    resume: "Reprendre %1 (finit à %3)",
    snooze: "Snooze %1 %2 (sonne à %3)",
    rename: "%1 → %4",
    timer: "Minuteur",
    alarm: "Alarme"
};
