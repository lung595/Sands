import QtQuick
import qs.Common
import "../../diagnostics/Log.js" as Log
import "Retired.js" as Retired

// Persistence of the engine: what survives a restart goes through DMS's
// plugin state (timers, next id, recents), nothing else is written. Nothing
// is saved before the saved state has been read (`loaded`), so an early
// change can't erase it.
QtObject {

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
    // mode, the end actions): dropped once, so the default applies. DMS has
    // no call to remove a plugin setting, so this writes the settings as
    // setPluginSetting does; nothing is written when there is nothing to drop.
    // True when the removal of the end actions must be told: only to whoever
    // had some, and only once ever (a flag in the plugin state, set at the
    // first start of 1.7.0 whatever the settings held).
    function dropRetiredSettings() {
        const all = SettingsData.pluginSettings || {};
        const r = Retired.sweep(all[pluginId]);
        if (r.removed.length > 0) {
            const updated = JSON.parse(JSON.stringify(all));
            updated[pluginId] = r.settings;
            SettingsData.pluginSettings = updated;
            SettingsData.savePluginSettings();
        }
        const done = pluginService.loadPluginState(pluginId, Retired.NOTICE_KEY, false) === true;
        if (!done)
            pluginService.savePluginState(pluginId, Retired.NOTICE_KEY, true);
        return Retired.notice(r.hadEndActions, done);
    }

    // { timers, nextId, recents } as saved, unprocessed but for the end
    // action an older timer may carry (dropped: it ends as any other)
    function read() {
        const timers = pluginService.loadPluginState(pluginId, "timers", []);
        if (!Array.isArray(timers))
            Log.event("SND-E002", {
                "reason": "bad_data"
            });
        return {
            timers: Retired.stripTimers(timers),
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
