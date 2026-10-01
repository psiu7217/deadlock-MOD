/*
 * Adapted one-shot Rune alert pattern from Predi-i/Deadlock-UI-Mods,
 * Bridge-Buff-Reminder (Apache-2.0). See THIRD_PARTY_NOTICES.md.
 */
(function () {
    'use strict';

    if (!$.DLTK) {
        $.DLTK = {};
    }
    if (!$.DLTK.Modules) {
        $.DLTK.Modules = {};
    }
    if ($.DLTK.Modules.Runes) {
        return;
    }

    var Config = $.DLTK.Config.runes;
    var State = {
        lastAlertTarget: -1,
        lastObservedTime: null,
        lastStatus: 'Waiting for HUD clock',
        lastLoggedNextSpawn: null
    };

    function getFirstAlertTime() {
        return Config.firstSpawnSeconds - Config.warningLeadSeconds;
    }

    function getTargetForCycle(cycle) {
        var safeCycle = Math.max(0, cycle);
        return {
            cycle: safeCycle,
            spawn: Config.firstSpawnSeconds + (safeCycle * Config.intervalSeconds),
            alert: getFirstAlertTime() + (safeCycle * Config.intervalSeconds)
        };
    }

    function getCycleForTime(currentTime) {
        var firstAlert = getFirstAlertTime();
        return currentTime < firstAlert
            ? 0
            : Math.floor((currentTime - firstAlert) / Config.intervalSeconds);
    }

    function getUpcoming(currentTime) {
        if (currentTime === null || typeof currentTime !== 'number') {
            return getTargetForCycle(0);
        }

        var cycle = getCycleForTime(currentTime);
        var target = getTargetForCycle(cycle);
        if (currentTime >= target.spawn) {
            target = getTargetForCycle(cycle + 1);
        }
        return target;
    }

    function getNextWarning(currentTime) {
        if (currentTime === null || typeof currentTime !== 'number') {
            return { alert: getFirstAlertTime(), active: false };
        }

        var target = getTargetForCycle(getCycleForTime(currentTime));
        var warningEnd = target.alert + Config.alertWindowSeconds;
        if (currentTime >= warningEnd) {
            target = getTargetForCycle(target.cycle + 1);
            return { alert: target.alert, active: false };
        }

        return {
            alert: target.alert,
            active: currentTime >= target.alert
        };
    }

    function formatTime(totalSeconds) {
        if (totalSeconds === null || typeof totalSeconds !== 'number') {
            return '--:--';
        }

        var absolute = Math.abs(Math.floor(totalSeconds));
        var hours = Math.floor(absolute / 3600);
        var minutes = Math.floor((absolute % 3600) / 60);
        var seconds = absolute % 60;
        function pad(value) {
            return value < 10 ? ('0' + value) : String(value);
        }

        return hours > 0
            ? (hours + ':' + pad(minutes) + ':' + pad(seconds))
            : (pad(minutes) + ':' + pad(seconds));
    }

    function resetAlertState() {
        State.lastAlertTarget = -1;
    }

    function getWarningSound() {
        return $.DLTK.Sounds && $.DLTK.Sounds.getCustomRuneWarning
            ? $.DLTK.Sounds.getCustomRuneWarning()
            : null;
    }

    function playWarningSound() {
        var sound = getWarningSound();
        if (!sound || !sound.event) {
            return false;
        }

        $.Msg('[DLTK][Sound] PlaySoundEffect: ' + sound.event + '\n');
        $.DispatchEvent('PlaySoundEffect', sound.event);
        return true;
    }

    function logNextSpawn(currentTime) {
        var upcoming = getUpcoming(currentTime);
        if (State.lastLoggedNextSpawn !== upcoming.spawn) {
            State.lastLoggedNextSpawn = upcoming.spawn;
            $.Msg('[DLTK][Runes] nextSpawn=' + formatTime(upcoming.spawn) + '\n');
        }
    }

    function onTick(currentTime, ignoredMode) {
        if (ignoredMode) {
            resetAlertState();
            State.lastObservedTime = currentTime;
            State.lastStatus = 'Paused in ignored mode';
            return;
        }

        if (currentTime === null || typeof currentTime !== 'number') {
            State.lastStatus = 'Waiting for HUD clock';
            return;
        }

        if (State.lastObservedTime !== null && currentTime < State.lastObservedTime - 2) {
            resetAlertState();
            State.lastLoggedNextSpawn = null;
        }
        State.lastObservedTime = currentTime;
        logNextSpawn(currentTime);

        if (!Config.enabled) {
            State.lastStatus = 'Disabled';
            return;
        }

        var firstAlert = getFirstAlertTime();
        if (currentTime < firstAlert) {
            State.lastStatus = 'Armed';
            return;
        }

        var cycle = getCycleForTime(currentTime);
        var target = getTargetForCycle(cycle);
        var insideWindow = currentTime >= target.alert &&
            currentTime < target.alert + Config.alertWindowSeconds;

        if (insideWindow && State.lastAlertTarget !== target.alert) {
            $.Msg('[DLTK][Runes] warning spawn=' + formatTime(target.spawn) + '\n');
            playWarningSound();
            State.lastAlertTarget = target.alert;
            State.lastStatus = 'Warning played for ' + formatTime(target.spawn);
            return;
        }

        State.lastStatus = 'Armed';
    }

    function setEnabled(enabled) {
        var nextEnabled = !!enabled;
        if (Config.enabled !== nextEnabled) {
            Config.enabled = nextEnabled;
            $.Msg('[DLTK][Runes] enabled=' + (nextEnabled ? 'true' : 'false') + '\n');
        }
        if (!Config.enabled) {
            resetAlertState();
        }
    }

    function toggleEnabled() {
        setEnabled(!Config.enabled);
        return Config.enabled;
    }

    $.DLTK.Modules.Runes = {
        onTick: onTick,
        isEnabled: function () { return Config.enabled; },
        setEnabled: setEnabled,
        toggleEnabled: toggleEnabled,
        getUpcoming: getUpcoming,
        getNextWarning: getNextWarning,
        formatTime: formatTime,
        getStatus: function () { return State.lastStatus; },
        reset: resetAlertState
    };

    $.Msg('[DLTK][Runes] initialized\n');
    $.Msg('[DLTK][Runes] enabled=' + (Config.enabled ? 'true' : 'false') + '\n');

    if ($.DLTK.Core && $.DLTK.Core.registerModule) {
        $.DLTK.Core.registerModule('Runes', $.DLTK.Modules.Runes);
    } else {
        $.Warning('[DLTK] Core was not ready when Runes module loaded.\n');
    }
})();
