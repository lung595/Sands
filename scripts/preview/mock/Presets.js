.pragma library

// Made-up stores for the settings previews: the default one, then the ones that
// show every optional row or a long list value.
var list = [
    {},
    // A custom sound file shows the file field
    {"sound": "custom"},
    // A launcher prefix shows its row
    {"noTrigger": false},
    // A long, realistic value in the sound list (the list is a fixed box: a value longer
    // than the page elides, as in DMS, so the test fails on one that does not fit)
    {"sound": "Complete · freedesktop"},
    // Own commands with a long name and command, and the most words a row may hold,
    // the longest allowed (24 characters)
    {
        "personalActions": [
            {"name": "Back up every photo of the family trip", "program": "backup-photos", "args": ["--quick", "--destination=/mnt/archive/photos/2026"]},
            {"name": "Lights", "program": "lights-off", "args": []}
        ],
        "actionWords": {
            "poweroff": ["abcdefghijklmnopqrstuvwx", "bye", "night", "zzz", "dodo", "later", "stop", "end"],
            "personal-0": ["save", "backup"]
        }
    }
];
