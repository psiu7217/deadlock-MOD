/*
 * Adapted portions: Rune polling and one-shot alert pattern from
 * Predi-i/Deadlock-UI-Mods, Bridge-Buff-Reminder (Apache-2.0).
 * Modified for configurable DLTK timing, module APIs, and current sound state
 * on 2026-09-28. See THIRD_PARTY_NOTICES.md and LICENSES/Apache-2.0.txt.
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
        lastStatus: 'Waiting for HUD clock'
    };

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value));
    }

    function getFirstAlertTime() {
        return Config.firstSpawnSeconds - Config.warningLeadSeconds;
    }

    function getCycleForTime(currentTime) {
        var firstAlert = getFirstAlertTime();

        if (currentTime < firstAlert) {
            return 0;
        }

        return Math.floor(
            (currentTime - firstAlert) / Config.intervalSeconds
        );
    }

    function getTargetForCycle(cycle) {
        var safeCycle = Math.max(0, cycle);

        return {
            cycle: safeCycle,
            spawn: Config.firstSpawnSeconds + (safeCycle * Config.intervalSeconds),
            alert: getFirstAlertTime() + (safeCycle * Config.intervalSeconds)
        };
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

    function resetAlertState() {
        State.lastAlertTarget = -1;
    }

    function getWarningSound() {
        return $.DLTK.Sounds && $.DLTK.Sounds.getCustomRuneWarning
            ? $.DLTK.Sounds.getCustomRuneWarning()
            : null;
    }

    function dispatchSoundEvent(eventName, shouldLog) {
        if (!eventName) {
            return false;
        }

        if (shouldLog) {
            $.Msg('[DLTK][Sound] PlaySoundEffect: ' + eventName + '\n');
        }

        $.DispatchEvent('PlaySoundEffect', eventName);
        return true;
    }

    function playWarningSound() {
        var sound = getWarningSound();

        return sound ? dispatchSoundEvent(sound.event, false) : false;
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

        if (
            State.lastObservedTime !== null &&
            currentTime < (State.lastObservedTime - 2)
        ) {
            resetAlertState();
        }

        State.lastObservedTime = currentTime;

        if (!Config.enabled) {
            State.lastStatus = 'Disabled';
            return;
        }

        var firstAlert = getFirstAlertTime();

        if (currentTime < firstAlert) {
            State.lastStatus = 'Armed';
            return;
        }

        var cycle = Math.floor(
            (currentTime - firstAlert) / Config.intervalSeconds
        );

        var target = getTargetForCycle(cycle);

        var insideWindow =
            currentTime >= target.alert &&
            currentTime < (target.alert + Config.alertWindowSeconds);

        if (
            insideWindow &&
            State.lastAlertTarget !== target.alert
        ) {
            playWarningSound();
            State.lastAlertTarget = target.alert;
            State.lastStatus = 'Warning played for ' + formatTime(target.spawn);
            return;
        }

        State.lastStatus = 'Armed';
    }

    function setEnabled(enabled) {
        Config.enabled = !!enabled;

        if (!Config.enabled) {
            resetAlertState();
        }
    }

    function toggleEnabled() {
        setEnabled(!Config.enabled);
        return Config.enabled;
    }

    function setWarningLead(seconds) {
        var parsed = parseInt(seconds, 10);

        if (isNaN(parsed)) {
            return Config.warningLeadSeconds;
        }

        Config.warningLeadSeconds = clamp(
            parsed,
            Config.minLeadSeconds,
            Config.maxLeadSeconds
        );

        resetAlertState();

        return Config.warningLeadSeconds;
    }

    function adjustWarningLead(delta) {
        return setWarningLead(
            Config.warningLeadSeconds + parseInt(delta, 10)
        );
    }

    function testSound() {
        var sound = getWarningSound();

        return sound ? dispatchSoundEvent(sound.event, true) : false;
    }

    function testKnownGoodSound() {
        return dispatchSoundEvent('UI.PlayMenu.Activate', true);
    }

    function formatTime(totalSeconds) {
        if (totalSeconds === null || typeof totalSeconds !== 'number') {
            return '--:--';
        }

        var negative = totalSeconds < 0;
        var absolute = Math.abs(Math.floor(totalSeconds));
        var hours = Math.floor(absolute / 3600);
        var minutes = Math.floor((absolute % 3600) / 60);
        var seconds = absolute % 60;

        function pad(value) {
            return value < 10 ? ('0' + value) : String(value);
        }

        var result = hours > 0
            ? (hours + ':' + pad(minutes) + ':' + pad(seconds))
            : (pad(minutes) + ':' + pad(seconds));

        return negative ? ('-' + result) : result;
    }

    $.DLTK.Modules.Runes = {
        onTick: onTick,

        isEnabled: function () {
            return Config.enabled;
        },

        setEnabled: setEnabled,
        toggleEnabled: toggleEnabled,

        getWarningLead: function () {
            return Config.warningLeadSeconds;
        },

        setWarningLead: setWarningLead,
        adjustWarningLead: adjustWarningLead,

        getSoundLabel: function () {
            var sound = getWarningSound();
            return sound ? sound.name : 'Unavailable';
        },

        getSoundEvent: function () {
            var sound = getWarningSound();
            return sound ? sound.event : '';
        },

        testSound: testSound,
        testKnownGoodSound: testKnownGoodSound,
        getUpcoming: getUpcoming,
        formatTime: formatTime,

        getStatus: function () {
            return State.lastStatus;
        },

        reset: resetAlertState
    };

    if ($.DLTK.Core && $.DLTK.Core.registerModule) {
        $.DLTK.Core.registerModule('Runes', $.DLTK.Modules.Runes);
    } else {
        $.Warning('[DLTK] Core was not ready when Runes module loaded.\n');
    }
})();
