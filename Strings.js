.pragma library

// Every sentence Sands shows, in English and French, under one key. Pure, no
// import: tr(key, lang, ...args) gives the text of `key` in `lang` with %1,
// %2… filled from args, and English when the language or the key is missing
// there. `lang` is "en", "fr" or any locale name ("fr_FR", "fr-CA",
// Qt.locale().name): langOf reads the language out of it, as DMS does
// (Common/I18n.qml takes SessionData.locale, else Qt.locale().name, and keeps
// what comes before "_" or "-"). tests/strings.test.js checks that both
// languages have the same keys and the same placeholders, and no emoji.
//
// A new language is one more table of the same keys in TABLE. The words the
// parser reads are elsewhere (lang/*.js): this file is only what is shown.

var TABLE = {
    en: {
        // A timer or an alarm without a name of its own
        "name.timer": "Timer",
        "name.alarm": "Alarm",

        // Preview.js: the launcher lines before Enter
        "preview.duration": "%1 · %2 · ends %3",
        "preview.at": "%1 · at %2",
        "preview.tomorrow": "%1 tomorrow",
        "preview.ringsAt": "Rings at %1",
        "preview.ringsIn": "Rings in %1",
        "preview.capped": "at most %1 at once",

        // TimeParser.js: the hint of an empty result
        "hint.unknownWord": "Unknown word « %1 »",

        // Commands.js: %1 the timer, %2 the amount, %3 the new end, %4 the new name
        "command.adjust": "%2 to %1 (ends %3)",
        "command.pause": "Pause %1",
        "command.resume": "Resume %1 (ends %3)",
        "command.snooze": "Snooze %1 %2 (rings %3)",
        "command.rename": "%1 → %4",

        // KnownDurations.js: %1 the name, %2 the duration
        "known.usual": "%1 — %2 (usual time)",

        // Guide.js: the notes when something cannot be done
        "guide.notStarted": "Not started",
        "guide.rangeHint": "A timer lasts between 1 second and 100 hours",
        "guide.fullHint": "At most %1 timers at once: cancel one first",
        "guide.partialTitle": "Started %1 of %2",
        "guide.partialHint": "At most %1 timers run at once",
        "guide.silentTitle": "The alarm made no sound",
        "guide.silentHint": "Pick another sound in the settings",
        "guide.previewTitle": "Could not play this sound",
        "guide.previewHint": "Check the file path, or pick another sound",
        "guide.toast": "Sands: %1. %2",

        // components/daemon/Retired.js
        "retired.toast": "End actions removed",

        // components/daemon/Notifications.js
        "notify.title": "%1 - done",
        "notify.at": "It's %1",
        "notify.elapsed": "%1 elapsed",
        "notify.stop": "Stop",
        "notify.snooze": "+%1 min",

        // components/daemon/IpcReplies.js (%n ending in a link: the guide URL)
        "ipc.tooLong": "Not started: keep it under %1 characters, like \"12 min pasta\": %2#syntax",
        "ipc.notUnderstood": "Not started. Try \"12 min pasta\": %1#syntax",
        "ipc.refused": "Not started: %1. %2#%3",
        "ipc.started": "Started: %1%2 - %3%4",
        "ipc.startedAt": "at %1",
        "ipc.partialCount": "%1 of %2 × ",
        "ipc.limit": " (at most %1 at once: %2#syntax)",
        "ipc.notChanged": "Not changed: taking time off stops at 0:10, and a timer lasts at most 100 hours. %1#syntax",
        "ipc.undone": "Timer restored",
        "ipc.nothingToUndo": "Nothing to undo: a stopped timer can be brought back for 5 s",
        "ipc.noTimer": "No timer",
        "ipc.paused": " (paused)",
        "ipc.done": " (done)",
        "ipc.collecting": "Collecting (about 2 s): run the same command again. %1#report-a-problem",
        "ipc.stillCollecting": "Still collecting, ask again in a moment. %1#report-a-problem"
    },
    fr: {
        "name.timer": "Minuteur",
        "name.alarm": "Alarme",

        "preview.duration": "%1 · %2 · finit à %3",
        "preview.at": "%1 · à %2",
        "preview.tomorrow": "%1 demain",
        "preview.ringsAt": "Sonne à %1",
        "preview.ringsIn": "Sonne dans %1",
        "preview.capped": "%1 au plus à la fois",

        "hint.unknownWord": "Mot inconnu « %1 »",

        "command.adjust": "%2 à %1 (finit à %3)",
        "command.pause": "Pause %1",
        "command.resume": "Reprendre %1 (finit à %3)",
        "command.snooze": "Snooze %1 %2 (sonne à %3)",
        "command.rename": "%1 → %4",

        "known.usual": "%1 — %2 (durée habituelle)",

        "guide.notStarted": "Pas démarré",
        "guide.rangeHint": "Un minuteur dure entre 1 seconde et 100 heures",
        "guide.fullHint": "%1 minuteurs au plus à la fois : en arrêter un d'abord",
        "guide.partialTitle": "%1 sur %2 démarrés",
        "guide.partialHint": "%1 minuteurs au plus tournent à la fois",
        "guide.silentTitle": "L'alarme n'a fait aucun son",
        "guide.silentHint": "Choisir un autre son dans les réglages",
        "guide.previewTitle": "Impossible de lire ce son",
        "guide.previewHint": "Vérifier le chemin du fichier, ou choisir un autre son",
        "guide.toast": "Sands : %1. %2",

        "retired.toast": "Actions de fin retirées",

        "notify.title": "%1 - terminé",
        "notify.at": "Il est %1",
        "notify.elapsed": "Temps écoulé : %1",
        "notify.stop": "Arrêter",
        "notify.snooze": "+%1 min",

        "ipc.tooLong": "Pas démarré : moins de %1 caractères, comme « 12 min pâtes » : %2#syntax",
        "ipc.notUnderstood": "Pas démarré. Essayer « 12 min pâtes » : %1#syntax",
        "ipc.refused": "Pas démarré : %1. %2#%3",
        "ipc.started": "Démarré : %1%2 - %3%4",
        "ipc.startedAt": "à %1",
        "ipc.partialCount": "%1 sur %2 × ",
        "ipc.limit": " (%1 au plus à la fois : %2#syntax)",
        "ipc.notChanged": "Pas changé : retirer du temps s'arrête à 0:10, et un minuteur dure 100 heures au plus. %1#syntax",
        "ipc.undone": "Minuteur rétabli",
        "ipc.nothingToUndo": "Rien à annuler : un minuteur arrêté peut revenir pendant 5 s",
        "ipc.noTimer": "Aucun minuteur",
        "ipc.paused": " (en pause)",
        "ipc.done": " (terminé)",
        "ipc.collecting": "Collecte (environ 2 s) : relancer la même commande. %1#report-a-problem",
        "ipc.stillCollecting": "Collecte en cours, redemander dans un instant. %1#report-a-problem"
    }
};

