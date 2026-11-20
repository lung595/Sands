import QtQuick
import qs.Common

// The "Launcher" section: the Timers row at the top of Super+Space. The row
// needs a DMS with live sections; elsewhere these switches change nothing.
Column {
    width: parent.width
    spacing: Theme.spacingM

    SwitchRow {
        id: sectionSetting
        settingKey: "launcherSection"
        label: "Timers in the launcher"
        description: "A row of your timers at the top of Super+Space"
        defaultValue: true
    }

    SwitchRow {
        visible: sectionSetting.value
        settingKey: "launcherSectionDuringSearch"
        label: "While searching"
        description: "The row stays above the results while you type"
        defaultValue: true
    }

    SwitchRow {
        visible: sectionSetting.value
        settingKey: "launcherSectionFavourites"
        label: "Favourites in the row"
        description: "Your most started timers fill the free places"
        defaultValue: true
    }

    SwitchRow {
        settingKey: "launcherAnimate"
        label: "Animate the sand"
        description: "The sand falls while the launcher is open"
        level: "light"
        cost: "Redraws the sand while the launcher is open"
        defaultValue: true
    }
}
