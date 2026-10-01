/*
 * Adapted portions: panel/root traversal and ignored-mode checks from
 * Predi-i/Deadlock-UI-Mods, Bridge-Buff-Reminder (Apache-2.0).
 * Modified for DLTK's modular core and current HUD clock shapes on 2026-09-28.
 * See THIRD_PARTY_NOTICES.md and LICENSES/Apache-2.0.txt.
 */
(function () {
    'use strict';

    if (!$.DLTK) {
        $.DLTK = {};
    }

    if ($.DLTK.Core) {
        return;
    }

    var CTX = $.GetContextPanel();

    var State = {
        rootPanel: null,
        uiTreeRoot: null,
        clockPanel: null,
        currentTime: null,
        ignoredMode: false,
        modules: []
    };

    function isValidPanel(panel) {
        return !!(panel && panel.IsValid && panel.IsValid());
    }

    function getUiTreeRoot() {
        if (isValidPanel(State.uiTreeRoot)) {
            return State.uiTreeRoot;
        }

        var top = CTX;
        var guard = 0;

        while (top && top.GetParent && top.GetParent() && guard < 50) {
            top = top.GetParent();
            guard++;
        }

        if (!top) {
            State.uiTreeRoot = null;
            State.rootPanel = null;
            return null;
        }

        State.uiTreeRoot = top;
        State.rootPanel = null;
        return top;
    }

    function getRoot() {
        if (isValidPanel(State.rootPanel)) {
            return State.rootPanel;
        }

        var top = getUiTreeRoot();
        State.rootPanel = top && top.FindChildTraverse
            ? (top.FindChildTraverse('Hud') || top)
            : top;

        return State.rootPanel;
    }

    function isModeIgnored(root) {
        if (!root || !root.BHasClass) {
            return false;
        }

        if (root.BHasClass('connectedToHideout')) {
            return true;
        }

        if (root.BHasClass('InHideout')) {
            return true;
        }

        if (root.BHasClass('connectedToHeroTesting')) {
            return true;
        }

        if (root.BHasClass('gamemode_streetbrawl')) {
            return true;
        }

        return false;
    }

    function parseClockText(text) {
        if (!text) {
            return null;
        }

        var raw = String(text).trim();
        if (!raw) {
            return null;
        }

        var isNegative = raw.charAt(0) === '-';
        if (isNegative) {
            raw = raw.substring(1);
        }

        var parts = raw.split(':');
        var hours = 0;
        var minutes = 0;
        var seconds = 0;

        if (parts.length === 3) {
            hours = parseInt(parts[0], 10);
            minutes = parseInt(parts[1], 10);
            seconds = parseInt(parts[2], 10);
        } else if (parts.length === 2) {
            minutes = parseInt(parts[0], 10);
            seconds = parseInt(parts[1], 10);
        } else {
            return null;
        }

        if (isNaN(hours) || isNaN(minutes) || isNaN(seconds)) {
            return null;
        }

        var total = (hours * 3600) + (minutes * 60) + seconds;
        return isNegative ? -total : total;
    }

    function readPanelClock(panel) {
        if (!isValidPanel(panel)) {
            return null;
        }

        var directTime = parseClockText(panel.text);

        if (directTime !== null) {
            return directTime;
        }

        if (!panel.FindChildTraverse) {
            return null;
        }

        // Older builds exposed a Label named GameTime directly. Current
        // builds expose GameClock with a child Label named Time.
        var timeLabel = panel.FindChildTraverse('Time') ||
            panel.FindChildTraverse('GameTime');

        return timeLabel ? parseClockText(timeLabel.text) : null;
    }

    function findClockPanel(root) {
        if (!root || !root.FindChildTraverse) {
            return null;
        }

        return root.FindChildTraverse('GameTime') ||
            root.FindChildTraverse('GameClock');
    }

    function getCurrentTime(root) {
        if (!root) {
            return null;
        }

        if (!isValidPanel(State.clockPanel)) {
            State.clockPanel = findClockPanel(root);
        }

        var currentTime = readPanelClock(State.clockPanel);

        // Re-discover once if a build changed the clock panel shape while the
        // HUD context stayed alive (for example after entering a match).
        if (currentTime === null) {
            State.clockPanel = findClockPanel(root);
            currentTime = readPanelClock(State.clockPanel);
        }

        return currentTime;
    }

    function registerModule(name, moduleObject) {
        if (!name || !moduleObject) {
            return;
        }

        for (var i = 0; i < State.modules.length; i++) {
            if (State.modules[i].name === name) {
                State.modules[i].module = moduleObject;
                return;
            }
        }

        State.modules.push({
            name: name,
            module: moduleObject
        });
    }

    function notifyModules(currentTime, ignoredMode) {
        for (var i = 0; i < State.modules.length; i++) {
            var moduleObject = State.modules[i].module;

            if (!moduleObject || !moduleObject.onTick) {
                continue;
            }

            try {
                moduleObject.onTick(currentTime, ignoredMode);
            } catch (error) {
                $.Warning('[DLTK] module tick failed: ' + State.modules[i].name + ' :: ' + error + '\n');
            }
        }
    }

    function notifyUI() {
        if ($.DLTK.UI && $.DLTK.UI.refresh) {
            try {
                $.DLTK.UI.refresh();
            } catch (error) {
                $.Warning('[DLTK] UI refresh failed: ' + error + '\n');
            }
        }
    }

    function loop() {
        if (!CTX || !CTX.IsValid || !CTX.IsValid()) {
            return;
        }

        var root = getRoot();
        var ignoredMode = isModeIgnored(root);
        var currentTime = getCurrentTime(root);

        State.ignoredMode = ignoredMode;
        State.currentTime = currentTime;

        notifyModules(currentTime, ignoredMode);
        notifyUI();

        var rate = (ignoredMode || currentTime === null)
            ? $.DLTK.Config.core.pollRateIdle
            : $.DLTK.Config.core.pollRateActive;

        $.Schedule(rate, loop);
    }

    $.DLTK.Core = {
        registerModule: registerModule,

        getCurrentTime: function () {
            return State.currentTime;
        },

        isIgnoredMode: function () {
            return State.ignoredMode;
        },

        parseClockText: parseClockText,

        getRoot: getRoot
    };

    $.Msg('[DLTK][Core] initialized\n');
    $.Schedule(1.0, loop);
})();
