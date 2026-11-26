import QtQuick

// Material Symbols glyph, loaded from the DMS install (the same font as the shell).
Text {
    property string name: ""
    property real size: 20
    // The shell fills the glyph with the FILL axis; a picture draws it outlined
    property bool filled: false
    // DMS moved its shared assets from DankCommon/ to DCommon/: the new place
    // first, the old one only when the new one is not there. Newer DMS builds
    // embed the shell and have no /usr/share copy: install the font under
    // ~/.local/share/fonts and it is used as is, with no file to load.
    readonly property string installed: "DCommon Material Symbols Rounded"
    readonly property bool hasInstalled: Qt.fontFamilies().indexOf(installed) >= 0
    FontLoader {
        id: fl
        source: hasInstalled ? "" : "file:///usr/share/quickshell/dms/DCommon/assets/fonts/material-design-icons/variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
    }
    FontLoader {
        id: older
        source: fl.status === FontLoader.Error ? "file:///usr/share/quickshell/dms/DankCommon/assets/fonts/material-design-icons/variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf" : ""
    }
    text: name
    font.family: hasInstalled ? installed : fl.status === FontLoader.Error ? older.name : fl.name
    font.pixelSize: size
    width: size
    height: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
