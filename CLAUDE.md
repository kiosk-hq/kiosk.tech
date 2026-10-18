# kiosk.tech (published site) — constitution

This repo is everything published at https://kiosk.tech (GitHub Pages,
`CNAME`). Static files, no build step.

- `specification.html` — the normative spec, in narrative form.
- `spec/` — the formal spec (`spec/protocol.md`) and JSON Schemas
  (`spec/schemas/`) for adopters and porters. Keep it consistent with
  `specification.html`.
- `skill.md` — the agent skill. It is the alias of the newest cut and must be
  byte-identical to it. The current cut is `skill-v0.5.14.md`.
- `index.html` (landing), `onboarding.html`, `known-issues.html`.

Every workflow in `.github/workflows/` runs one `bin/check-*` guard over the
checked-in files, and each guard has exactly one workflow. `ls` the two
directories for the list.

## Skill cuts

- Never edit a published `skill-vX.Y.Z.md`. Every change ships a new cut.
- A skill edit ends in a version bump and a re-pin of every consumer in the
  same change. `bin/check-skill-immutability` enforces both.

## The five rules

1. **Authority chain.** `specification.html` is normative and the root of the
   chain. Code and skill conform to it. Landing and skill text claim only what
   the reference implementation does. An ADR may override the spec; then
   update the spec. A change to normative spec text is a decision: it needs an
   ADR or a recorded ledger `decision`.
2. **Conflict rule.** On a conflict with no recorded decision, do not pick a
   side. Record it in the findings ledger as `decision-needed` and skip it.
3. **Scope rule.** Record a problem outside your task in the findings ledger.
   Do not fix it inline.
4. **Merge gate.** Tests that cover the change are green before merge.
5. **Changelog rule.** A change to behaviour, spec text, skill instructions or
   claims gets an entry in `CHANGELOG.md`. Tests-only changes, refactors and
   typo fixes get none.
   - One or two sentences, under 200 characters, the essence only. Details go
     in the commit message.
   - New entries go under `## [Unreleased]`. A cut renames it to
     `## [<line> MAJOR.MINOR.PATCH] — YYYY-MM-DD` and opens a new empty one
     above. A skill PATCH gets a section too.
   - This repo publishes two versioned lines on independent numbers: the skill
     and the pinned event listener. The heading names the line it cut.
     Everything published since the previous section belongs to it.
   - Never edit a written entry.
   - `CHANGELOG-RULE.md` at the root is the procedure.

## The skill stays audience-neutral

`skill.md` is read by every assistant on every OS. A workaround for one OS,
one Python install or one assistant runtime goes in it only when its absence
blocks a significant share of readers. Otherwise it goes on
`known-issues.html` (symptom, cause, fix), and only for a problem a live run
hit.
