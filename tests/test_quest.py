"""Rules shared with the iOS app: the plan, the XP table, Fitbit matching."""
import copy
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
import quest as q  # noqa: E402

NOW = datetime(2026, 9, 24, 6, 0, tzinfo=timezone.utc)
CST = timezone(timedelta(hours=-5))


def session(id, w, d, start, elapsed, completed):
    return {"id": id, "week": w, "day": d, "startedAt": q.iso(start), "endedAt": q.iso(start + timedelta(seconds=elapsed)),
            "elapsedSeconds": elapsed, "jogSecondsDone": 0, "completed": completed}


def activity(logid, name, start, minutes, very=5, fairly=6, hr=128):
    return {"logId": logid, "activityName": name, "startTime": start.astimezone(CST).strftime("%Y-%m-%dT%H:%M:%S.000-05:00"),
            "duration": minutes * 60000, "distance": 2.4, "averageHeartRate": hr,
            "activityLevel": [{"name": "sedentary", "minutes": 1}, {"name": "lightly", "minutes": max(0, minutes - 1 - fairly - very)},
                              {"name": "fairly", "minutes": fairly}, {"name": "very", "minutes": very}]}


def test_plan_shape():
    assert len(q.all_sessions()) == 27
    assert q.total_seconds(1, 1) == 1800 and q.jog_seconds(1, 1) == 480
    assert q.jog_seconds(5, 3) == 1200 and q.jog_seconds(9, 3) == 1800
    for w, d in q.all_sessions():
        segs = q.plan_session(w, d)
        assert segs[0] == q.WARMUP and segs[-1] == q.COOLDOWN
        assert all(s > 0 for _, s in segs)


def test_osrs_xp_table():
    # Known values from the OSRS experience table.
    assert q.xp_for_level(2) == 83
    assert q.xp_for_level(10) == 1154
    assert q.xp_for_level(50) == 101333
    assert q.xp_for_level(99) == 13034431
    assert q.level_for_xp(0) == 1 and q.level_for_xp(82) == 1 and q.level_for_xp(83) == 2
    assert q.level_for_xp(13034431) == 99


def test_xp_rules():
    s = {"id": "x", "week": 1, "day": 1, "startedAt": q.iso(NOW), "elapsedSeconds": 200, "completed": False}
    assert q.xp_for_session(s) == 0
    s["elapsedSeconds"] = 300
    assert q.xp_for_session(s) == q.BOOTS_ON_XP
    s["completed"] = True
    assert q.xp_for_session(s) == q.BOOTS_ON_XP + q.COMPLETE_XP
    s["verification"] = {"activeMinutes": 10}
    assert q.xp_for_session(s) == q.BOOTS_ON_XP + q.COMPLETE_XP + q.VERIFIED_XP + 10 * q.ACTIVE_MINUTE_XP
    free = {"id": "free-1", "startedAt": q.iso(NOW), "elapsedSeconds": 900, "completed": False, "verification": {"activeMinutes": 4}}
    assert q.xp_for_session(free) == q.FREE_RUN_XP + 4 * q.ACTIVE_MINUTE_XP


def test_full_plan_lands_around_level_fifty():
    quest = {"sessions": [dict(session(f"s{w}{d}", w, d, NOW, 1800, True), verification={"activeMinutes": 20})
                          for w, d in q.all_sessions()]}
    assert 48 <= q.level_for_xp(q.total_xp(quest)) <= 55


def test_match_prefers_overlap_and_ignores_bikes():
    t0 = NOW - timedelta(days=3)
    data = {"quest": {"plan": "c25k", "sessions": [session("a", 1, 1, t0, 1800, True), session("b", 1, 2, t0 + timedelta(days=1), 1800, True)]}}
    acts = [activity(1, "Run", t0 + timedelta(minutes=2), 28),
            activity(2, "Bike", t0 + timedelta(days=1), 30),
            activity(3, "Walk", t0 + timedelta(days=2), 18, very=1)]
    data, events = q.apply(data, acts, NOW)
    kinds = [(e["type"], e.get("week"), e.get("day")) for e in events]
    assert ("verified", 1, 1) in kinds
    assert not any(e["type"] == "verified" and e["day"] == 2 for e in events)
    assert not any(e["type"] == "free_run" for e in events)
    assert data["quest"]["sessions"][0]["verification"]["logId"] == 1
    assert data["quest"]["sessions"][0]["verification"]["averageHeartRate"] == 128


def test_apply_is_idempotent_and_one_activity_per_session():
    t0 = NOW - timedelta(days=2)
    data = {"quest": {"sessions": [session("a", 1, 1, t0, 1800, True), session("a-again", 1, 1, t0 + timedelta(minutes=5), 1500, False)]}}
    acts = [activity(1, "Run", t0, 30)]
    data, events = q.apply(copy.deepcopy(data), acts, NOW)
    assert [e["type"] for e in events if e["type"] == "verified"] == ["verified"]
    assert sum(1 for s in data["quest"]["sessions"] if s.get("verification")) == 1
    again, events2 = q.apply(copy.deepcopy(data), acts, NOW)
    assert events2 == [] and again == data


def test_free_run_rules():
    t0 = NOW - timedelta(days=1)
    data = {"quest": {"sessions": []}}
    acts = [activity(1, "Run", t0, 12),                       # named run: counts
            activity(2, "Walk", t0 + timedelta(hours=2), 20, very=9),  # hard walk: counts
            activity(3, "Walk", t0 + timedelta(hours=4), 20, very=3),  # stroll: ignored
            activity(4, "Run", t0 + timedelta(hours=6), 3)]            # too short: ignored
    data, events = q.apply(data, acts, NOW)
    assert sorted(e["activity"]["logId"] for e in events if e["type"] == "free_run") == [1, 2]
    assert all(s["id"].startswith("free-") for s in data["quest"]["sessions"])


def test_short_stop_needs_only_five_minutes_of_overlap():
    t0 = NOW - timedelta(days=1)
    data = {"quest": {"sessions": [session("a", 2, 1, t0, 420, False)]}}
    data, events = q.apply(data, [activity(1, "Walk", t0, 6)], NOW)
    assert events and events[0]["type"] == "verified"


def test_events_report_level_and_chapter():
    t0 = NOW - timedelta(days=7)
    sessions = [session(f"s{d}", 1, d, t0 + timedelta(days=d), 1800, True) for d in (1, 2, 3)]
    data = {"quest": {"sessions": sessions}}
    acts = [activity(d, "Run", t0 + timedelta(days=d), 30) for d in (1, 2, 3)]
    _, events = q.apply(data, acts, NOW)
    types = [e["type"] for e in events]
    assert types.count("verified") == 3 and "level_up" in types
    # The chapter was already done (all three completed) before verification, so no chapter event now.
    assert "chapter_done" not in types


def test_iso_roundtrip_matches_swift_shape():
    s = q.iso(datetime(2026, 9, 24, 5, 36, 13, 372000, tzinfo=timezone.utc))
    assert s == "2026-09-24T05:36:13.372Z"
    assert q.parse_ts(s) == datetime(2026, 9, 24, 5, 36, 13, 372000, tzinfo=timezone.utc)
    assert q.parse_ts("2026-09-09T19:09:19.000-05:00").astimezone(timezone.utc).hour == 0


def test_summary_json_safe():
    data = {"quest": {"sessions": [session("a", 1, 1, NOW, 1800, True)]}}
    json.dumps(q.summary(data["quest"], NOW))
