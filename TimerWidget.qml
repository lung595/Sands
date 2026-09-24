import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components"
import "TimeParser.js" as TP
import "L10n.js" as L

// Pastille de barre + popout. L'état vit dans le daemon ; ce fichier ne fait
// qu'afficher et relayer les actions.
PluginComponent {
    id: root

    // Langue de l'interface (réglage du plugin, réactif)
    readonly property string lang: SettingsData.pluginSettings["smartTimer"]?.language || "auto"

    pluginId: "smartTimer"
    pluginService: PluginService
    layerNamespacePlugin: "smart-timer"

    readonly property var daemon: PluginService.pluginDaemonInstances[pluginId] ?? null
    readonly property bool hasTimers: daemon?.hasTimers ?? false
    readonly property var primary: daemon?.primary ?? null
    readonly property bool use24h: SettingsData.use24HourClock !== false

    // Invisible au repos : la pastille apparaît (largeur + fondu) au premier minuteur.
    function syncVisibility() {
        setVisibilityOverride(root.hasTimers);
        if (!root.hasTimers)
            root.closePopout();
    }
    onHasTimersChanged: syncVisibility()
    Component.onCompleted: syncVisibility()

    // Raccourci clavier / IPC : ouvre le panneau sur l'écran actif.
    Connections {
        target: root.daemon
        function onPanelRequested(screenName) {
            if (!screenName || (root.parentScreen && root.parentScreen.name === screenName))
                root.triggerPopout();
        }
    }

    // Clic gauche : ouvre le panneau.
    // Clic droit : pause / reprise du plus proche ; pendant la sonnerie, l'arrête.
    pillRightClickAction: () => {
        if (!root.daemon)
            return;
        if (root.daemon.ringing)
            root.daemon.dismissRinging();
        else if (root.primary)
            root.daemon.toggle(root.primary.id);
    }

    // La barre peut ouvrir les panneaux au survol : pas pour le minuteur. Le
    // survol affiche seulement son nom dans la pastille ; le panneau s'ouvre
    // au clic. (DMS appelle cette fonction au survol ; on la neutralise.)
    function triggerHoverPopout(widgetHostId) {
    }

    // ------------------------------------------------------------------
    // Pastille
    // ------------------------------------------------------------------

    horizontalBarPill: Component {
        Item {
            id: pill

            // Juste après un lancement, on montre CE minuteur (nom + durée) 2 s.
            property int flashId: -1
            readonly property var flashTimer: flashId >= 0 && root.daemon ? root.daemon.find(flashId) : null
            readonly property var t: flashTimer || root.primary
            readonly property string st: t ? t.state : "idle"
            readonly property real rem: t && root.daemon ? root.daemon.remainingOf(t) : 0
            readonly property bool urgent: st === "running" && rem <= 60000
            readonly property bool finalCountdown: st === "running" && rem <= 10000
            // Survol amorti : la pastille s'ouvre après 120 ms et ne se referme
            // que 450 ms après la sortie. Sans ça, l'encoche qui se recentre en
            // s'élargissant faisait entrer/sortir la souris en boucle (clignotement).
            property bool hoverOpen: false
            readonly property bool showLabel: st === "ringing" || flashTimer !== null || hoverOpen

            readonly property real textSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
            readonly property real pad: (root.barConfig?.removeWidgetPadding ?? false) ? 0 : (root.barConfig?.widgetPadding ?? 12) * (root.widgetThickness / 30)
            readonly property string timeText: st === "ringing" ? L.tr(root.lang, "Terminé") : TP.formatClock(rem)
            readonly property int others: Math.max(0, (root.daemon?.count ?? 0) - 1)
            readonly property color accent: st === "ringing" ? Theme.error : (urgent ? Theme.warning : (root.daemon && t ? root.daemon.colorFor(t) : Theme.primary))

            implicitWidth: row.implicitWidth
            implicitHeight: root.widgetThickness - pad * 2

            Item {
                x: -pill.pad
                y: -pill.pad
                width: pill.width + pill.pad * 2
                height: pill.height + pill.pad * 2

                HoverHandler {
                    id: hover
                    onHoveredChanged: {
                        if (hovered) {
                            hoverOut.stop();
                            hoverIn.restart();
                        } else {
                            hoverIn.stop();
                            hoverOut.restart();
                        }
                    }
                }
            }

            Timer {
                id: hoverIn
                interval: 120
                onTriggered: pill.hoverOpen = true
            }

            Timer {
                id: hoverOut
                interval: 450
                onTriggered: pill.hoverOpen = false
            }

            Timer {
                id: flashEnd
                interval: 2200
                onTriggered: pill.flashId = -1
            }

            Connections {
                target: root.daemon
                function onTimerStarted(id) {
                    pill.flashId = id;
                    flashEnd.restart();
                }
            }

            // Fond d'alerte qui respire pendant la sonnerie.
            Rectangle {
                id: alertBg
                x: -pill.pad
                y: -pill.pad
                width: pill.width + pill.pad * 2
                height: pill.height + pill.pad * 2
                radius: Theme.cornerRadius
                color: Theme.error
                visible: pill.st === "ringing"
                opacity: 0.2

                // Animators : exécutés par le fil de rendu.
                SequentialAnimation {
                    running: pill.st === "ringing"
                    loops: Animation.Infinite
                    OpacityAnimator {
                        target: alertBg
                        to: 0.4
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                    OpacityAnimator {
                        target: alertBg
                        to: 0.16
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                }
            }

            // Molette : ±1 min (sur un minuteur qui sonne, vers le haut = +1 min).
            // Clic du milieu : annule. Gauche et droit passent au BasePill dessous.
            MouseArea {
                x: -pill.pad
                y: -pill.pad
                width: pill.width + pill.pad * 2
                height: pill.height + pill.pad * 2
                acceptedButtons: Qt.MiddleButton
                property real acc: 0

                onClicked: {
                    if (!root.daemon || !pill.t)
                        return;
                    if (pill.st === "ringing")
                        root.daemon.dismissRinging();
                    else
                        root.daemon.remove(pill.t.id);
                }
                onWheel: wheel => {
                    if (!root.daemon || !pill.t)
                        return;
                    acc += wheel.angleDelta.y;
                    while (Math.abs(acc) >= 120) {
                        const step = acc > 0 ? 1 : -1;
                        acc -= step * 120;
                        if (step < 0 && pill.st === "ringing")
                            continue;
                        root.daemon.adjust(pill.t.id, step * 60000);
                    }
                    wheel.accepted = true;
                }
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: Math.round(pill.textSize * 0.45)

                Item {
                    id: glyph
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(pill.textSize * 1.2)
                    height: width

                    // Dix dernières secondes : un battement par seconde.
                    SequentialAnimation {
                        running: pill.finalCountdown
                        loops: Animation.Infinite
                        onRunningChanged: if (!running)
                            glyph.scale = 1
                        ScaleAnimator {
                            target: glyph
                            to: 1.22
                            duration: 110
                            easing.type: Easing.OutQuad
                        }
                        ScaleAnimator {
                            target: glyph
                            to: 1
                            duration: 390
                            easing.type: Easing.OutCubic
                        }
                        PauseAnimation {
                            duration: 500
                        }
                    }

                    ProgressRing {
                        anchors.fill: parent
                        visible: pill.st === "running"
                        progress: root.daemon ? root.daemon.progressOf(pill.t) : 0
                        thickness: Math.max(2.5, Math.round(width * 0.2))
                        color: pill.accent
                        trackColor: Theme.withAlpha(Theme.widgetTextColor, 0.2)

                        Behavior on color {
                            ColorAnimation {
                                duration: 400
                            }
                        }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        visible: pill.st === "paused"
                        name: "pause_circle"
                        filled: true
                        size: parent.width
                        color: Theme.withAlpha(Theme.widgetTextColor, 0.6)
                    }

                    DankIcon {
                        id: bell
                        anchors.centerIn: parent
                        visible: pill.st === "ringing"
                        name: "alarm"
                        filled: true
                        size: parent.width
                        color: Theme.error

                        SequentialAnimation {
                            running: pill.st === "ringing" && (root.daemon?.soundActive ?? false)
                            loops: Animation.Infinite
                            onRunningChanged: if (!running)
                                bell.rotation = 0
                            RotationAnimator {
                                target: bell
                                to: 14
                                duration: 70
                            }
                            RotationAnimator {
                                target: bell
                                to: -14
                                duration: 140
                            }
                            RotationAnimator {
                                target: bell
                                to: 10
                                duration: 120
                            }
                            RotationAnimator {
                                target: bell
                                to: 0
                                duration: 90
                            }
                            PauseAnimation {
                                duration: 650
                            }
                        }
                    }
                }

                // Nom du minuteur : se déplie au lancement, au survol et à la fin.
                Item {
                    id: labelClip
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property real fullWidth: Math.min(labelRow.implicitWidth, pill.textSize * 11)
                    width: pill.showLabel ? fullWidth : 0
                    height: labelRow.implicitHeight
                    clip: true
                    opacity: pill.showLabel ? 1 : 0
                    visible: width > 0.5

                    Behavior on width {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 220
                        }
                    }

                    Row {
                        id: labelRow
                        spacing: Math.round(pill.textSize * 0.35)

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.daemon ? root.daemon.displayLabel(pill.t) : ""
                            width: Math.min(implicitWidth, pill.textSize * 11 - dot.implicitWidth - parent.spacing)
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font.pixelSize: pill.textSize
                            font.weight: Font.DemiBold
                            color: pill.st === "ringing" ? Theme.error : Theme.widgetTextColor
                        }

                        StyledText {
                            id: dot
                            anchors.verticalCenter: parent.verticalCenter
                            text: "·"
                            font.pixelSize: pill.textSize
                            color: Theme.withAlpha(Theme.widgetTextColor, 0.45)
                        }
                    }
                }

                StyledText {
                    id: timeLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: pill.timeText
                    // Largeur figée sur « 00:00 » : la pastille ne tremble pas à chaque seconde.
                    width: pill.st === "ringing" ? implicitWidth : Math.ceil(metrics.advanceWidth)
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.NoWrap
                    font.pixelSize: pill.textSize
                    font.weight: pill.urgent || pill.st === "ringing" ? Font.DemiBold : Font.Medium
                    font.features: {
                        "tnum": 1
                    }
                    color: {
                        if (pill.st === "ringing")
                            return Theme.error;
                        if (pill.st === "paused")
                            return Theme.withAlpha(Theme.widgetTextColor, 0.55);
                        return pill.urgent ? Theme.warning : Theme.widgetTextColor;
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 400
                        }
                    }

                    TextMetrics {
                        id: metrics
                        font: timeLabel.font
                        text: TP.widthTemplate(pill.timeText)
                    }
                }

                // Fin : ✕ explicite (tout clic sur la pastille arrête aussi).
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.st === "ringing"
                    name: "close"
                    size: Math.round(pill.textSize * 1.1)
                    color: Theme.error
                }

                // « +2 » : autres minuteurs en cours.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.others > 0 && pill.st !== "ringing"
                    height: Math.round(pill.textSize * 1.15)
                    width: Math.max(height, badgeText.implicitWidth + Math.round(pill.textSize * 0.6))
                    radius: height / 2
                    color: Theme.withAlpha(Theme.primary, 0.18)

                    StyledText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: "+" + pill.others
                        font.pixelSize: Math.round(pill.textSize * 0.78)
                        font.weight: Font.DemiBold
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.primary
                    }
                }
            }
        }
    }

    // Barre verticale : anneau + temps court (« 18m », « 42s »).
    verticalBarPill: Component {
        Column {
            id: vpill

            readonly property var t: root.primary
            readonly property string st: t ? t.state : "idle"
            readonly property real textSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
            readonly property real rem: t ? root.daemon.remainingOf(t) : 0

            spacing: 2

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(vpill.textSize * 1.3)
                height: width

                ProgressRing {
                    anchors.fill: parent
                    progress: root.daemon ? root.daemon.progressOf(vpill.t) : 0
                    thickness: Math.max(2, Math.round(width * 0.14))
                    color: vpill.st === "ringing" ? Theme.error : (vpill.st === "paused" ? Theme.withAlpha(Theme.widgetTextColor, 0.5) : (root.daemon && vpill.t ? root.daemon.colorFor(vpill.t) : Theme.primary))
                    trackColor: Theme.withAlpha(Theme.widgetTextColor, 0.16)
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const s = Math.ceil(Math.abs(vpill.rem) / 1000);
                    if (s >= 3600)
                        return Math.floor(s / 3600) + "h";
                    if (s >= 60)
                        return Math.ceil(s / 60) + "m";
                    return s + "s";
                }
                font.pixelSize: Math.round(vpill.textSize * 0.85)
                font.weight: Font.Medium
                font.features: {
                    "tnum": 1
                }
                color: vpill.st === "ringing" ? Theme.error : Theme.widgetTextColor
            }
        }
    }

    // ------------------------------------------------------------------
    // Panneau (popout native de DMS)
    // ------------------------------------------------------------------

    popoutWidth: 356
    popoutHeight: 560

    popoutContent: Component {
        Item {
            id: pane

            property var closePopout: null
            property var parentPopout: null

            width: parent ? parent.width : root.popoutWidth
            implicitHeight: content.implicitHeight

            TimerPanelContent {
                id: content
                width: pane.width
                daemon: root.daemon
                use24h: root.use24h
                // Panneau fermé (DMS garde son contenu chargé) : plus d'animation.
                shown: pane.parentPopout ? pane.parentPopout.shouldBeVisible : true
            }
        }
    }
}
