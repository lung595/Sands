import QtQuick
import QtTest
import "../../scripts/preview/mock"
import "../../components"

// The help note keeps the message it showed, and its size, while it fades out:
// clearing the note must not empty the texts and shrink the card to the mark.
// Run: tests/qml-page/run.sh
Item {
    width: 404
    height: 200

    FakeDaemon {
        id: daemon
    }

    HelpNote {
        id: note
        daemon: daemon
        maxWidth: 380
    }

    TestCase {
        name: "HelpNoteFade"
        when: windowShown

        function test_fadeKeepsTextAndWidth() {
            daemon.note = {
                title: "No sound player",
                hint: "Install pw-play or paplay to hear the bell",
                anchor: "sound"
            };
            tryCompare(note, "opacity", 1);
            const shown = note.width;
            daemon.note = null;
            // Lets the Row lay out again (polish) while the fade runs
            wait(40);
            verify(note.opacity > 0.05, "still fading");
            compare(note.width, shown);
            verify(note.width > 3 * note.linkSize, "keeps the text width");
            tryCompare(note, "visible", false);
        }
    }
}
