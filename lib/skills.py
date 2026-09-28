"""The skills panel, Mac side: XP rules for every skill.

Mirrors ``ios/ExerciseLog/Sources/Model/Skills.swift`` exactly. XP is
derived from the logs, never stored, so the phone and the Mac can both
rewrite the file without drift. Change the constants in both files or
neither.

INVARIANTS
- ``merge_nights`` is idempotent and never downgrades a verified night to a
  claimed one.
- Hitpoints never drops below level 10 (1154 xp), as in the game.
"""
from __future__ import annotations

from datetime import date, timedelta

import quest as q

SKILLS = ["hitpoints", "strength", "agility", "firemaking", "crafting", "cooking"]

HITPOINTS_BASE_XP = 1154
SET_BASE_XP = 10
WEEKLY_TARGET_XP = 100
SLEEP_BASE_XP = 60
SLEEP_STEP_XP = 20
SLEEP_MAX_XP = 200
MEAL_XP = 40
COMBAT_SHARE = 3

FIRE_XP = {"candle": 10, "fireplace": 40, "campfire": 90, "bonfire": 135, "noLighter": 202, "rain": 304}
CRAFT_XP = {"trinket": 50, "project": 200, "ambitious": 600, "masterwork": 1500}
COOK_XP = {"simple": 30, "everyday": 70, "involved": 120, "exotic": 210, "feast": 300}


def _next_day(day: str) -> str:
    return (date.fromisoformat(day) + timedelta(days=1)).isoformat()


def strength_xp(data: dict) -> int:
    total = 0
    targets = {e["id"]: e.get("weeklySets", 0) for e in data.get("exercises", [])}
    for w in data.get("weeks", []):
        counts: dict[str, int] = {}
        for d in w.get("days", []):
            for eid, e in d.get("entries", {}).items():
                sets = e.get("sets", [])
                total += sum(SET_BASE_XP + s.get("reps", 0) for s in sets)
                counts[eid] = counts.get(eid, 0) + len(sets)
        for eid, target in targets.items():
            if target > 0 and counts.get(eid, 0) >= target:
                total += WEEKLY_TARGET_XP
    return total


def _runs(nights: list[dict]):
    run, previous = 0, None
    for n in sorted(nights, key=lambda n: n["date"]):
        if n.get("goalMet"):
            run = run + 1 if (previous and _next_day(previous) == n["date"] and run > 0) else 1
            yield n, run
        else:
            run = 0
        previous = n["date"]


def sleep_xp(nights: list[dict]) -> int:
    return sum(min(SLEEP_BASE_XP + SLEEP_STEP_XP * (run - 1), SLEEP_MAX_XP) for _, run in _runs(nights))


def current_sleep_run(nights: list[dict]) -> int:
    run = 0
    for _, run in _runs(nights):
        pass
    # _runs only yields goal-met nights; a trailing miss resets to zero.
    ordered = sorted(nights, key=lambda n: n["date"])
    if ordered and not ordered[-1].get("goalMet"):
        return 0
    return run


def hitpoints_xp(data: dict) -> int:
    s = data.get("skills", {})
    meals = len(s.get("meals", [])) * MEAL_XP + sum(MEAL_XP for c in s.get("cooks", []) if c.get("healthy"))
    combat = (strength_xp(data) + q.total_xp(data.get("quest", {}))) // COMBAT_SHARE
    return HITPOINTS_BASE_XP + sleep_xp(s.get("nights", [])) + meals + combat


def xp(skill: str, data: dict) -> int:
    s = data.get("skills", {})
    if skill == "hitpoints":
        return hitpoints_xp(data)
    if skill == "strength":
        return strength_xp(data)
    if skill == "agility":
        return q.total_xp(data.get("quest", {}))
    if skill == "firemaking":
        return sum(FIRE_XP.get(e.get("kind"), 0) for e in s.get("fires", []))
    if skill == "crafting":
        return sum(CRAFT_XP.get(e.get("tier"), 0) for e in s.get("crafts", []))
    if skill == "cooking":
        return sum(COOK_XP.get(e.get("tier"), 0) for e in s.get("cooks", []))
    raise ValueError(skill)


def levels(data: dict) -> dict[str, int]:
    return {s: q.level_for_xp(xp(s, data)) for s in SKILLS}


def total_level(data: dict) -> int:
    return sum(levels(data).values())


def merge_nights(data: dict, verified: list[dict]) -> tuple[dict, list[dict]]:
    """Write Fitbit-verified nights over claimed ones for the same date.

    ``verified`` items: ``{"date", "minutes", "goalMet"}``. Returns the new
    data and one event per night that changed.
    """
    skills = data.setdefault("skills", {})
    nights = {n["date"]: n for n in skills.get("nights", [])}
    events = []
    for v in verified:
        new = {"date": v["date"], "minutes": v["minutes"], "goalMet": bool(v["goalMet"]), "verified": True}
        old = nights.get(v["date"])
        if old == new:
            continue
        nights[v["date"]] = new
        events.append({"type": "night_verified", "date": v["date"], "minutes": v["minutes"], "goalMet": new["goalMet"],
                       "wasClaimed": bool(old and not old.get("verified"))})
    skills["nights"] = [nights[k] for k in sorted(nights)]
    return data, events
