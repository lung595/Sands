.pragma library

// What the controls drawn by hand share: the keys that press them, their
// smallest size, their fades and how long a passing message stays.

// A message that goes away alone, and the "Copied" state, last this long
var PASSING_MS = 4000;
// One-shot fades: in, then out
var FADE_IN_MS = 150;
var FADE_OUT_MS = 100;
// The smallest side of a control that is pressed
var TARGET = 44;

// Enter, Return and Space press the focused control, as on a real button
function activates(key) {
    return key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space;
}

// For Keys.onPressed: runs `action` and takes the key when it is one of them
function onKey(event, action) {
    if (!activates(event.key))
        return;
    action();
    event.accepted = true;
}
