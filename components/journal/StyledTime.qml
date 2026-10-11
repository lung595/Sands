import QtQuick
import qs.Common
import qs.Widgets

// A duration of the journal: tabular figures, so two values line up.
StyledText {
    wrapMode: Text.NoWrap
    font.pixelSize: Theme.fontSizeMedium
    font.features: {
        "tnum": 1
    }
    color: Theme.surfaceText
}
