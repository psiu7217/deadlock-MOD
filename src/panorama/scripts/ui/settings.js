(function () {
    'use strict';

    if (!$.DLTK) {
        $.DLTK = {};
    }

    if ($.DLTK.UI) {
        return;
    }

    var State = {
        open: false,
        selectedTab: $.DLTK.Config.ui.defaultTab || 'runes'
    };

    function getPanel(id) {
        var context = $.GetContextPanel();
        if (!context || !context.FindChildTraverse) {
            return null;
        }

        return context.FindChildTraverse(id);
    }

    function isValidPanel(panel) {
        return !!(panel && panel.IsValid && panel.IsValid());
    }

    function setText(id, value) {
        var panel = getPanel(id);

        if (isValidPanel(panel)) {
            panel.text = String(value);
        }
    }

    function setHidden(panel, hidden) {
        if (!isValidPanel(panel)) {
            return;
        }

        if (hidden) {
            panel.AddClass('DLTKHidden');
        } else {
            panel.RemoveClass('DLTKHidden');
        }
    }

    function setSelected(button, selected) {
        if (!isValidPanel(button)) {
            return;
        }

        if (selected) {
            button.AddClass('DLTKTabSelected');
        } else {
            button.RemoveClass('DLTKTabSelected');
        }
    }

    function open() {
        var settings = getPanel('DLToolkitSettings');
        setHidden(settings, false);
        State.open = true;
        selectTab(State.selectedTab);
    }

    function close() {
        var settings = getPanel('DLToolkitSettings');
        setHidden(settings, true);
        State.open = false;
    }

    function toggle() {
        if (State.open) {
            close();
        } else {
            open();
        }
    }

    function selectTab(tabName) {
        var runesButton = getPanel('DLTKTabRunes');
        var partyButton = getPanel('DLTKTabParty');
        var aboutButton = getPanel('DLTKTabAbout');
        var runesPage = getPanel('DLTKPageRunes');
        var partyPage = getPanel('DLTKPageParty');
        var aboutPage = getPanel('DLTKPageAbout');

        if (tabName === 'party') {
            State.selectedTab = 'party';
        } else if (tabName === 'about') {
            State.selectedTab = 'about';
        } else {
            State.selectedTab = 'runes';
        }

        var runesSelected = State.selectedTab === 'runes';
        var partySelected = State.selectedTab === 'party';

        setSelected(runesButton, runesSelected);
        setSelected(partyButton, partySelected);
        setSelected(aboutButton, !runesSelected && !partySelected);

        setHidden(runesPage, !runesSelected);
        setHidden(partyPage, !partySelected);
        setHidden(aboutPage, runesSelected || partySelected);
    }

    function toggleRunes() {
        if (!$.DLTK.Modules || !$.DLTK.Modules.Runes) {
            return;
        }

        $.DLTK.Modules.Runes.toggleEnabled();
        refresh();
    }

    function adjustRuneLead(delta) {
        if (!$.DLTK.Modules || !$.DLTK.Modules.Runes) {
            return;
        }

        $.DLTK.Modules.Runes.adjustWarningLead(delta);
        refresh();
    }

    function testRuneSound() {
        if (!$.DLTK.Modules || !$.DLTK.Modules.Runes) {
            return;
        }

        $.DLTK.Modules.Runes.testSound();
    }

    function testKnownGoodSound() {
        if (!$.DLTK.Modules || !$.DLTK.Modules.Runes) {
            return;
        }

        $.DLTK.Modules.Runes.testKnownGoodSound();
    }

    function toggleParty() {
        if (!$.DLTK.Modules || !$.DLTK.Modules.Party) {
            return;
        }

        $.DLTK.Modules.Party.toggleEnabled();
        refresh();
    }

    function applyPartyNow() {
        if (!$.DLTK.Modules || !$.DLTK.Modules.Party) {
            return;
        }

        $.DLTK.Modules.Party.applyNow();
        refresh();
    }

    function refreshEnabledState(runes) {
        var enabled = runes.isEnabled();
        var button = getPanel('DLTKRuneEnabledButton');

        setText('DLTKRuneEnabledValue', enabled ? 'ON' : 'OFF');

        if (!isValidPanel(button)) {
            return;
        }

        if (enabled) {
            button.RemoveClass('DLTKOff');
        } else {
            button.AddClass('DLTKOff');
        }
    }

    function refreshPartyEnabledState(party) {
        var enabled = party.isEnabled();
        var button = getPanel('DLTKPartyEnabledButton');

        setText('DLTKPartyEnabledValue', enabled ? 'ON' : 'OFF');

        if (!isValidPanel(button)) {
            return;
        }

        if (enabled) {
            button.RemoveClass('DLTKOff');
        } else {
            button.AddClass('DLTKOff');
        }
    }

    function refresh() {
        if (!State.open) {
            return;
        }

        if (!$.DLTK.Modules || !$.DLTK.Modules.Runes || !$.DLTK.Modules.Party) {
            return;
        }

        var runes = $.DLTK.Modules.Runes;
        var party = $.DLTK.Modules.Party;
        var currentTime = $.DLTK.Core
            ? $.DLTK.Core.getCurrentTime()
            : null;

        refreshEnabledState(runes);
        refreshPartyEnabledState(party);

        setText(
            'DLTKRuneLeadValue',
            runes.getWarningLead() + ' sec'
        );

        setText(
            'DLTKRuneSoundValue',
            runes.getSoundLabel()
        );

        setText(
            'DLTKRuneSoundEvent',
            runes.getSoundEvent()
        );

        setText(
            'DLTKGameTimeValue',
            runes.formatTime(currentTime)
        );

        var upcoming = runes.getUpcoming(currentTime);

        setText(
            'DLTKNextRuneValue',
            runes.formatTime(upcoming.spawn)
        );

        setText(
            'DLTKNextWarningValue',
            runes.formatTime(upcoming.alert)
        );

        setText(
            'DLTKRuneStatusValue',
            runes.getStatus()
        );

        setText(
            'DLTKPartyStatusValue',
            party.getStatus()
        );

        setText(
            'DLTKPartyDetectedValue',
            party.isPartyDetected() ? 'Yes' : 'No'
        );

        setText(
            'DLTKPartySelectorValue',
            party.hasNativeSelector() ? 'Yes' : 'No'
        );

        setText(
            'DLTKPartyCurrentValue',
            party.getCurrentPreference()
        );

        setText(
            'DLTKPartyDesiredValue',
            party.getDesiredPreference()
        );

        setText(
            'DLTKPartyLastEventValue',
            party.getLastPartyUpdatedAt()
        );

        setText(
            'DLTKPartyLastAttemptValue',
            party.getLastApplyAttemptAt()
        );

        setText(
            'DLTKPartyResultValue',
            party.getLastResult()
        );

        setText(
            'DLTKPartyVerificationValue',
            party.getVerification()
        );
    }

    $.DLTK.UI = {
        open: open,
        close: close,
        toggle: toggle,
        selectTab: selectTab,
        toggleRunes: toggleRunes,
        adjustRuneLead: adjustRuneLead,
        testRuneSound: testRuneSound,
        testKnownGoodSound: testKnownGoodSound,
        toggleParty: toggleParty,
        applyPartyNow: applyPartyNow,
        refresh: refresh,

        isOpen: function () {
            return State.open;
        }
    };
})();
