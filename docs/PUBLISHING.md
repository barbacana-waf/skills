# Publishing to skills.sh

How to get these skills in front of users via [skills.sh](https://www.skills.sh/) and the `npx skills` CLI ([vercel-labs/skills](https://github.com/vercel-labs/skills)).

## How skills.sh works

Checked against the skills.sh docs and FAQ:

- **There is no submit form.** Skills live in public GitHub repositories. Users install with `npx skills add <owner/repo>`.
- **The leaderboard is built from install telemetry.** The CLI sends anonymous data (skill name, skill files, a timestamp) when someone installs. A skill appears in the rankings once it has been installed, ranked by install count. The docs give no timeframe for how soon.
- **Audits.** skills.sh says it runs routine security audits of listed skills and their contents (see skills.sh/audits). It does not say whether an audit gates listing. Keep skills free of anything that looks like exploit code or exfiltration.
- **Removal.** There is no documented removal flow. Skills are maintained by their authors; problems are reported as issues on the skill's repo.

Not documented, so unverified: how long listing takes, how audits affect ranking, and whether a repo needs a minimum number of installs to show on the homepage. Re-check the site before relying on any of these.

## How the CLI finds our skills

The CLI searches `skills/` (and many agent-specific folders), walking up to three levels deep, and also reads `.claude-plugin/marketplace.json`. Our layout, `skills/<name>/SKILL.md`, is found directly. Required frontmatter is `name` (lowercase, hyphens) and `description`. `metadata.internal: true` hides a skill from normal discovery.

## Before the first publish

Publishing is effectively permanent: every install is tracked and cached copies persist. Do not publish unfinished work.

- [ ] **Only finished skills are visible.** Stubs (`barbacana-waf-configure`, `barbacana-waf-operate`) carry `metadata.internal: true` and stay hidden. Remove the flag when a skill is ready.
- [ ] No `TODO` left in any visible skill: `grep -rn TODO skills/*/SKILL.md skills/*/references` returns nothing for visible skills.
- [ ] `scripts/lint-skills.sh` passes.
- [ ] Sample configs validate against the **latest released** Barbacana: `barbacana --config <file> --validate` for each `skills/*/assets/waf-*.yaml`.
- [ ] Evals run and reviewed (`evals/README.md`); the skill beats the baseline on the evals it should, with no regressions.
- [ ] Image tags in assets are placeholders (`vX.Y.Z`) and docs tell the agent to look up the latest release.
- [x] Cosign identity confirmed: the exact `release.yml@refs/heads/master` identity verifies v0.9.7 (image, SBOM attestation and `checksums.txt.bundle`). The Barbacana docs that said otherwise were corrected in `docs/VERIFYING.md` and `docs/design/build.md`.
- [ ] No secrets, internal hostnames or personal paths anywhere (`git grep -nE 'carlos|/Users/|@hotmail'`).
- [ ] `LICENSE` (Apache-2.0) present; README accurate about which skills are ready.

## Publish

Creating the repository and pushing are outward-facing, so do them yourself:

```bash
cd ~/src/barbacana-skills
git add -A && git commit -m "feat: barbacana-waf-install skill"     # Co-Authored-By line if Claude helped
gh repo create barbacana-waf/skills --public --source . --push \
  --description "Agent skills for installing, configuring, tuning and operating the Barbacana WAF"
git tag v0.1.0 && git push origin v0.1.0
```

Add repo topics (`agent-skills`, `waf`, `security`, `claude-code`) in the GitHub settings to help discovery.

## Verify the install path

Use a clean directory, and turn telemetry off so test installs do not count toward the leaderboard:

```bash
mkdir -p "$(mktemp -d)" && cd "$_"
export DISABLE_TELEMETRY=1
npx skills add barbacana-waf/skills --list                      # expect barbacana-waf-install and barbacana-waf-tune
npx skills add barbacana-waf/skills --skill barbacana-waf-install --agent claude-code --yes
ls .claude/skills/barbacana-waf-install                              # SKILL.md, references/, assets/
```

Then start an agent in that directory and ask it to put Barbacana in front of an app. Confirm it loads the skill and that `evals/` was not installed with it, if the CLI copies the whole folder.

Optional: `npx skills use barbacana-waf/skills --skill barbacana-waf-install` generates a prompt without installing.

## Getting listed

1. Publish the repo (above).
2. Install it for real, without `DISABLE_TELEMETRY`, from a clean machine. That install is the first telemetry event.
3. Look for the repo on skills.sh and its leaderboard. If it does not appear after a few days, open an issue on `vercel-labs/skills` rather than guessing.
4. Link the install command from the Barbacana README and from barbacana.dev:
   `npx skills add barbacana-waf/skills`

## Claude Code marketplace (deferred)

Not shipped in v0.1. A `.claude-plugin/marketplace.json` would give Claude Code users a native `/plugin marketplace add barbacana-waf/skills` install, but it adds a second list to keep in sync and its format has not been tested against Claude Code. Revisit once the skills are stable.

## Releasing updates

- Change skills by pull request; run the lint and evals first.
- Tag releases (`v0.2.0` when a skill is added or its behaviour changes, patch for wording fixes) and keep a short CHANGELOG.
- Users update with `npx skills update`; `npx skills check` shows pending updates.
- When Barbacana ships a release that changes config keys, protection names, CLI flags or metrics, review the skills the same day. The release checklist in `barbacana-waf/barbacana` should carry a line for this.
- When a new skill is finished: remove `metadata.internal`, add it to the README table, run its evals, tag a release.

## Telemetry note for contributors

The CLI collects anonymous install data by default. Set `DISABLE_TELEMETRY=1` (or `DO_NOT_TRACK=1`) when testing so development installs do not inflate the install count.
