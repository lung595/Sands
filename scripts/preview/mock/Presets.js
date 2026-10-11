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
    {"sound": "Complete · freedesktop"}
];
