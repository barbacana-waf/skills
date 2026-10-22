#!/usr/bin/env python3
"""Print a with/without pass-rate table for an iteration directory."""
import glob
import json
import os
import sys

it = sys.argv[1]
rows = {}
for g in sorted(glob.glob(os.path.join(it, "*", "eval-*", "*", "grading.json"))):
    parts = g.split(os.sep)
    skill, ev, arm = parts[-4], parts[-3], parts[-2]
    s = json.load(open(g))["summary"]
    t = {}
    tp = os.path.join(os.path.dirname(g), "timing.json")
    if os.path.exists(tp):
        t = json.load(open(tp))
    rows.setdefault((skill, ev), {})[arm] = (s, t)
print(f"\n{'skill / eval':44} {'with skill':>12} {'without':>10}   cost with/without")
tot = {"with_skill": [0, 0], "without_skill": [0, 0]}
for (skill, ev), arms in rows.items():
    cells = []
    for arm in ("with_skill", "without_skill"):
        if arm in arms:
            s = arms[arm][0]
            cells.append(f"{s['passed']}/{s['total']}")
            tot[arm][0] += s["passed"]; tot[arm][1] += s["total"]
        else:
            cells.append("-")
    cost = "/".join(f"${(arms.get(a, ({}, {}))[1].get('cost_usd') or 0):.2f}" for a in ("with_skill", "without_skill"))
    print(f"{skill + ' ' + ev:44} {cells[0]:>12} {cells[1]:>10}   {cost}")
print(f"{'TOTAL':44} {tot['with_skill'][0]}/{tot['with_skill'][1]:>9} {tot['without_skill'][0]}/{tot['without_skill'][1]:>8}")
