(function () {
    'use strict';
    if (!$.DLTK) { $.DLTK = {}; }
    if (!$.DLTK.Modules) { $.DLTK.Modules = {}; }
    if ($.DLTK.Modules.Party) { return; }
    var Config = $.DLTK.Config.party;
    var ContextPanel = $.GetContextPanel();
    var S = {
        partyDetected: false,
        lastPartyUpdatedAt: 'Never',
        status: 'Waiting for party state', startupDone: false,
        applyInProgress: false, selectorSearchPending: false,
        partyEventDebouncePending: false, applySequence: 0,
        lastTrigger: 'Never', lastResult: 'Not applied'
    };
    function valid(p) { return !!(p && p.IsValid && p.IsValid()); }
    function id(p) { return valid(p) ? String(p.id || '') : ''; }
    function type(p) {
        if (!valid(p)) { return 'invalid'; }
        try { return String(p.paneltype || (p.GetPanelType && p.GetPanelType()) || 'Panel'); }
        catch (e) { return 'unknown'; }
    }
    function log(s) { $.Msg('[DLTK][Party] ' + s); }
    function top() {
        var p = ContextPanel, i = 0;
        while (valid(p) && p.GetParent && valid(p.GetParent()) && i++ < 50) { p = p.GetParent(); }
        return p;
    }
    function root() { return $.DLTK.Core && $.DLTK.Core.getRoot ? $.DLTK.Core.getRoot() : null; }
    function find(idToFind) {
        var a = top(), b = root();
        return (valid(a) && a.FindChildTraverse && a.FindChildTraverse(idToFind)) ||
            (valid(b) && b.FindChildTraverse && b.FindChildTraverse(idToFind)) || null;
    }
    function classInChain(p, name) {
        for (var i = 0; valid(p) && i < 20; i++) {
            if (p.BHasClass && p.BHasClass(name)) { return true; }
            p = p.GetParent ? p.GetParent() : null;
        }
        return false;
    }
    function detectParty() {
        var a = top(), b = root();
        if (classInChain(a, 'localPlayerInParty') || classInChain(b, 'localPlayerInParty')) { return true; }
        if (valid(a) && a.FindChildrenWithClassTraverse &&
            (a.FindChildrenWithClassTraverse('localPlayerInParty') || []).length) { return true; }
        if (valid(b) && b.FindChildrenWithClassTraverse &&
            (b.FindChildrenWithClassTraverse('localPlayerInParty') || []).length) { return true; }
        var members = find('PartyMembersList');
        try { return valid(members) && members.GetChildCount && members.GetChildCount() > 0; }
        catch (e) { return false; }
    }
    function clock() {
        var d = new Date();
        function pad(n) { return n < 10 ? '0' + n : String(n); }
        return pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
    }
    function chain(p) {
        var parts = [];
        for (var i = 0; valid(p) && i < 12; i++) {
            parts.push(type(p) + (id(p) ? '#' + id(p) : ''));
            p = p.GetParent ? p.GetParent() : null;
        }
        return parts.join(' < ');
    }
    function visible(p) { try { return valid(p) && p.visible !== false; } catch (e) { return false; } }
    function selectedDetails(p) {
        if (!valid(p) || typeof p.GetSelected !== 'function') {
            return { id: 'unavailable', value: 'unavailable' };
        }
        try {
            var selectedPanel = p.GetSelected();
            if (!valid(selectedPanel)) { return { id: 'none', value: 'none' }; }
            var value = typeof selectedPanel.GetAttributeString === 'function'
                ? String(selectedPanel.GetAttributeString('value', ''))
                : 'unavailable';
            return { id: id(selectedPanel) || 'none', value: value || 'empty' };
        } catch (e) {
            return { id: 'error', value: String(e) };
        }
    }
    function allPanels() {
        var stack = [], seen = [], a = top(), b = root();
        if (valid(a)) { stack.push(a); }
        if (valid(b) && b !== a) { stack.push(b); }
        while (stack.length && seen.length < 20000) {
            var panel = stack.pop();
            if (!valid(panel) || seen.indexOf(panel) >= 0) { continue; }
            seen.push(panel);
            if (panel.GetChildCount && panel.GetChild) {
                try {
                    var childCount = panel.GetChildCount();
                    for (var i = 0; i < childCount; i++) { stack.push(panel.GetChild(i)); }
                } catch (e) { /* Some native branches do not expose children. */ }
            }
        }
        return seen;
    }
    function selectorCandidates() {
        var panels = allPanels(), candidates = [];
        for (var i = 0; i < panels.length; i++) {
            if (id(panels[i]) === 'LanePreferenceSelector') { candidates.push(panels[i]); }
        }
        return candidates;
    }
    function stockPartyAncestry(panel) {
        var p = panel, hasCitadelParty = false, hasPartyList = false, parts = [];
        for (var i = 0; valid(p) && i < 20; i++) {
            var panelType = type(p), panelId = id(p), classes = [];
            if (panelType.toLowerCase() === 'citadelparty' || panelId === 'CitadelParty') {
                hasCitadelParty = true;
            }
            if (p.BHasClass && p.BHasClass('PartyList')) {
                hasPartyList = true;
                classes.push('PartyList');
            }
            parts.push(panelType + (panelId ? '#' + panelId : '') +
                (classes.length ? '.' + classes.join('.') : ''));
            p = p.GetParent ? p.GetParent() : null;
        }
        return { valid: hasCitadelParty && hasPartyList, chain: parts.join(' < ') };
    }
    function isDescendantOf(panel, ancestor) {
        for (var i = 0; valid(panel) && i < 30; i++) {
            if (panel === ancestor) { return true; }
            panel = panel.GetParent ? panel.GetParent() : null;
        }
        return false;
    }
    function findStockJoinCreateParty() {
        var panels = allPanels(), buttonCandidates = [], validated = [];
        var partyRoots = [], partyLists = [];
        for (var i = 0; i < panels.length; i++) {
            var panel = panels[i], panelType = type(panel);
            if (panelType.toLowerCase() === 'citadelparty' || id(panel) === 'CitadelParty') {
                partyRoots.push(panel);
            }
            if (panel.BHasClass && panel.BHasClass('PartyList')) { partyLists.push(panel); }
            if (id(panel) === 'JoinCreateParty') {
                var ancestry = stockPartyAncestry(panel);
                var isButton = panelType.toLowerCase() === 'button';
                buttonCandidates.push({ panel: panel, ancestry: ancestry, isButton: isButton });
                log('JoinCreateParty candidate #' + buttonCandidates.length +
                    ' type=' + panelType +
                    ' stock ancestry=' + (ancestry.valid ? 'yes' : 'no') +
                    ' button=' + (isButton ? 'yes' : 'no') +
                    ' chain=' + ancestry.chain);
                if (ancestry.valid && isButton) { validated.push(panel); }
            }
        }
        if (validated.length === 1) {
            log('stock JoinCreateParty found');
            return validated[0];
        }
        if (validated.length > 1) {
            log('stock JoinCreateParty ambiguous validated candidates=' + validated.length);
            return null;
        }
        log('stock JoinCreateParty not found in validated CitadelParty / PartyList context');
        log('CitadelParty candidates=' + partyRoots.length +
            ' PartyList candidates=' + partyLists.length +
            ' JoinCreateParty id candidates=' + buttonCandidates.length);
        for (var r = 0; r < partyRoots.length; r++) {
            var descendants = [];
            for (var d = 0; d < panels.length; d++) {
                if (isDescendantOf(panels[d], partyRoots[r])) {
                    descendants.push(type(panels[d]) + (id(panels[d]) ? '#' + id(panels[d]) : ''));
                }
            }
            log('CitadelParty candidate #' + (r + 1) +
                ' descendant panels=' + descendants.length +
                ' sample=[' + descendants.slice(0, 40).join(', ') + ']');
        }
        return null;
    }
    function getNativePopup(panel) {
        for (var i = 0; valid(panel) && i < 20; i++) {
            if (type(panel).toLowerCase() === 'popupjoinorcreateparty') { return panel; }
            panel = panel.GetParent ? panel.GetParent() : null;
        }
        return null;
    }
    function refreshSettings() {
        if ($.DLTK.UI && typeof $.DLTK.UI.refresh === 'function') {
            $.DLTK.UI.refresh();
        }
    }
    function setStatus(status, result) {
        S.status = status;
        if (result) { S.lastResult = result; }
        refreshSettings();
    }
    function finishApply(sequence, success, result) {
        if (sequence !== S.applySequence) { return; }
        S.applyInProgress = false;
        S.selectorSearchPending = false;
        setStatus(success ? 'Ready' : 'Apply failed', S.lastTrigger + ': ' + result);
    }
    function findStockPopupCloseButton(popup) {
        if (!valid(popup) || type(popup).toLowerCase() !== 'popupjoinorcreateparty') { return null; }
        var stack = [], seen = [], candidates = [];
        function actualPanelType(panel) {
            try {
                if (typeof panel.paneltype === 'string' && panel.paneltype) { return panel.paneltype; }
                if (typeof panel.GetPanelType === 'function') {
                    var panelType = panel.GetPanelType();
                    if (panelType !== null && panelType !== undefined && String(panelType)) {
                        return String(panelType);
                    }
                }
            } catch (e) { /* Panel type is optional on some Panorama wrappers. */ }
            return null;
        }
        if (popup.GetChildCount && popup.GetChild) {
            try {
                for (var i = 0; i < popup.GetChildCount(); i++) { stack.push(popup.GetChild(i)); }
            } catch (e) { return null; }
        }
        while (stack.length && seen.length < 5000) {
            var panel = stack.pop();
            if (!valid(panel) || seen.indexOf(panel) >= 0) { continue; }
            seen.push(panel);
            if (id(panel) === 'EscapeButton' && getNativePopup(panel) === popup) {
                var panelType = actualPanelType(panel);
                if (panelType && panelType.toLowerCase() !== 'citadelbindingbutton') {
                    log('stock EscapeButton candidate rejected type=' + panelType +
                        '; expected CitadelBindingButton');
                } else {
                    candidates.push(panel);
                    log('stock close button found type=' + (panelType || 'unavailable'));
                }
            }
            if (panel.GetChildCount && panel.GetChild) {
                try {
                    for (var j = 0; j < panel.GetChildCount(); j++) { stack.push(panel.GetChild(j)); }
                } catch (e2) { /* Continue validating other popup descendants. */ }
            }
        }
        if (candidates.length > 1) {
            log('popup close lookup failed: ambiguous validated EscapeButton count=' + candidates.length);
            return null;
        }
        if (candidates.length === 0) {
            log('popup close lookup failed: EscapeButton not found in PopupJoinOrCreateParty');
            return null;
        }
        return candidates[0];
    }
    function closeStockPopupAfterApply(popup, sequence, result) {
        if (sequence !== S.applySequence || !S.applyInProgress) { return; }
        if (!valid(popup) || !visible(popup)) {
            log('popup already closed');
            finishApply(sequence, true, result + '; stock popup closed');
            return;
        }
        log('popup close start');
        var closeButton = findStockPopupCloseButton(popup);
        if (!valid(closeButton)) {
            log('popup close failed: no validated EscapeButton; leaving popup open');
            finishApply(sequence, true, result + '; popup remains open (stock close button not found)');
            return;
        }
        try {
            $.DispatchEvent('Activated', closeButton, 'mouse');
            log('popup close via EscapeButton');
        } catch (e) {
            log('popup close failed: EscapeButton activation threw: ' + String(e) + '; leaving popup open');
            finishApply(sequence, true, result + '; popup remains open (close activation failed)');
            return;
        }
        $.Schedule(0.2, function () {
            if (sequence !== S.applySequence || !S.applyInProgress) { return; }
            if (!valid(popup) || !visible(popup)) {
                log('popup closed');
                finishApply(sequence, true, result + '; stock popup closed');
            } else {
                log('popup close failed: stock popup still visible; leaving popup open');
                finishApply(sequence, true, result + '; popup remains open (close not confirmed)');
            }
        });
    }
    function attemptNativeSelector(sequence, attemptIndex) {
        if (sequence !== S.applySequence || !S.applyInProgress || !S.selectorSearchPending) { return; }
        var candidates = selectorCandidates(), nativeCandidates = [];
        for (var i = 0; i < candidates.length; i++) {
            var popup = getNativePopup(candidates[i]);
            if (popup) { nativeCandidates.push({ selector: candidates[i], popup: popup }); }
        }
        if (nativeCandidates.length === 1) {
            S.selectorSearchPending = false;
            var selector = nativeCandidates[0].selector;
            var popupPanel = nativeCandidates[0].popup;
            var before = selectedDetails(selector);
            log('stock popup opened');
            log('stock selector found');
            log('before=' + before.id);
            if (before.id !== 'lanepreference_1') {
                if (typeof selector.SetSelected !== 'function') {
                    finishApply(sequence, false, 'Stock selector has no SetSelected method');
                    return;
                }
                try {
                    selector.SetSelected('lanepreference_1');
                    log('SetSelected(lanepreference_1) called');
                } catch (e) {
                    finishApply(sequence, false, 'SetSelected failed: ' + String(e));
                    return;
                }
            } else {
                log('already selected lanepreference_1; no change needed');
            }
            var outcome = before.id === 'lanepreference_1'
                ? 'With Party was already selected'
                : 'SetSelected(lanepreference_1) called';
            $.Schedule(0.2, function () {
                closeStockPopupAfterApply(popupPanel, sequence, outcome);
            });
            return;
        }
        if (attemptIndex >= 5) {
            S.selectorSearchPending = false;
            var failure = nativeCandidates.length
                ? 'ambiguous stock selector count=' + nativeCandidates.length
                : 'selector not found';
            log('apply failed: ' + failure);
            finishApply(sequence, false, failure + '; popup left open');
        }
    }
    function applyWithPartyViaNativePopup(reason) {
        if (S.applyInProgress) {
            log('apply ignored; another apply is in progress');
            return false;
        }
        S.applyInProgress = true;
        S.selectorSearchPending = true;
        var sequence = ++S.applySequence;
        S.lastTrigger = reason;
        log('apply start reason=' + reason);
        setStatus('Opening Party Settings', 'Started: ' + reason);
        var joinCreatePartyPanel = findStockJoinCreateParty();
        if (!valid(joinCreatePartyPanel)) {
            log('apply failed: validated stock JoinCreateParty not found');
            finishApply(sequence, false, 'validated stock JoinCreateParty not found');
            return false;
        }
        try {
            $.DispatchEvent("Activated", joinCreatePartyPanel, "mouse");
            log('$.DispatchEvent("Activated", JoinCreateParty, "mouse") called');
        } catch (e) {
            log('apply failed: JoinCreateParty activation threw: ' + String(e));
            finishApply(sequence, false, 'JoinCreateParty activation failed');
            return false;
        }
        var retryOffsets = [0, 0.1, 0.25, 0.5, 1, 2];
        attemptNativeSelector(sequence, 0);
        for (var i = 1; i < retryOffsets.length; i++) {
            (function (attempt) {
                $.Schedule(retryOffsets[attempt], function () {
                    attemptNativeSelector(sequence, attempt);
                });
            })(i);
        }
        return true;
    }
    function onPartyUpdated() {
        S.lastPartyUpdatedAt = clock();
        if (!Config.enabled || S.partyEventDebouncePending) { return; }
        S.partyEventDebouncePending = true;
        log('party_updated received; coalescing for 400ms');
        $.Schedule(0.4, function () {
            S.partyEventDebouncePending = false;
            S.partyDetected = detectParty();
            if (Config.enabled && S.partyDetected) {
                applyWithPartyViaNativePopup('party_updated');
            } else {
                refreshSettings();
            }
        });
    }
    function registerPartyUpdated() {
        if (typeof GameEvents === 'undefined' || !GameEvents ||
            typeof GameEvents.Subscribe !== 'function') {
            log('party_updated subscription unavailable; automatic event apply disabled');
            return;
        }
        try {
            GameEvents.Subscribe('party_updated', onPartyUpdated);
            log('party_updated subscribed via GameEvents.Subscribe');
        } catch (e) {
            log('party_updated subscription failed: ' + String(e));
        }
    }
    function toggleEnabled() {
        Config.enabled = !Config.enabled;
        if (Config.enabled) {
            setStatus('Automatic apply ON', 'Enabled; waiting for party_updated or Apply now');
        } else {
            setStatus('Automatic apply OFF', 'Disabled by user');
        }
        return Config.enabled;
    }
    function applyNow() {
        return applyWithPartyViaNativePopup('manual');
    }
    function onTick() {
        if (S.startupDone) { return; }
        S.startupDone = true;
        S.partyDetected = detectParty();
        log('party detected=' + S.partyDetected);
        if (Config.enabled && S.partyDetected) {
            applyWithPartyViaNativePopup('startup');
        } else if (!Config.enabled) {
            setStatus('Automatic apply OFF', 'Disabled by user');
        } else {
            setStatus('Waiting for party', 'Startup apply skipped; no party detected');
        }
    }
    $.DLTK.Modules.Party = {
        onTick: onTick,
        toggleEnabled: toggleEnabled,
        applyNow: applyNow,
        isEnabled: function () { return !!Config.enabled; },
        isPartyDetected: function () { return S.partyDetected; },
        getLastPartyUpdatedAt: function () { return S.lastPartyUpdatedAt; },
        getLastResult: function () { return S.lastResult; },
        getStatus: function () { return S.status; }
    };
    registerPartyUpdated();
    if ($.DLTK.Core && $.DLTK.Core.registerModule) {
        $.DLTK.Core.registerModule('Party', $.DLTK.Modules.Party);
    } else { $.Warning('[DLTK] Core was not ready when Party module loaded.\n'); }
})();
