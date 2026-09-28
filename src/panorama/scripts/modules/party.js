(function () {
    'use strict';

    if (!$.DLTK) {
        $.DLTK = {};
    }

    if (!$.DLTK.Modules) {
        $.DLTK.Modules = {};
    }

    if ($.DLTK.Modules.Party) {
        return;
    }

    var Config = $.DLTK.Config.party;
    var ContextPanel = $.GetContextPanel();
    var State = {
        eventRegistered: false,
        retryToken: 0,
        lastPartyState: null,
        partyDetected: false,
        nativeSelectorFound: false,
        currentPreference: 'Unknown',
        lastAppliedAt: '',
        lastPartyUpdatedAt: 'Never',
        lastApplyAttemptAt: 'Never',
        lastResult: 'Unknown',
        verification: 'Unknown',
        lastStatus: 'Waiting for party state',
        nextFallbackAt: 0
    };

    function isValidPanel(panel) {
        return !!(panel && panel.IsValid && panel.IsValid());
    }

    function getTopPanel() {
        var top = ContextPanel;
        var guard = 0;

        while (top && top.GetParent && top.GetParent() && guard < 50) {
            top = top.GetParent();
            guard++;
        }

        return top;
    }

    function findPanel(id) {
        var top = getTopPanel();
        var root = $.DLTK.Core && $.DLTK.Core.getRoot
            ? $.DLTK.Core.getRoot()
            : null;
        var panel = top && top.FindChildTraverse
            ? top.FindChildTraverse(id)
            : null;

        if (!panel && root && root.FindChildTraverse) {
            panel = root.FindChildTraverse(id);
        }

        return panel;
    }

    function hasClassInParentChain(panel, className) {
        var current = panel;
        var guard = 0;

        while (current && guard < 20) {
            if (current.BHasClass && current.BHasClass(className)) {
                return true;
            }

            current = current.GetParent ? current.GetParent() : null;
            guard++;
        }

        return false;
    }

    function readSelectedOption(selector) {
        if (!isValidPanel(selector) || !selector.GetSelected) {
            return null;
        }

        var selected = null;

        try {
            selected = selector.GetSelected();
        } catch (error) {
            return null;
        }

        if (!isValidPanel(selected)) {
            return null;
        }

        var id = selected.id ? String(selected.id) : '';
        var value = '';
        var text = selected.text ? String(selected.text) : '';

        try {
            if (selected.GetAttributeString) {
                value = selected.GetAttributeString('value', '');
            }
        } catch (errorAttribute) {
            value = '';
        }

        return {
            panel: selected,
            id: id,
            value: String(value || ''),
            text: text
        };
    }

    function selectedLabel(selected) {
        if (!selected) {
            return 'Unknown';
        }

        if (selected.id === Config.targetLanePreference ||
            selected.value === '1' ||
            selected.text.toLowerCase().indexOf('with party') !== -1) {
            return Config.targetLaneLabel;
        }

        return selected.text || selected.id || selected.value || 'Unknown';
    }

    function isWithPartySelected(selector) {
        return selectedLabel(readSelectedOption(selector)) === Config.targetLaneLabel;
    }

    function readCurrentPreference(selector) {
        return selectedLabel(readSelectedOption(selector));
    }

    function detectParty() {
        var top = getTopPanel();
        var root = $.DLTK.Core && $.DLTK.Core.getRoot
            ? $.DLTK.Core.getRoot()
            : null;

        if (hasClassInParentChain(top, 'localPlayerInParty') ||
            hasClassInParentChain(root, 'localPlayerInParty')) {
            return true;
        }

        if (top && top.FindChildrenWithClassTraverse) {
            var topPartyPanels = top.FindChildrenWithClassTraverse('localPlayerInParty') || [];
            if (topPartyPanels.length > 0) {
                return true;
            }
        }

        if (root && root.FindChildrenWithClassTraverse) {
            var rootPartyPanels = root.FindChildrenWithClassTraverse('localPlayerInParty') || [];
            if (rootPartyPanels.length > 0) {
                return true;
            }
        }

        var members = findPanel('PartyMembersList');
        if (isValidPanel(members) && members.GetChildCount) {
            try {
                return members.GetChildCount() > 0;
            } catch (errorCount) {
                return false;
            }
        }

        return false;
    }

    function formatNow() {
        var date = new Date();

        function pad(value) {
            return value < 10 ? ('0' + value) : String(value);
        }

        return pad(date.getHours()) + ':' +
            pad(date.getMinutes()) + ':' +
            pad(date.getSeconds());
    }

    function activatePanel(panel) {
        if (!isValidPanel(panel)) {
            return false;
        }

        var attempts = [
            function () { $.DispatchEvent('Activated', panel, 'mouse'); },
            function () { $.DispatchEvent('Activated', panel); },
            function () { $.DispatchEvent('Activated', panel, 'keyboard'); }
        ];

        for (var i = 0; i < attempts.length; i++) {
            try {
                attempts[i]();
                return true;
            } catch (error) {
                // Continue with the next supported Panorama signature.
            }
        }

        return false;
    }

    function findLanePreferenceOption(selector) {
        var root = $.DLTK.Core && $.DLTK.Core.getRoot
            ? $.DLTK.Core.getRoot()
            : null;
        var option = selector && selector.FindChildTraverse
            ? selector.FindChildTraverse(Config.targetLanePreference)
            : null;

        if (!option && root && root.FindChildTraverse) {
            option = root.FindChildTraverse(Config.targetLanePreference);
        }

        if (!option && selector && selector.FindChildrenWithClassTraverse) {
            var dropdownChildren = selector.FindChildrenWithClassTraverse('DropDownChild') || [];
            for (var i = 0; i < dropdownChildren.length; i++) {
                if (String(dropdownChildren[i].id || '') === Config.targetLanePreference) {
                    option = dropdownChildren[i];
                    break;
                }
            }
        }

        return isValidPanel(option) ? option : null;
    }

    function commitSelection(selector, option) {
        if (!isValidPanel(selector) || !selector.SetSelected) {
            return false;
        }

        try {
            selector.SetSelected(Config.targetLanePreference);
        } catch (errorSetSelected) {
            return false;
        }

        activatePanel(selector);

        if (option) {
            if (option.SetSelected) {
                try {
                    option.SetSelected(Config.targetLanePreference);
                } catch (errorOptionSelected) {
                    // The option can still be committed through Activated.
                }
            }

            activatePanel(option);
        }

        try {
            selector.SetSelected(Config.targetLanePreference);
            $.DispatchEvent('Activated', selector);
        } catch (errorFinalCommit) {
            return false;
        }

        return true;
    }

    function ensureWithParty(reason) {
        State.lastApplyAttemptAt = formatNow();

        if (!Config.enabled) {
            State.currentPreference = 'Unknown';
            State.lastResult = 'Disabled';
            State.verification = 'Unknown';
            State.lastStatus = 'Disabled';
            return true;
        }

        State.partyDetected = detectParty();
        var selector = findPanel('LanePreferenceSelector');
        State.nativeSelectorFound = isValidPanel(selector);
        State.currentPreference = State.nativeSelectorFound
            ? readCurrentPreference(selector)
            : 'Unknown';

        if (!State.partyDetected) {
            State.lastResult = 'Not attempted';
            State.verification = 'Unknown';
            State.lastStatus = reason === 'manual'
                ? 'Party not detected'
                : 'Waiting for party';
            return true;
        }

        if (!State.nativeSelectorFound) {
            State.lastResult = 'Failed';
            State.verification = 'Unknown';
            State.lastStatus = 'Waiting for Lane Preference selector';
            return false;
        }

        if (isWithPartySelected(selector)) {
            State.currentPreference = Config.targetLaneLabel;
            State.lastResult = 'Success';
            State.verification = 'Verified';
            State.lastStatus = 'With Party already selected';
            return true;
        }

        var option = findLanePreferenceOption(selector);
        if (!commitSelection(selector, option)) {
            State.lastResult = 'Failed';
            State.verification = 'Not verified';
            State.lastStatus = 'Apply failed; retrying';
            return false;
        }

        var selectedAfter = readSelectedOption(selector);
        State.currentPreference = selectedLabel(selectedAfter);

        if (isWithPartySelected(selector)) {
            State.currentPreference = Config.targetLaneLabel;
            State.lastAppliedAt = formatNow();
            State.lastResult = 'Success';
            State.verification = 'Verified';
            State.lastStatus = 'Applied With Party';
            return true;
        }

        State.lastResult = selectedAfter ? 'Failed' : 'Unknown';
        State.verification = selectedAfter ? 'Not verified' : 'Unknown';
        State.lastStatus = selectedAfter
            ? 'Apply failed; retrying'
            : 'Apply attempted; verification unknown';
        return false;
    }

    function scheduleRetries(reason) {
        State.retryToken++;
        var token = State.retryToken;
        var delays = Config.retryDelaysSeconds;

        for (var i = 0; i < delays.length; i++) {
            (function (delay, retryToken) {
                $.Schedule(delay, function () {
                    if (retryToken !== State.retryToken) {
                        return;
                    }

                    if (ensureWithParty(reason)) {
                        State.retryToken++;
                    }
                });
            })(delays[i], token);
        }
    }

    function registerPartyEvent() {
        if (State.eventRegistered || !$.RegisterForUnhandledEvent) {
            return;
        }

        try {
            $.RegisterForUnhandledEvent('party_updated', function () {
                State.lastPartyUpdatedAt = formatNow();
                scheduleRetries('party_updated');
            });
            State.eventRegistered = true;
        } catch (error) {
            State.lastStatus = 'Party event unavailable; polling';
        }
    }

    function applyNow() {
        if (!ensureWithParty('manual')) {
            scheduleRetries('manual');
        }
    }

    function setEnabled(enabled) {
        Config.enabled = !!enabled;

        if (!Config.enabled) {
            State.retryToken++;
            State.lastResult = 'Disabled';
            State.verification = 'Unknown';
            State.lastStatus = 'Disabled';
            State.currentPreference = 'Unknown';
        } else {
            scheduleRetries('enabled');
        }
    }

    function toggleEnabled() {
        setEnabled(!Config.enabled);
        return Config.enabled;
    }

    function onTick() {
        registerPartyEvent();

        var partyState = detectParty();
        State.partyDetected = partyState;

        if (State.lastPartyState !== partyState) {
            State.lastPartyState = partyState;
            scheduleRetries('party state changed');
        }

        var now = Date.now ? Date.now() : (new Date()).getTime();
        if (partyState && now >= State.nextFallbackAt) {
            State.nextFallbackAt = now + (Config.fallbackPollSeconds * 1000);
            scheduleRetries('fallback poll');
        }
    }

    $.DLTK.Modules.Party = {
        onTick: onTick,
        isEnabled: function () { return Config.enabled; },
        setEnabled: setEnabled,
        toggleEnabled: toggleEnabled,
        applyNow: applyNow,
        ensureWithParty: ensureWithParty,
        isPartyDetected: function () { return State.partyDetected; },
        hasNativeSelector: function () { return State.nativeSelectorFound; },
        getCurrentPreference: function () { return State.currentPreference; },
        getDesiredPreference: function () { return Config.targetLaneLabel; },
        getLastPartyUpdatedAt: function () { return State.lastPartyUpdatedAt; },
        getLastApplyAttemptAt: function () { return State.lastApplyAttemptAt; },
        getLastResult: function () { return State.lastResult; },
        getVerification: function () { return State.verification; },
        getStatus: function () { return State.lastStatus; },
        getLastAppliedAt: function () {
            return State.lastAppliedAt || 'Never';
        }
    };

    if ($.DLTK.Core && $.DLTK.Core.registerModule) {
        $.DLTK.Core.registerModule('Party', $.DLTK.Modules.Party);
    } else {
        $.Warning('[DLTK] Core was not ready when Party module loaded.\n');
    }
})();
