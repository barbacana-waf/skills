#!/usr/bin/env python3
"""Grade one eval run against the assertions in a skill's evals.json.

usage: grade.py <evals.json> <eval-id> <run-dir>

<run-dir> holds workdir/ (what the agent produced) and response.md (its final
answer). Writes <run-dir>/grading.json with {text, passed, evidence} per
assertion. Standard library only.
"""
import glob
import json
import os
import re
import subprocess
import sys

SKIP = (".claude" + os.sep,)


def files(workdir, pattern):
    hits = glob.glob(os.path.join(workdir, pattern), recursive=True)
    out = []
    for h in sorted(hits):
        rel = os.path.relpath(h, workdir)
        if os.path.isfile(h) and not rel.startswith(SKIP):
            out.append(h)
    return out


def read(path):
    with open(path, errors="replace") as f:
        return f.read()


def check(c, workdir, response):
    t = c["type"]
    if t in ("output_contains", "output_not_contains"):
        m = re.search(c["regex"], response)
        ok = bool(m) == (t == "output_contains")
        return ok, f"/{c['regex']}/ " + ("matched" if m else "not found") + " in response"
    fs = files(workdir, c["glob"])
    if t == "file_exists":
        return bool(fs), f"{len(fs)} file(s) match {c['glob']}: " + ", ".join(os.path.relpath(f, workdir) for f in fs[:5])
    if t == "file_contains":
        for f in fs:
            if re.search(c["regex"], read(f)):
                return True, f"/{c['regex']}/ found in {os.path.relpath(f, workdir)}"
        return False, f"/{c['regex']}/ not found in {len(fs)} file(s) matching {c['glob']}"
    if t == "file_not_contains":
        if not fs:  # absence in nothing is not evidence; avoids inflating baselines
            return False, f"no files match {c['glob']}"
        for f in fs:
            if re.search(c["regex"], read(f)):
                return False, f"/{c['regex']}/ found in {os.path.relpath(f, workdir)}"
        return True, f"/{c['regex']}/ absent from {len(fs)} file(s) matching {c['glob']}"
    if t == "validate_config":
        binary = os.environ.get("BARBACANA_BIN", "barbacana")
        cfgs = [f for f in fs if "version: v1alpha1" in read(f)]
        if not cfgs:
            return False, f"no Barbacana config (version: v1alpha1) among files matching {c['glob']}"
        notes = []
        for f in cfgs:
            p = subprocess.run([binary, "--config", f, "--validate"], capture_output=True, text=True)
            out = (p.stdout + p.stderr).strip().splitlines()
            notes.append(f"{os.path.relpath(f, workdir)}: " + (out[-1] if out else "no output"))
            if p.returncode != 0 or "config valid" not in (p.stdout + p.stderr):
                return False, "; ".join(notes)
        return True, "; ".join(notes)
    return False, f"unknown check type {t}"


def main():
    evals_path, eval_id, run_dir = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    spec = next(e for e in json.load(open(evals_path))["evals"] if e["id"] == eval_id)
    workdir = os.path.join(run_dir, "workdir")
    rp = os.path.join(run_dir, "response.md")
    response = read(rp) if os.path.exists(rp) else ""
    results = []
    for a in spec["assertions"]:
        ok, evidence = check(a["check"], workdir, response)
        results.append({"text": a["text"], "passed": ok, "evidence": evidence})
    passed = sum(r["passed"] for r in results)
    json.dump({"expectations": results, "summary": {"passed": passed, "total": len(results)}},
              open(os.path.join(run_dir, "grading.json"), "w"), indent=2)
    print(f"  {passed}/{len(results)} passed")
    for r in results:
        if not r["passed"]:
            print(f"    FAIL {r['text']} -- {r['evidence']}")


if __name__ == "__main__":
    main()
