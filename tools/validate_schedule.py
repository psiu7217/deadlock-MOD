#!/usr/bin/env python3
"""
Engine-independent tests for the v0.1 rune schedule.
This does not test Panorama or Deadlock; it only verifies timing math.
"""

FIRST_SPAWN = 300
INTERVAL = 300
LEAD = 30


def expected_alerts(count=8):
    return [
        FIRST_SPAWN - LEAD + (i * INTERVAL)
        for i in range(count)
    ]


def fmt(seconds: int) -> str:
    minutes, sec = divmod(seconds, 60)
    return f"{minutes:02d}:{sec:02d}"


def upcoming(current_time: int):
    first_alert = FIRST_SPAWN - LEAD

    if current_time < first_alert:
        cycle = 0
    else:
        cycle = (current_time - first_alert) // INTERVAL

    spawn = FIRST_SPAWN + cycle * INTERVAL
    alert = first_alert + cycle * INTERVAL

    if current_time >= spawn:
        cycle += 1
        spawn = FIRST_SPAWN + cycle * INTERVAL
        alert = first_alert + cycle * INTERVAL

    return alert, spawn


def simulated_alerts(samples):
    """Mirror the module's one-shot trigger guard for deterministic tests."""
    last_alert_target = -1
    last_observed_time = None
    fired = []

    for current_time in samples:
        if (
            last_observed_time is not None
            and current_time < last_observed_time - 2
        ):
            last_alert_target = -1

        last_observed_time = current_time
        first_alert = FIRST_SPAWN - LEAD
        if current_time < first_alert:
            continue

        cycle = (current_time - first_alert) // INTERVAL
        target_alert = first_alert + cycle * INTERVAL
        inside_window = target_alert <= current_time < target_alert + 3

        if inside_window and last_alert_target != target_alert:
            fired.append(target_alert)
            last_alert_target = target_alert

    return fired


def main():
    alerts = expected_alerts(6)
    assert alerts == [270, 570, 870, 1170, 1470, 1770]

    assert upcoming(0) == (270, 300)
    assert upcoming(269) == (270, 300)
    assert upcoming(270) == (270, 300)
    assert upcoming(299) == (270, 300)
    assert upcoming(300) == (570, 600)
    assert upcoming(569) == (570, 600)
    assert upcoming(570) == (570, 600)

    assert simulated_alerts([269, 270, 270.5, 271, 272.9, 273]) == [270]
    assert simulated_alerts([570, 570.5, 571, 572.9, 870]) == [570, 870]
    assert simulated_alerts([270, 271, 100, 270]) == [270, 270]

    print("Rune schedule validation: PASS")
    print("First alerts:", ", ".join(fmt(x) for x in alerts))


if __name__ == "__main__":
    main()
