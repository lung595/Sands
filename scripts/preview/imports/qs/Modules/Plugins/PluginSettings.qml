import QtQuick

// Preview stand-in for the DMS settings host: children go into one column,
// values come from `store` and go back to it, like loadValue / saveValue.
Item {
    id: root
    required property string pluginId
    property var pluginService: ({})
    property var store: ({})
    default property list<QtObject> content
    implicitHeight: column.implicitHeight
    height: implicitHeight

    function loadValue(key, fallback) {
        return store[key] !== undefined ? store[key] : fallback;
    }
    function saveValue(key, value) {
        store[key] = value;
    }
    onContentChanged: {
        for (let i = 0; i < content.length; i++)
            if (content[i] instanceof Item)
                content[i].parent = column;
    }
    Column {
        id: column
        width: parent.width
        spacing: 12
    }
}
