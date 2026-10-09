// Sound.js tests — run with: gjs tests/sound.test.js (from the plugin root)
// Which file the alarm plays, how loud, and the player command.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const S = load("components/daemon/Sound.js");

// Sound setting → file to play
const DIR = "/p/sounds/";
const HG = DIR + "hourglass.ogg";
const OLD = "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";
eq(S.RINGS.map(r => r.value), ["default", "silt-chime"], "Hourglass is listed first, then Silt Chime");
eq(S.RINGS.map(r => r.label), ["Hourglass", "Silt Chime"], "ring labels");
eq(S.soundFile("", "", "/h", DIR), HG, "empty choice plays Hourglass");
eq(S.soundFile("default", "", "/h", DIR), HG, "'default' plays Hourglass");
eq(S.soundFile(undefined, "", "/h", DIR), HG, "no setting plays Hourglass");
eq(S.soundFile("Alarm clock (default)", "", "/h", DIR), HG, "the label DMS saved by mistake plays the default (P126)");
eq(S.soundFile("silt-chime", "", "/h", DIR), DIR + "silt-chime.ogg", "Silt Chime plays its file");
eq(S.soundFile(OLD, "", "/h", DIR), OLD, "the old default, saved as a path, keeps playing");
eq(S.soundFile("/usr/share/sounds/x/bell.oga", "", "/h", DIR), "/usr/share/sounds/x/bell.oga", "a full path plays as is");
eq(S.soundFile("custom", "~/Music/a.mp3", "/h", DIR), "/h/Music/a.mp3", "custom expands ~/");
eq(S.soundFile("custom", " file:///tmp/a.ogg ", "/h", DIR), "/tmp/a.ogg", "custom drops file:// and spaces");
eq(S.soundFile("custom", "", "/h", DIR), HG, "custom without a file plays Hourglass");
eq(S.soundFile("custom", "alarm.mp3", "/h", DIR), HG, "custom needs a full path");
eq(S.soundFile("nonsense", "", "/h", DIR), HG, "an unknown choice plays Hourglass");
eq(S.RINGS.every(r => /^[a-z-]+\.ogg$/.test(r.file)), true, "ring files are plain names");

// Volume setting → gain
eq(S.volumeOf(80), 0.8, "80 is 0.8");
eq(S.volumeOf("35"), 0.35, "a string setting is read");
eq(S.volumeOf(250), 1, "above 100 is capped");
eq(S.volumeOf(-5), 0, "below 0 is raised to 0");
eq(S.volumeOf("loud"), 0.8, "unreadable falls back to 80 %");
eq(S.volumeOf(0), 0, "0 is silence, not the fallback");

// Rising alarm
eq(S.ramp(false, 0), 1, "no ramp plays at full volume");
eq(S.ramp(true, 0), 0.3, "the ramp starts at 30 %");
eq(Math.round(S.ramp(true, 1) * 100), 65, "then 65 %");
eq(S.ramp(true, 2), 1, "then full volume");
eq(S.ramp(true, 9), 1, "and stays there");

// How long the alarm rings
eq(S.ringLimitMs(60), 60000, "60 s");
eq(S.ringLimitMs("30"), 30000, "a string setting is read");
eq(S.ringLimitMs(1), 5000, "at least 5 s");
eq(S.ringLimitMs("x"), 60000, "unreadable falls back to 60 s");

// Player commands are lists, with `--` before the path
eq(S.playerCommand(false, "/a b.oga", 0.5), ["pw-play", "--volume=0.50", "--", "/a b.oga"], "pw-play first");
eq(S.playerCommand(true, "/a.oga", 0.5), ["paplay", "--volume=32768", "/a.oga"], "paplay as the fallback");
eq(S.playerCommand(false, "--evil", 1)[2], "--", "a path that looks like an option stays after --");

done();
