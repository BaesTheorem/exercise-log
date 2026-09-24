"""The running quest, Mac side: plan, XP rules, and Fitbit matching.

Mirrors ``ios/ExerciseLog/Sources/Model/Quest.swift`` exactly. The phone
writes attempts (``quest.sessions``); this module adds ``verification`` to
them from Fitbit's activity log and appends free runs it finds with no
attempt. XP and level are derived from ``sessions`` on both sides, never
stored, so either writer can rewrite its part without the numbers drifting.

Change the XP constants or the plan in both files or neither.

INVARIANTS
- ``apply`` is idempotent: running it twice on the same data and activities
  changes nothing the second time and reports no events.
- A Fitbit activity verifies at most one session, and a session takes at
  most one activity.
- Bike rides never verify anything.
"""
from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone

PLAN_ID = "c25k"
WEEKS = 9
DAYS_PER_WEEK = 3
WARMUP = ("warmup", 300)
COOLDOWN = ("cooldown", 300)

BOOTS_ON_XP = 1000
BOOTS_ON_SECONDS = 300
COMPLETE_XP = 1500
VERIFIED_XP = 1500
ACTIVE_MINUTE_XP = 50
FREE_RUN_XP = 500

CHAPTERS = [
    "Tutorial Island", "The Lumbridge Road", "The Draynor Marsh", "The Varrock Gate",
    "The Wilderness Ditch", "The Barbarian Village", "The Falador Wall",
    "The Taverley Dungeon", "The Boss",
]


# MARK: plan

def _reps(n: int, pattern: list[tuple[str, int]]) -> list[tuple[str, int]]:
    return pattern * n


def _work(week: int, day: int) -> list[tuple[str, int]]:
    jog, walk = "jog", "walk"
    if week == 1:
        return _reps(8, [(jog, 60), (walk, 90)])
    if week == 2:
        return _reps(6, [(jog, 90), (walk, 120)])
    if week == 3:
        return _reps(2, [(jog, 90), (walk, 90), (jog, 180), (walk, 180)])
    if week == 4:
        return [(jog, 180), (walk, 90), (jog, 300), (walk, 150), (jog, 180), (walk, 90), (jog, 300)]
    if week == 5:
        return {1: [(jog, 300), (walk, 180), (jog, 300), (walk, 180), (jog, 300)],
                2: [(jog, 480), (walk, 300), (jog, 480)]}.get(day, [(jog, 1200)])
    if week == 6:
        return {1: [(jog, 300), (walk, 180), (jog, 480), (walk, 180), (jog, 300)],
                2: [(jog, 600), (walk, 180), (jog, 600)]}.get(day, [(jog, 1500)])
    if week == 7:
        return [(jog, 1500)]
    if week == 8:
        return [(jog, 1680)]
    return [(jog, 1800)]


def plan_session(week: int, day: int) -> list[tuple[str, int]]:
    return [WARMUP] + _work(week, day) + [COOLDOWN]


def total_seconds(week: int, day: int) -> int:
    return sum(s for _, s in plan_session(week, day))


def jog_seconds(week: int, day: int) -> int:
    return sum(s for k, s in plan_session(week, day) if k == "jog")


def all_sessions() -> list[tuple[int, int]]:
    return [(w, d) for w in range(1, WEEKS + 1) for d in range(1, DAYS_PER_WEEK + 1)]


# MARK: xp

def _xp_table() -> list[int]:
    table = [0, 0]
    points = 0.0
    for n in range(1, 99):
        points += math.floor(n + 300 * 2 ** (n / 7))
        table.append(int(math.floor(points / 4)))
    return table


XP_TABLE = _xp_table()


def level_for_xp(xp: int) -> int:
    level = 1
    while level < 99 and XP_TABLE[level + 1] <= xp:
        level += 1
    return level


def xp_for_level(level: int) -> int:
    return XP_TABLE[max(1, min(99, level))]


def is_plan(s: dict) -> bool:
    return s.get("week") is not None and s.get("day") is not None


def xp_for_session(s: dict) -> int:
    total = 0
    v = s.get("verification")
    if is_plan(s):
        if s.get("elapsedSeconds", 0) >= BOOTS_ON_SECONDS:
            total += BOOTS_ON_XP
        if s.get("completed"):
            total += COMPLETE_XP
        if v:
            total += VERIFIED_XP
    elif v:
        total += FREE_RUN_XP
    if v:
        total += v.get("activeMinutes", 0) * ACTIVE_MINUTE_XP
    return total


