# kiosk.tech

The source of <https://kiosk.tech>. Static files, served by GitHub Pages from
this repository — there is no build step, and no workflow here builds the site:
every workflow runs a guard over the checked-in files.

Kiosk is a protocol for exposing a provider's own API to a consumer's AI
assistant. **This repository is the specification and the published agent
skill.** The Ruby reference implementation is a separate repository,
<https://github.com/kiosk-hq/kiosk>.

## What is normative

`specification.html` is the **normative** specification. It is the narrative
one, written in RFC 2119 language, and it binds two conformance targets: the
**operator** serving the endpoints and the **AI assistant** calling them. Boxes
in it marked *Reference note* describe the Ruby reference and say of themselves
that they are non-normative.

`spec/protocol.md` is its **formal** companion — the same protocol written
RFC-style and section-numbered, for anyone porting Kiosk to another stack. The
two are kept consistent; where their wording still differs, the formal
specification is the authority on wire precision.

`spec/schemas/` carries the machine-readable JSON Schemas. Beside them,
`spec/schemas/examples/` holds documents every schema must ACCEPT and
`spec/schemas/examples/rejected/` documents it must REFUSE, so a schema is
pinned from both directions; `spec/schemas/validate.sh` runs them.

## The skill

`skill.md` is the universal agent skill — the instructions an AI assistant reads
in order to talk to any Kiosk operator. It is the **latest alias**, and it comes
to rest byte-identical to the newest `skill-vX.Y.Z.md` beside it.

A `skill-vX.Y.Z.md` file is **immutable**: a published cut is never edited, and
every change ships a new file. MAJOR.MINOR is the protocol version that cut
describes, so a cut whose MAJOR.MINOR does not match an operator's protocol
cannot transact with it; PATCH is a skill-only revision against the same
protocol. An operator's `/.well-known/kiosk.json` pins one of these URLs
together with its SHA-256, which is why the files may not move.

`skills.md` is the index of them: every published cut, the protocol it
describes, and what changed on the wire.

## The other published pages

| Path | What is served there |
|---|---|
| `index.html` | The landing page. |
| `onboarding.html` | The operator onboarding guide. |
| `problems/<code>/` | One page per entry in the protocol's closed error vocabulary. Every Kiosk refusal is an RFC 9457 problem document whose `type` is one of these URLs, so a developer who pastes the URI out of a log lands on the page for that code; `problems/` indexes them. |
| `pow/solve.py` | The reference Equihash proof-of-work solver (Python + numpy) — the current copy, which is what an operator's `402` points a caller at. |
| `pow/solve-<digest>.py` | The same solver at a content-addressed URL, so a frozen skill cut can pin a solver whose bytes cannot change under it. |
| `payment/return/` | The page a hosted card-setup flow returns the human to. |

## Checking it

The scripts under `bin/` are the guards, and each is run by exactly one workflow
under `.github/workflows/`, so a guard answers the same on a laptop as it does
in CI. Run one by name from the repository root; every one of them also takes
`--self-test`, which exercises its own rules against planted fixtures and
touches nothing in the tree.

## Reporting a problem

`SECURITY.md` says what counts as a vulnerability in a specification, what does
not, and where to send one.

## Licence

Apache-2.0 — see `LICENSE`.
