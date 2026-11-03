---
name: template-skill
description: "What this skill does AND when to use it. Be specific and a little pushy: list adjacent phrasings. This is the only thing that triggers the skill."
metadata:
  internal: true  # the template is not a skill: keep it out of CLI discovery
---

# Skill name

One line on the outcome.

## Ground rules
Copy the shared block from an existing Barbacana skill.

## Workflow
Imperative steps. Explain why, not just what.

## References
Point to `references/*.md` and say when to read each. Add a table of contents to any file over 300 lines.

## Found a problem?

Say where it belongs instead of working around it silently, and open an issue only if the user agrees. Remove hostnames, IPs, tokens and log contents from anything you post.

- Barbacana misbehaves (crash, wrong result, config that validates but fails to start): <https://github.com/barbacana-waf/barbacana/issues>
- The documentation is wrong or missing: <https://github.com/barbacana-waf/barbacana-docs/issues>
- This skill is wrong, unclear or missing a case: <https://github.com/barbacana-waf/skills/issues>
