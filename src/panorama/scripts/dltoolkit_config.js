(function () {
    'use strict';

    if (!$.DLTK) {
        $.DLTK = {};
    }

    if ($.DLTK.Config) {
        return;
    }

    $.DLTK.Config = {
        version: '0.1.0',

        core: {
            pollRateActive: 0.10,
            pollRateIdle: 1.00
        },

        sounds: {
            customRuneWarning: {
                name: 'Custom sound',
                event: 'DLTK.Rune.Warning'
            }
        },

        runes: {
            enabled: true,
            firstSpawnSeconds: 300,
            intervalSeconds: 300,
            warningLeadSeconds: 30,
            alertWindowSeconds: 3,
            minLeadSeconds: 5,
            maxLeadSeconds: 90,
            leadStepSeconds: 5
        },

        party: {
            enabled: true,
            targetLanePreference: 'lanepreference_1',
            targetLaneLabel: 'With Party',
            retryDelaysSeconds: [0.25, 1.00, 2.00],
            fallbackPollSeconds: 5.00
        },

        ui: {
            defaultTab: 'runes'
        }
    };

    $.DLTK.Sounds = {
        getCustomRuneWarning: function () {
            return $.DLTK.Config.sounds.customRuneWarning;
        }
    };
})();
