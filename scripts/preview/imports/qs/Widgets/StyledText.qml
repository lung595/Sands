import QtQuick

// Mirrors the DMS defaults (wrap, elide, centering) so text lays out as in the shell.
Text {
    font.pixelSize: 14
    color: "white"
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
