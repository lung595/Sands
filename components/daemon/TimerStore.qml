import QtQuick

// Persistence of the engine: what survives a restart goes through DMS's
// plugin state (timers, next id, recents), nothing else is written. Nothing
// is saved before the saved state has been read (`loaded`), so an early
// change can't erase it.
QtObject {
    id: store

    required property var pluginService
    required property string pluginId

    property bool loaded: false

    // The launcher works without a prefix by default (« 20 min » is enough).
    // Without this explicit setting, DMS would fall back to the "!" trigger.
    function ensureLauncherDefault() {
        if (pluginService.loadPluginData(pluginId, "noTrigger", null) === null)
            pluginService.savePluginData(pluginId, "noTrigger", true);
    }

    // { timers, nextId, recents } as saved, unprocessed
    function read() {
        return {
            timers: pluginService.loadPluginState(pluginId, "timers", []),
            nextId: pluginService.loadPluginState(pluginId, "nextId", 1),
            recents: pluginService.loadPluginState(pluginId, "recents", []) || []
        };
    }

    function saveTimers(list, nextId) {
        if (!pluginService || !loaded)
            return;
        pluginService.savePluginState(pluginId, "timers", list);
        pluginService.savePluginState(pluginId, "nextId", nextId);
    }

    function saveRecents(list) {
        if (pluginService)
            pluginService.savePluginState(pluginId, "recents", list);
    }
}
