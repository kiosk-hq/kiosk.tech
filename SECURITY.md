# Security policy

This repository is the published Kiosk protocol: the normative
[`specification.html`](specification.html), the formal spec and its JSON
Schemas under `spec/`, the versioned assistant skill cuts, the problem-document
pages every error `type` URI dereferences to, and the proof-of-work solver an
assistant downloads and runs. The solver is served twice, and both copies are
in scope: the content-addressed `pow/solve-<sha256-prefix>.py` that a skill cut
pins by URL and digest, and `pow/solve.py`, the mutable copy an operator's 402
hint points at. This repository holds no operator's data and no card, and it
runs no server of its own — but what is written here is what every Kiosk
operator and
every assistant implements, so a flaw in the *rules* reaches every origin at
once.

## Reporting a vulnerability

**Open a GitHub issue.** Which repository depends on what the flaw is in:

| The flaw is in | File it in |
| --- | --- |
| the **specification** — a normative rule, the formal spec, a JSON Schema, a skill cut, a problem page, either served copy of the solver | [`kiosk-hq/kiosk.tech`](https://github.com/kiosk-hq/kiosk.tech/issues), this repository |
| the **implementation** — a gem, a demo application, the e2e harness, a deploy runbook | [`kiosk-hq/kiosk`](https://github.com/kiosk-hq/kiosk/issues) |

If a flaw is in both — the spec permits something an engine should not do, or
an engine does something the spec never described — file it in either and say
so; we will move it.

**A GitHub issue is PUBLIC from the moment you file it.** There is no private
channel, so filing IS disclosing: anyone reading the tracker, including someone
who would use the flaw, sees it the instant you press the button. That is worth
knowing before you choose, and we would rather say it plainly than route you
through a page that implies a confidential inbox we do not have. If a flaw
looks severe enough that you are not willing to publish it, open an issue that
describes its shape without the exploit and we will work out where to take it.

**This is the arrangement until 1.0.** Kiosk is pre-1.0 and the wire may still
change between releases, so there is no fleet of frozen deployments for a
disclosure race to endanger. That changes at 1.0, and this page changes with
it — do not read the current channel as permanent.

A report is most useful when it carries:

- **which document and which clause** — the section number in
  `specification.html`, the `$id` and JSON Pointer of a schema, or the exact
  skill cut file, because the cuts are frozen and differ;
- **the sequence that shows it** — the requests, tokens or mandates a
  conforming implementation would accept, and why it should not;
- **what an attacker gets**: whose data, whose money, or whose identity, at an
  operator that implements the specification exactly as written.

We will credit you in the changelog entry for the fix unless you ask us not to.

## What is in scope

Every normative statement in `specification.html` and in `spec/protocol.md`,
every JSON Schema under `spec/schemas/`, the assistant skill (the alias
`skill.md` and every `skill-vX.Y.Z.md` cut), the problem pages under
`problems/`, and both served copies of the solver — the content-addressed
`pow/solve-<sha256-prefix>.py` that skill cuts pin, and `pow/solve.py`.

## What is not a vulnerability here

- **A published skill cut cannot be edited, and that is the design.** Operators
  pin a cut by URL *and* by sha256, so changing one is a supply-chain event, not
  a fix. A flaw found in a cut is repaired by publishing a NEW cut and moving the
  pins; an issue asking us to rewrite `skill-v0.3.4.md` in place will be answered
  with that. A report that a cut's bytes no longer match a published digest is a
  real and urgent finding.
- **The solver holds no key, sees no token and touches no money.** It is
  fetched by content hash and run as a subprocess by the assistant, which never
  imports from it; the worst a swapped copy buys is a rejected proof. A report
  that the served bytes do not match the digest a skill cut publishes beside the
  URL is, again, a real finding.
- **The proof-of-work gate is metered pricing, not a hardware wall.** Equihash
  is neither ASIC- nor GPU-proof and the specification says so. "A GPU solves
  this faster than a laptop" is the design.
- **Pre-1.0 wire changes.** The wire may change between releases; that is
  stated on the landing page and in the specification, and a change that breaks
  an unpinned client is not a security flaw.

## What is not covered by this policy

A flaw in a third party's Kiosk implementation belongs to that implementation's
maintainers. If it turns out the specification is what led them there, tell us
and it becomes a report here.
