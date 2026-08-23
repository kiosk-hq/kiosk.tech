# kiosk.tech (published site) — constitution

This repo is everything published at https://kiosk.tech (GitHub Pages,
`CNAME`): `specification.html` — **the normative spec**, `skill.md` — the
universal agent skill (the "latest" alias, which must come to REST byte-identical
to the newest cut; the immutable published versions are `skill-vX.Y.Z.md`,
current `skill-v0.4.5.md` (MAJOR.MINOR tracks the framework release from 0.2 on)
— a published version file is never edited, every change ships a new one, and a
skill edit ends in a version bump plus a re-pin of every consumer in the same
wave: `bin/check-skill-immutability` enforces both halves. K-847, and the three
standing rules are in the umbrella `CLAUDE.md`.), `index.html` —
landing, `onboarding.html`, `payment/return` (Stripe Checkout return page),
and `spec/` — the **formal** specification (`spec/protocol.md`,
RFC-style) plus machine-readable JSON Schemas (`spec/schemas/`) for adopters and
porters (`specification.html` is the narrative spec, the formal spec is
its precise companion; both are kept consistent). Static files, no build step — nothing
here is compiled, and neither CI workflow builds the site. `.github/workflows/spec-schemas.yml`
lints `spec/schemas/`; `.github/workflows/skill-immutability.yml` runs
`bin/check-skill-immutability`, the guard the paragraph above depends on, so it
answers the same in CI as it does locally. `bin/` also ships
`check-problem-pages` (the RFC 9457 problem-type pages under `problems/` resolve
and match the spec's vocabulary), which no workflow runs yet.

Extra weight of rule 1 here: the spec is the ROOT of the authority chain.
Changing normative spec text is a decision — it needs an ADR or a ledger
`decision` reference. Landing and skill text must trace to behavior
demonstrated by the reference implementation.

## The five rules

1. **Authority chain.** The spec (`kiosk.tech/specification.html`) is
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
   text, skill instructions, or claims — get ONE line in the touched repo's
   `CHANGELOG.md`: 1–2 sentences stating the essence and intent of the
   change, not its content. Tests-only changes, refactors, typos do not
   qualify.
