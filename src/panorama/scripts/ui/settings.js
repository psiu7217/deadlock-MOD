(function () {
    'use strict';

    if (!$.DLTK) {
        $.DLTK = {};
    }
    if ($.DLTK.UI) {
        return;
    }

    var State = { open: false };

    function getPanel(id) {
        var context = $.GetContextPanel();
        return context && context.FindChildTraverse
            ? context.FindChildTraverse(id)
            : null;
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

    function open() {
        setHidden(getPanel('DLToolkitSettings'), false);
        State.open = true;
        refresh();
    }

    function close() {
        setHidden(getPanel('DLToolkitSettings'), true);
        State.open = false;
    }

    function toggleRunes() {
        if ($.DLTK.Modules && $.DLTK.Modules.Runes) {
            $.DLTK.Modules.Runes.toggleEnabled();
            refresh();
        }
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

    function refresh() {
        if (!State.open || !$.DLTK.Modules || !$.DLTK.Modules.Runes) {
            return;
        }

        var runes = $.DLTK.Modules.Runes;
        var currentTime = $.DLTK.Core ? $.DLTK.Core.getCurrentTime() : null;
        refreshEnabledState(runes);

        setText('DLTKGameTimeValue', runes.formatTime(currentTime));

        var upcoming = runes.getUpcoming(currentTime);
        setText('DLTKNextRuneValue', currentTime === null
            ? '--:--'
            : runes.formatTime(upcoming.spawn));

        var nextWarning = runes.getNextWarning(currentTime);
        var warningText = currentTime === null
            ? '--:--'
            : (nextWarning.active
                ? 'NOW'
                : runes.formatTime(Math.max(0, nextWarning.alert - currentTime)));
        setText('DLTKNextWarningValue', warningText);
        setText('DLTKRuneStatusValue', runes.isEnabled() ? 'Enabled' : 'Disabled');
    }

    $.DLTK.UI = {
        open: open,
        close: close,
        toggleRunes: toggleRunes,
        refresh: refresh,
        isOpen: function () { return State.open; }
    };

    $.Msg('[DLTK][Runes] UI initialized\n');
})();
