import QtQuick
import qs.Common
import qs.Widgets
import "../TimeParser.js" as TP
import "../L10n.js" as L

// Contenu du panneau : sablier, temps, réglages, autres minuteurs.
Column {
    id: pop

    // Langue de l'interface (réglage du plugin, réactif)
    readonly property string lang: SettingsData.pluginSettings["smartTimer"]?.language || "auto"

    property var daemon: null
    property bool use24h: true
    // 0 → 1 : gel (pause), piloté par le panneau
    readonly property color frostColor: Qt.rgba(0.78, 0.9, 1, 1)
    // Gel : s'installe en ~0,9 s à la pause, fond en ~0,7 s à la reprise.
    property real frost: st === "paused" ? 1 : 0
    Behavior on frost {
        NumberAnimation {
            duration: pop.st === "paused" ? 900 : 700
            easing.type: Easing.InOutCubic
        }
    }

    // false quand le panneau est fermé : toutes les animations s'arrêtent.
    property bool shown: true
    readonly property bool reducedMotion: SettingsData.reduceMotion

    // Minuteur affiché en grand : celui qu'on a choisi, sinon le plus proche.
    property int selectedId: -1
    readonly property var d: pop.daemon
    readonly property var t: {
        const sel = d ? d.find(selectedId) : null;
        return sel || (d ? d.primary : null);
    }
    readonly property string st: t ? t.state : "idle"
    readonly property real rem: (t && d) ? d.remainingOf(t) : 0
    readonly property var others: (d && t) ? d.sorted.filter(x => x.id !== t.id) : []
    // Clé texte : ne change que si la liste change, pas à chaque tic d'horloge
    // (sinon le Repeater recréerait ses lignes 4 fois par seconde).
    readonly property string othersKey: others.map(x => x.id).join(",")
    readonly property color accent: (d && t) ? d.colorFor(t) : Theme.primary

    // --- Passer d'un minuteur à l'autre (glisser, molette horizontale, points)
    readonly property var ids: d ? d.sorted.map(x => x.id) : []
    readonly property int index: t ? ids.indexOf(t.id) : -1
    property real slide: 0

    function go(step) {
        if (ids.length < 2 || switchAnim.running)
            return;
        showId(ids[(index + step + ids.length) % ids.length], step);
    }
    function showId(id, dir) {
        if (!t || id === t.id)
            return;
        switchAnim.dir = dir;
        switchAnim.nextId = id;
        switchAnim.restart();
    }
    SequentialAnimation {
        id: switchAnim
        property int dir: 1
        property int nextId: -1
        NumberAnimation {
            target: pop
            property: "slide"
            to: -switchAnim.dir
            duration: pop.reducedMotion ? 0 : 130
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                pop.selectedId = switchAnim.nextId;
                pop.slide = switchAnim.dir;
            }
        }
        NumberAnimation {
            target: pop
            property: "slide"
            to: 0
            duration: pop.reducedMotion ? 0 : 240
            easing.type: Easing.OutCubic
        }
    }

    width: 340
    spacing: Theme.spacingL
    topPadding: Theme.spacingS
    bottomPadding: Theme.spacingXS

    // Ouvrir la popout coupe la sonnerie ; le minuteur reste « terminé »
    // pour qu'on choisisse : arrêter, +1 min, relancer.
    Component.onCompleted: d?.silence()
    onVisibleChanged: if (visible)
        d?.silence()

    // --- Sablier ---
    Item {
        id: glassArea
        width: parent.width
        height: 236
        opacity: 1 - Math.abs(pop.slide)
        transform: Translate {
            x: pop.slide * 56
        }

        Hourglass {
            id: glass
            anchors.fill: parent
            progress: pop.d ? pop.d.progressOf(pop.t) : 0
            running: pop.st === "running"
            paused: pop.st === "paused"
            ringing: pop.st === "ringing"
            frost: pop.frost
            frostColor: pop.frostColor
            animate: pop.shown
            reducedMotion: pop.reducedMotion
            sandColor: pop.st === "ringing" ? Theme.error : ((pop.st === "running" && pop.rem <= 60000) ? Theme.warning : pop.accent)
            glassColor: Theme.surfaceText
            capColor: Theme.surfaceContainerHighest

            // Recommencer : le sablier se retourne.
            Connections {
                target: pop.d
                function onTimerStarted(id) {
                    if (pop.t && pop.t.id === id)
                        glass.flip();
                }
            }
        }

        // Gel autour du sablier : brume froide derrière, poussière de givre
        // devant. Dessinés une fois ; leur lente dérive et le scintillement
        // sont des Animators (fil de rendu) : aucun travail JavaScript.
        Item {
            id: mistHolder
            z: -1
            anchors.fill: parent
            visible: pop.frost > 0.005
            opacity: pop.frost

            Canvas {
                id: mist
                width: 300
                height: 250
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                renderTarget: Canvas.FramebufferObject
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const c = pop.frostColor;
                    // Nuages froids qui se chevauchent : une brume, pas un cercle.
                    const blobs = [[0.5, 0.48, 0.42, 0.34], [0.34, 0.36, 0.26, 0.22], [0.68, 0.4, 0.28, 0.2], [0.38, 0.7, 0.26, 0.2], [0.64, 0.72, 0.3, 0.22], [0.5, 0.2, 0.22, 0.16], [0.5, 0.86, 0.3, 0.18]];
                    for (const b of blobs) {
                        const x = b[0] * width, y = b[1] * height, r = b[2] * width;
                        const g = ctx.createRadialGradient(x, y, 0, x, y, r);
                        g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, b[3]));
                        g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                        ctx.fillStyle = g;
                        ctx.fillRect(0, 0, width, height);
                    }
                }

                // La brume dérive à peine : l'air est presque immobile.
                SequentialAnimation {
                    running: mistHolder.visible && pop.shown && !pop.reducedMotion
                    loops: Animation.Infinite
                    XAnimator {
                        target: mist
                        from: (mistHolder.width - mist.width) / 2 - 6
                        to: (mistHolder.width - mist.width) / 2 + 6
                        duration: 7000
                        easing.type: Easing.InOutSine
                    }
                    XAnimator {
                        target: mist
                        from: (mistHolder.width - mist.width) / 2 + 6
                        to: (mistHolder.width - mist.width) / 2 - 6
                        duration: 7000
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // Poussière de givre : de fins cristaux en suspension qui scintillent.
        Item {
            id: dust
            anchors.fill: parent
            visible: pop.frost > 0.005
            opacity: pop.frost

            Repeater {
                model: 16

                // Porteur positionné une fois ; le cristal bouge dedans.
                Item {
                    id: slot
                    required property int index
                    readonly property real h1: Math.abs(Math.sin(index * 91.7) * 43758.5) % 1
                    readonly property real h2: Math.abs(Math.sin(index * 17.3) * 24634.6) % 1
                    readonly property real h3: Math.abs(Math.sin(index * 53.1) * 12345.6) % 1
                    // Répartis autour du sablier, pas dessus
                    readonly property real ang: index / 16 * Math.PI * 2 + h1 * 0.4
                    readonly property real dist: 0.34 + h2 * 0.14
                    x: dust.width / 2 + Math.cos(ang) * dust.height * dist * 0.85
                    y: dust.height / 2 + Math.sin(ang) * dust.height * dist

                    Rectangle {
                        id: mote
                        width: 1.5 + slot.h3 * 2
                        height: width
                        radius: width / 2
                        x: -width / 2
                        color: "white"
                        opacity: 0.3

                        ParallelAnimation {
                            running: dust.visible && pop.shown
                            loops: Animation.Infinite

                            SequentialAnimation {
                                PauseAnimation {
                                    duration: slot.h1 * 3000
                                }
                                OpacityAnimator {
                                    target: mote
                                    to: 0.95
                                    duration: 900 + slot.h2 * 800
                                    easing.type: Easing.InOutSine
                                }
                                OpacityAnimator {
                                    target: mote
                                    to: 0.25
                                    duration: 1400 + slot.h3 * 900
                                    easing.type: Easing.InOutSine
                                }
                            }
                            SequentialAnimation {
                                YAnimator {
                                    target: mote
                                    from: 2
                                    to: -4
                                    duration: 5000 + slot.h2 * 3000
                                    easing.type: Easing.InOutSine
                                }
                                YAnimator {
                                    target: mote
                                    from: -4
                                    to: 2
                                    duration: 5000 + slot.h3 * 3000
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }
            }
        }

        // Gestes sur le sablier : clic = le retourner (recommencer),
        // molette = ±1 min, glisser / molette horizontale = autre minuteur.
        MouseArea {
            anchors.centerIn: parent
            width: 190
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            property real pressX: 0
            property bool swiped: false
            property real accX: 0
            property real accY: 0

            onPressed: m => {
                pressX = m.x;
                swiped = false;
            }
            onPositionChanged: m => {
                if (!swiped && Math.abs(m.x - pressX) > 40) {
                    swiped = true;
                    pop.go(m.x < pressX ? 1 : -1);
                }
            }
            onClicked: {
                if (!swiped && pop.t)
                    pop.d.restart(pop.t.id);
            }
            onWheel: w => {
                if (!pop.t)
                    return;
                if (Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y)) {
                    accX += w.angleDelta.x;
                    if (Math.abs(accX) >= 120) {
                        pop.go(accX < 0 ? 1 : -1);
                        accX = 0;
                    }
                } else {
                    accY += w.angleDelta.y;
                    while (Math.abs(accY) >= 120) {
                        const step = accY > 0 ? 1 : -1;
                        accY -= step * 120;
                        if (step > 0 || pop.rem > 61000)
                            pop.d.adjust(pop.t.id, step * 60000);
                    }
                }
                w.accepted = true;
            }
        }

        // Points : où l'on est parmi les minuteurs (couleur de chacun).
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -4
            spacing: 6
            visible: pop.ids.length > 1

            Repeater {
                model: pop.ids

                Rectangle {
                    id: dot
                    required property var modelData
                    required property int index
                    readonly property bool current: pop.t && pop.t.id === modelData
                    readonly property var tm: pop.d ? pop.d.find(modelData) : null
                    width: current ? 18 : 6
                    height: 6
                    radius: 3
                    color: pop.d && tm ? pop.d.colorFor(tm) : Theme.primary
                    opacity: current ? 1 : 0.45

                    Behavior on width {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pop.showId(dot.modelData, dot.index > pop.index ? 1 : -1)
                    }
                }
            }
        }
    }

    // --- Temps ---
    Item {
        width: parent.width
        height: timeCol.implicitHeight
        opacity: 1 - Math.abs(pop.slide)
        transform: Translate {
            x: pop.slide * 40
        }

        // Halo froid derrière le chrono (dessiné une fois, opacité animée)
        Canvas {
            anchors.centerIn: parent
            width: 220
            height: 90
            visible: pop.frost > 0.005
            opacity: pop.frost
            renderTarget: Canvas.FramebufferObject
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = pop.frostColor;
                ctx.translate(width / 2, height / 2);
                ctx.scale(1, height / width);
                const g = ctx.createRadialGradient(0, 0, 0, 0, 0, width / 2);
                g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.26));
                g.addColorStop(0.6, Qt.rgba(c.r, c.g, c.b, 0.07));
                g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.arc(0, 0, width / 2, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        Column {
            id: timeCol
            width: parent.width
            spacing: 0

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: pop.d ? pop.d.displayLabel(pop.t) : ""
                font.pixelSize: Theme.fontSizeMedium
                color: Qt.tint(Theme.surfaceVariantText, Qt.rgba(pop.frostColor.r, pop.frostColor.g, pop.frostColor.b, pop.frost * 0.6))
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            StyledText {
                id: bigTime
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: TP.formatClock(pop.rem)
                font.pixelSize: 52
                font.weight: Font.Light
                font.features: {
                    "tnum": 1
                }
                wrapMode: Text.NoWrap
                // Gelé : les chiffres virent au bleu glace.
                color: pop.st === "ringing" ? Theme.error : Qt.tint(Theme.surfaceText, Qt.rgba(pop.frostColor.r, pop.frostColor.g, pop.frostColor.b, pop.frost * 0.85))
                style: pop.frost > 0.01 ? Text.Outline : Text.Normal
                styleColor: Qt.rgba(pop.frostColor.r, pop.frostColor.g, pop.frostColor.b, 0.25 * pop.frost)

                SequentialAnimation {
                    running: pop.st === "ringing" && pop.shown
                    loops: Animation.Infinite
                    onRunningChanged: if (!running)
                        bigTime.opacity = 1
                    OpacityAnimator {
                        target: bigTime
                        to: 0.35
                        duration: 650
                        easing.type: Easing.InOutSine
                    }
                    OpacityAnimator {
                        target: bigTime
                        to: 1
                        duration: 650
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: pop.st === "paused" ? "ac_unit" : (pop.st === "ringing" ? "alarm" : "notifications")
                    size: 15
                    filled: true
                    color: pop.st === "ringing" ? Theme.error : (pop.st === "paused" ? pop.frostColor : Theme.surfaceVariantText)
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!pop.t)
                            return "";
                        if (pop.st === "paused")
                            return L.tr(pop.lang, "En pause");
                        if (pop.st === "ringing")
                            return L.tr(pop.lang, "Terminé");
                        const end = TP.formatTimeOfDay(pop.t.endAt, pop.use24h);
                        return TP.isTomorrow(pop.t.endAt, pop.d.now) ? L.tr(pop.lang, "Demain ") + end : end;
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    font.features: {
                        "tnum": 1
                    }
                    color: pop.st === "ringing" ? Theme.error : (pop.st === "paused" ? pop.frostColor : Theme.surfaceVariantText)
                }
            }
        }
    }

    // --- Ajustements ---
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingS

        Chip {
            visible: pop.st !== "ringing" && pop.rem > 61000
            text: L.tr(pop.lang, "−1 min")
            onClicked: pop.d.adjust(pop.t.id, -60000)
        }
        Chip {
            text: "+1 min"
            onClicked: pop.d.adjust(pop.t.id, 60000)
        }
        Chip {
            text: "+5 min"
            onClicked: pop.d.adjust(pop.t.id, 300000)
        }
    }

    // --- Commandes ---
    Item {
        width: parent.width
        height: 64

        // En cours / en pause : annuler · pause/reprendre · recommencer.
        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingXL
            visible: pop.st !== "ringing"

            RoundButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "close"
                tooltip: L.tr(pop.lang, "Annuler le minuteur")
                onClicked: pop.d.remove(pop.t.id)
            }

            RoundButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 64
                filled: true
                // Couleur du minuteur affiché ; texte foncé ou clair selon le fond.
                accent: pop.accent
                accentText: (0.299 * pop.accent.r + 0.587 * pop.accent.g + 0.114 * pop.accent.b) > 0.6 ? "#1c1b1f" : "white"
                iconName: pop.st === "paused" ? "play_arrow" : "pause"
                tooltip: pop.st === "paused" ? L.tr(pop.lang, "Reprendre") : L.tr(pop.lang, "Mettre en pause")
                onClicked: pop.d.toggle(pop.t.id)
            }

            RoundButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "replay"
                tooltip: L.tr(pop.lang, "Recommencer (") + (pop.t ? TP.formatHuman(pop.t.total) : "") + ")"
                onClicked: pop.d.restart(pop.t.id)
            }
        }

        // Terminé : une seule action évidente, et « relancer » à côté.
        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingM
            visible: pop.st === "ringing"

            Rectangle {
                id: stopBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 168
                height: 56
                radius: height / 2
                color: stopMouse.pressed ? Qt.darker(Theme.error, 1.12) : (stopMouse.containsMouse ? Qt.lighter(Theme.error, 1.08) : Theme.error)
                scale: stopMouse.pressed ? 0.96 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "stop"
                        filled: true
                        size: 22
                        color: Theme.errorText
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: L.tr(pop.lang, "Arrêter")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        color: Theme.errorText
                    }
                }

                MouseArea {
                    id: stopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.d.dismiss(pop.t.id)
                }
            }

            RoundButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 56
                iconName: "replay"
                tooltip: L.tr(pop.lang, "Relancer ") + (pop.t ? TP.formatHuman(pop.t.total) : "")
                onClicked: pop.d.restart(pop.t.id)
            }
        }
    }

    // --- Autres minuteurs ---
    Column {
        width: parent.width
        spacing: 2
        visible: pop.others.length > 0

        Rectangle {
            width: parent.width - Theme.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.18)
        }

        Item {
            width: 1
            height: Theme.spacingXS
        }

        Repeater {
            model: pop.othersKey === "" ? [] : pop.othersKey.split(",").map(Number)

            delegate: Rectangle {
                id: line

                required property var modelData
                readonly property var tm: pop.d ? pop.d.find(modelData) : null
                readonly property string lst: tm ? tm.state : ""
                readonly property real lrem: (pop.d && tm) ? pop.d.remainingOf(tm, pop.d.now) : 0

                width: pop.width
                height: 48
                radius: Theme.cornerRadius
                color: lineMouse.containsMouse ? Theme.surfaceTextHover : "transparent"

                MouseArea {
                    id: lineMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.showId(line.modelData, 1)
                }

                ProgressRing {
                    id: miniRing
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    thickness: 3
                    progress: pop.d ? pop.d.progressOf(line.tm) : 0
                    color: line.lst === "ringing" ? Theme.error : (line.lst === "paused" ? Theme.surfaceVariantText : (pop.d && line.tm ? pop.d.colorFor(line.tm) : Theme.primary))
                    trackColor: Theme.surfaceContainerHighest
                }

                StyledText {
                    anchors.left: miniRing.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: lineTime.left
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: pop.d ? pop.d.displayLabel(line.tm) : ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                StyledText {
                    id: lineTime
                    anchors.right: lineActions.left
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: TP.formatClock(line.lrem)
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    font.features: {
                        "tnum": 1
                    }
                    color: line.lst === "ringing" ? Theme.error : (line.lst === "paused" ? Theme.surfaceVariantText : Theme.surfaceText)
                }

                Row {
                    id: lineActions
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    DankActionButton {
                        buttonSize: 36
                        iconName: line.lst === "running" ? "pause" : (line.lst === "paused" ? "play_arrow" : "stop")
                        iconColor: line.lst === "ringing" ? Theme.error : Theme.surfaceText
                        onClicked: pop.d.toggle(line.modelData)
                    }
                    DankActionButton {
                        buttonSize: 36
                        iconName: "close"
                        iconColor: Theme.surfaceVariantText
                        onClicked: pop.d.remove(line.modelData)
                    }
                }
            }
        }
    }
}