def total_xp(quest: dict) -> int:
    return sum(xp_for_session(s) for s in quest.get("sessions", []))


def is_done(quest: dict, week: int, day: int) -> bool:
    return any(s.get("completed") and s.get("week") == week and s.get("day") == day
               for s in quest.get("sessions", []))


def is_verified(quest: dict, week: int, day: int) -> bool:
    return any(s.get("completed") and s.get("verification") and s.get("week") == week and s.get("day") == day
               for s in quest.get("sessions", []))


def chapter_done(quest: dict, week: int) -> bool:
    return all(is_done(quest, week, d) for d in range(1, DAYS_PER_WEEK + 1))


def next_session(quest: dict) -> tuple[int, int] | None:
    for w, d in all_sessions():
        if not is_done(quest, w, d):
            return (w, d)
    return None


# MARK: dates

def parse_ts(s: str) -> datetime:
    """Swift writes ``...Z`` with millis; Fitbit writes ``...000-05:00``."""
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def iso(dt: datetime) -> str:
    """The exact shape the Swift encoder writes, so a diff of the file is quiet."""
    dt = dt.astimezone(timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%S.") + f"{dt.microsecond // 1000:03d}Z"


def week_of(dt: datetime) -> str:
    """Sunday-start calendar week, matching ``LogDates.weekOf`` on the phone."""
    local = dt.astimezone()
    start = local - timedelta(days=(local.weekday() + 1) % 7)
    return start.strftime("%Y-%m-%d")


def completed_this_week(quest: dict, now: datetime | None = None) -> int:
    now = now or datetime.now(timezone.utc)
    wk = week_of(now)
    return sum(1 for s in quest.get("sessions", [])
               if s.get("completed") and is_plan(s) and week_of(parse_ts(s["startedAt"])) == wk)


# MARK: fitbit matching

EXCLUDED = ("bike", "cycl", "swim", "row", "elliptical")
RUNNING_WORDS = ("run", "jog")


def _activity_window(a: dict) -> tuple[datetime, datetime]:
    start = parse_ts(a["startTime"])
    return start, start + timedelta(milliseconds=a.get("duration", 0))


def _active_minutes(a: dict) -> int:
    levels = {lv["name"]: lv["minutes"] for lv in a.get("activityLevel", [])}
    return int(levels.get("fairly", 0) + levels.get("very", 0))


def _very_minutes(a: dict) -> int:
    return int(next((lv["minutes"] for lv in a.get("activityLevel", []) if lv["name"] == "very"), 0))


def eligible(a: dict) -> bool:
    name = a.get("activityName", "").lower()
    if any(x in name for x in EXCLUDED):
        return False
    return a.get("duration", 0) >= 5 * 60 * 1000


def verification_from(a: dict, now: datetime) -> dict:
    start, end = _activity_window(a)
    v = {
        "logId": int(a["logId"]),
        "source": "fitbit",
        "activityName": a.get("activityName", ""),
        "startTime": iso(start),
        "durationSeconds": int(a.get("duration", 0) // 1000),
        "distanceKm": float(a.get("distance", 0.0) or 0.0),
        "activeMinutes": _active_minutes(a),
        "verifiedAt": iso(now),
    }
    if a.get("averageHeartRate") is not None:
        v["averageHeartRate"] = int(a["averageHeartRate"])
    return v


def overlap_seconds(s: dict, a: dict) -> float:
    s_start = parse_ts(s["startedAt"])
    s_end = parse_ts(s["endedAt"]) if s.get("endedAt") else s_start + timedelta(seconds=s.get("elapsedSeconds", 0))
    a_start, a_end = _activity_window(a)
    return max(0.0, (min(s_end, a_end) - max(s_start, a_start)).total_seconds())


def match(s: dict, activities: list[dict]) -> dict | None:
    """The eligible activity that overlaps the attempt most, if the overlap is
    at least half of what was run (floored at five minutes for short stops)."""
    if not is_plan(s) or not s.get("startedAt"):
        return None
    need = 0.5 * max(s.get("elapsedSeconds", 0), 300)
    best, best_overlap = None, 0.0
    for a in activities:
        if not eligible(a):
            continue
        o = overlap_seconds(s, a)
        if o > best_overlap:
            best, best_overlap = a, o
    return best if best is not None and best_overlap >= need else None


def is_free_run(a: dict) -> bool:
    """A run, or a walk hard enough to count: eight very-active minutes in a
    quarter hour or more. Everyday walks to the store stay out of it."""
    if not eligible(a):
        return False
    name = a.get("activityName", "").lower()
    if any(w in name for w in RUNNING_WORDS):
        return True
    return _very_minutes(a) >= 8 and a.get("duration", 0) >= 15 * 60 * 1000


def apply(data: dict, activities: list[dict], now: datetime | None = None) -> tuple[dict, list[dict]]:
    """Verify attempts and add free runs. Returns the (mutated) data and the
    list of events that happened this pass, oldest first."""
    now = now or datetime.now(timezone.utc)
    quest = data.setdefault("quest", {"plan": PLAN_ID, "sessions": []})
    sessions = quest.setdefault("sessions", [])
    events: list[dict] = []
    level_before = level_for_xp(total_xp(quest))
    chapters_before = {w for w in range(1, WEEKS + 1) if chapter_done(quest, w)}

    used = {int(s["verification"]["logId"]) for s in sessions if s.get("verification")}
    pool = [a for a in activities if int(a["logId"]) not in used]

    # Oldest attempt first so an activity goes to the attempt it belongs to.
    for s in sorted((s for s in sessions if is_plan(s) and not s.get("verification")),
                    key=lambda s: s["startedAt"]):
        a = match(s, pool)
        if a is None:
            continue
        s["verification"] = verification_from(a, now)
        pool = [p for p in pool if p["logId"] != a["logId"]]
        events.append({"type": "verified", "week": s["week"], "day": s["day"], "sessionId": s["id"],
                       "xp": xp_for_session(s), "activity": s["verification"]})

    for a in pool:
        if not is_free_run(a):
            continue
        start, end = _activity_window(a)
        s = {
            "id": f"free-{int(a['logId'])}",
            "startedAt": iso(start),
            "endedAt": iso(end),
            "elapsedSeconds": int(a.get("duration", 0) // 1000),
            "jogSecondsDone": 0,
            "completed": False,
            "verification": verification_from(a, now),
        }
        sessions.append(s)
        events.append({"type": "free_run", "sessionId": s["id"], "xp": xp_for_session(s),
                       "activity": s["verification"]})

    sessions.sort(key=lambda s: s["startedAt"])
    xp = total_xp(quest)
    level_after = level_for_xp(xp)
    if level_after > level_before:
        events.append({"type": "level_up", "from": level_before, "to": level_after, "xp": xp})
    for w in sorted({w for w in range(1, WEEKS + 1) if chapter_done(quest, w)} - chapters_before):
        events.append({"type": "chapter_done", "week": w, "title": CHAPTERS[w - 1]})
    return data, events


def summary(quest: dict, now: datetime | None = None) -> dict:
    now = now or datetime.now(timezone.utc)
    xp = total_xp(quest)
    level = level_for_xp(xp)
    nxt = next_session(quest)
    sessions = quest.get("sessions", [])
    plan_attempts = [s for s in sessions if is_plan(s)]
    last = max(plan_attempts, key=lambda s: s["startedAt"], default=None)
    return {
        "level": level,
        "xp": xp,
        "xpToNext": (xp_for_level(level + 1) - xp) if level < 99 else 0,
        "next": {"week": nxt[0], "day": nxt[1], "title": CHAPTERS[nxt[0] - 1],
                 "totalSeconds": total_seconds(*nxt), "jogSeconds": jog_seconds(*nxt)} if nxt else None,
        "completedThisWeek": completed_this_week(quest, now),
        "planSessionsDone": sum(1 for w, d in all_sessions() if is_done(quest, w, d)),
        "planSessionsVerified": sum(1 for w, d in all_sessions() if is_verified(quest, w, d)),
        "freeRuns": sum(1 for s in sessions if not is_plan(s)),
        "awaitingVerification": sum(1 for s in plan_attempts if s.get("completed") and not s.get("verification")),
        "startedAt": quest.get("startedAt"),
        "last": last,
    }
