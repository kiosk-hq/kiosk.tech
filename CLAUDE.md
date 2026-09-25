# kiosk.tech (published site) — constitution

This repo is everything published at https://kiosk.tech (GitHub Pages,
`CNAME`): `specification.html` — **the normative spec**, `skill.md` — the
universal agent skill (the "latest" alias, which must come to REST byte-identical
to the newest cut; the immutable published versions are `skill-vX.Y.Z.md`,
current `skill-v0.5.0.md` (MAJOR.MINOR tracks the framework release from 0.2 on)
— a published version file is never edited, every change ships a new one, and a
skill edit ends in a version bump plus a re-pin of every consumer in the same
wave: `bin/check-skill-immutability` enforces both halves. K-847, and the three
standing rules are in the umbrella `CLAUDE.md`.), `index.html` —
landing, `onboarding.html`, `payment/return` (Stripe Checkout return page),
and `spec/` — the **formal** specification (`spec/protocol.md`,
RFC-style) plus machine-readable JSON Schemas (`spec/schemas/`) for adopters and
porters (`specification.html` is the narrative spec, the formal spec is
its precise companion; both are kept consistent). Static files, no build step — nothing
here is compiled, and NO workflow builds the site: every workflow in
`.github/workflows/` runs a guard over the checked-in files. Each `bin/check-*`
has exactly one workflow that runs it, so the guards answer the same in CI as
they do locally — that pairing is the fact worth knowing, and it is enforced
rather than restated here. **Do not enumerate or count the workflows in this
paragraph.** It
claimed a single one while two existed (K-898); the repair claimed two while a
third was landing; and that same repair asserted `check-problem-pages` was run
by nothing on the very day the workflow that runs it was committed. Three wrong
statements, one cause: a set the directory already knows, retyped by hand.
`ls .github/workflows/` and `ls bin/` are the list, and that same umbrella
check fails if one is written back here.

Extra weight of rule 1 here: the spec is the ROOT of the authority chain.
Changing normative spec text is a decision — it needs an ADR or a ledger
`decision` reference. Landing and skill text must trace to behavior
demonstrated by the reference implementation.

## The five rules

1. **Authority chain.** The spec (`specification.html`, this repository's own) is
   normative. Code and skill conform to the spec; landing/HN/README claim
   only what the code demonstrably does. An ADR may override the spec — then
   the spec must be updated to match.
2. **Conflict rule.** On a conflict with no recorded decision (ADR or a
   ledger `decision`): do NOT pick a side. Record it in the findings ledger
   as `decision-needed` and skip that item.
3. **Scope rule.** Found a problem outside your current task? Record it in
   the findings ledger. Do not fix it inline.
4. **Merge gate.** Tests covering the change must be green before merge; for
   `reference` that means the touched gem's own suite + `e2e/run.sh`.
5. **Changelog rule.** Significant changes — anything altering behavior, spec
   text, skill instructions, or claims — get an entry in the touched repo's
   `CHANGELOG.md` stating the essence and intent of the change, not its
   content. Tests-only changes, refactors, typos do not qualify.
   **THE STRONG RULE (Phil, 2026-09-11), his words. It binds EVERY
   `CHANGELOG.md` in this workspace, and this repository tracks exactly one
   (it ships no gem — zero `.gemspec` files tracked). There is no second
   register and no exception; the «journal for the root file, release notes
   for the gems» split this rule used to carry is REPEALED:**

   > **Keep the entries short, always under 200 characters and one-two
   > sentences. Only keep the essence of the change. git commit messages will
   > keep the details. In the CHANGELOG, only keep the essence.**

   The details belong in the git commit message and in the ledger row. Nothing
   already written is edited — a changelog is append-only history — so the long
   standing corpus stays as it is, and `bin/check-changelog` (arms CL-8 length,
   CL-9 sentences) holds the rule on entries that are NEW against its declared
   baseline commit, printing the backlog as a census that never reddens.

   **AND THE ENTRY SAYS WHICH VERSION CARRIES IT, NOT ONLY WHEN IT LANDED (Phil,
   2026-09-24).** An entry is grouped by the cut that carries it:
   `## [Unreleased]` holds what no cut has closed yet, and a cut renames it to
   `## [<line> MAJOR.MINOR.PATCH] — YYYY-MM-DD` and opens a fresh empty one above
   — **a skill PATCH getting a section exactly as a MINOR does**, since a date
   cannot say which version has a change. This repository publishes TWO versioned
   lines on independent numbers — the skill cut and the pinned event listener — so
   the heading names which one it cut, and everything published since the previous
   section belongs to it, a specification sentence and a landing claim included.
   The entries written before the grouping sit
   below the `## Before release sections` heading, unedited and naming no version.
   **`CHANGELOG-RULE.md` at the root is the authority for how**, and the changelog
   points at it instead of repeating it. `bin/check-changelog` holds the shape
   (CL-11 heading grammar, CL-12 an open section, CL-13 no ungrouped entry).
