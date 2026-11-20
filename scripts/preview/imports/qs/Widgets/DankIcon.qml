import QtQuick

// Material Symbols glyph, loaded from the DMS install (the same font as the shell).
Text {
    property string name: ""
    property real size: 20
    // The shell fills the glyph with the FILL axis; a picture draws it outlined
    property bool filled: false
    // DMS moved its shared assets from DankCommon/ to DCommon/: the new place
    // first, the old one only when the new one is not there
    FontLoader {
        id: fl
        source: "file:///usr/share/quickshell/dms/DCommon/assets/fonts/material-design-icons/variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
    }
    FontLoader {
        id: older
        source: fl.status === FontLoader.Error ? "file:///usr/share/quickshell/dms/DankCommon/assets/fonts/material-design-icons/variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf" : ""
    }
    text: name
    font.family: fl.status === FontLoader.Error ? older.name : fl.name
    font.pixelSize: size
    width: size
    height: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
