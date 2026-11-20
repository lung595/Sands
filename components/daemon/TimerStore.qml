import QtQuick
import qs.Common
import "../../diagnostics/Log.js" as Log
import "Retired.js" as Retired

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

    // Settings an older Sands saved and this one no longer reads (the end
    // mode): dropped once, without a word, so the default applies. DMS has no
    // call to remove a plugin setting, so this writes the settings as
    // setPluginSetting does; nothing is written when there is nothing to drop.
    function dropRetiredSettings() {
        const all = SettingsData.pluginSettings || {};
        const r = Retired.sweep(all[pluginId]);
        if (r.removed.length === 0)
            return;
        const updated = JSON.parse(JSON.stringify(all));
        updated[pluginId] = r.settings;
        SettingsData.pluginSettings = updated;
        SettingsData.savePluginSettings();
    }

    // { timers, nextId, recents } as saved, unprocessed
    function read() {
        const timers = pluginService.loadPluginState(pluginId, "timers", []);
        if (!Array.isArray(timers))
            Log.event("SND-E002", {
                "reason": "bad_data"
            });
        return {
            timers: timers,
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
