"""Skill XP rules shared with the iOS app."""
import copy
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
import skills as sk  # noqa: E402


def night(d, met=True, verified=False, minutes=460):
    return {"date": d, "minutes": minutes, "goalMet": met, "verified": verified}


def test_hitpoints_starts_at_level_ten():
    assert sk.levels({})["hitpoints"] == 10


def test_sleep_run_ramps_and_caps():
    nights = [night(f"2026-09-{d:02d}") for d in range(1, 11)]
    # 60, 80, 100, 120, 140, 160, 180, 200, 200, 200
    assert sk.sleep_xp(nights) == 1440
    assert sk.current_sleep_run(nights) == 10


def test_sleep_miss_resets_run_not_xp():
    nights = [night("2026-09-01"), night("2026-09-02"), night("2026-09-03", met=False), night("2026-09-04")]
    assert sk.sleep_xp(nights) == 60 + 80 + 60
    assert sk.current_sleep_run(nights) == 1
    nights.append(night("2026-09-05", met=False))
    assert sk.current_sleep_run(nights) == 0


def test_gap_in_dates_breaks_run():
    nights = [night("2026-09-01"), night("2026-09-03")]
    assert sk.sleep_xp(nights) == 120


def test_strength_xp_counts_sets_and_targets():
    data = {"exercises": [{"id": "a", "weeklySets": 2}],
            "weeks": [{"days": [{"entries": {"a": {"sets": [{"reps": 12}, {"reps": 10}]}}}]}]}
    assert sk.strength_xp(data) == (10 + 12) + (10 + 10) + 100


def test_hitpoints_takes_a_third_of_combat():
    data = {"exercises": [{"id": "a", "weeklySets": 9}],
            "weeks": [{"days": [{"entries": {"a": {"sets": [{"reps": 20}]}}}]}],
            "skills": {"meals": [{}], "cooks": [{"tier": "exotic", "healthy": True}]}}
    assert sk.strength_xp(data) == 30
    assert sk.hitpoints_xp(data) == 1154 + 40 + 40 + 30 // 3
    assert sk.xp("cooking", data) == 210


def test_merge_nights_idempotent_and_keeps_verified():
    data = {"skills": {"nights": [night("2026-09-01", verified=False), night("2026-09-02", met=False, verified=True)]}}
    verified = [{"date": "2026-09-01", "minutes": 300, "goalMet": False}]
    out, events = sk.merge_nights(copy.deepcopy(data), verified)
    assert [e["date"] for e in events] == ["2026-09-01"] and events[0]["wasClaimed"]
    assert out["skills"]["nights"][0] == {"date": "2026-09-01", "minutes": 300, "goalMet": False, "verified": True}
    again, events2 = sk.merge_nights(copy.deepcopy(out), verified)
    assert again == out and events2 == []
