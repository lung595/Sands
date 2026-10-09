import QtQuick

// Material Symbols glyph, loaded from the DMS install (the same font as the shell).
Text {
    property string name: ""
    property real size: 20
    // The shell fills the glyph with the FILL axis; a picture draws it outlined
    property bool filled: false
    FontLoader {
        id: fl
        source: "file:///usr/share/quickshell/dms/DankCommon/assets/fonts/material-design-icons/variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
    }
    text: name
    font.family: fl.name
    font.pixelSize: size
    width: size
    height: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