var FALLBACK = "en";

// The language of a locale name, one of TABLE's keys: "fr_FR" → "fr",
// "fr-CA" → "fr", "en_GB" → "en"; anything unknown or empty → English
function langOf(locale) {
    var tag = String(locale === undefined || locale === null ? "" : locale).split(/[_\-.@]/)[0].toLowerCase();
    return tag !== "" && Object.prototype.hasOwnProperty.call(TABLE, tag) ? tag : FALLBACK;
}

// `template` with each %1… replaced by values[0]…; a placeholder without a
// value stays as is
function fill(template, values) {
    return String(template).replace(/%(\d)/g, function (all, n) {
        return values[n - 1] === undefined ? all : String(values[n - 1]);
    });
}

// The text of `key` in `lang` (a language or a locale name), filled with the
// arguments after `lang`. English when `lang` lacks the key, the key itself
// when English lacks it too (so a missing string shows, and a test can see it).
function tr(key, lang) {
    var table = TABLE[langOf(lang)];
    var text = Object.prototype.hasOwnProperty.call(table, key) ? table[key]
        : (Object.prototype.hasOwnProperty.call(TABLE[FALLBACK], key) ? TABLE[FALLBACK][key] : key);
    return fill(text, Array.prototype.slice.call(arguments, 2));
}

// Whether `key` exists in English (the reference language)
function has(key) {
    return Object.prototype.hasOwnProperty.call(TABLE[FALLBACK], key);
}
