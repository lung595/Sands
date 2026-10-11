import QtQuick
import qs.Common

// The "Appearance" section.
Column {
    width: parent.width
    spacing: Theme.spacingM

    ChoiceRow {
        settingKey: "hourglassStyle"
        label: "Hourglass"
        description: "Only the hourglass changes: sand, freeze and flip stay the same"
        options: [
            {
                label: "Classic",
                value: "classic"
            },
            {
                // A nod to Steven Universe
                label: "Glass of Time",
                value: "glassOfTime"
            }
        ]
        defaultValue: "classic"
    }
}
