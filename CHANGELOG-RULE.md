# How to write a CHANGELOG entry here

This repository tracks one changelog, `CHANGELOG.md`: the record of what changed
on the published site. Read this before adding a line.

## The entry

The rule every entry is held to, and it is a MUST:

> Keep the entries short, always under 200 characters and one-two sentences.
> Only keep the essence of the change. git commit messages will keep the
> details. In the CHANGELOG, only keep the essence.

State the essence of the change and what it is for, never its content: the
commit message is where the details go. One entry per significant change to a
published surface.

Every top-level entry opens with its ISO date, `- YYYY-MM-DD: ` (arm CL-7).

`bin/check-changelog` holds the arms named here. It measures an entry as its text
after the leading `- `, date included, with wrapped lines joined by one space.

## The version is in the heading, and a PATCH is a release

Entries are grouped by the cut that carries them, so a reader can answer «which
version has this change?» A date cannot answer it. **A MINOR cut and a PATCH cut
each get their own section — that is the point of the rule.**

    ## [Unreleased]                                 new entries go here, newest first

    ## [skill 0.5.0] — 2026-09-25                   a cut renames [Unreleased]

    ## [skill 0.5.1 · listener 0.5.2] — 2026-09-26  a cut that moved both lines

    ## Before release sections                      entries from before the grouping

Four shapes, and the check holds them:

1. The record carries exactly one `## [Unreleased]`, and it is the first section
   in the file. A new entry goes INSIDE it — an entry above the first section
   belongs to no release and is refused (arms CL-12, CL-13).
2. A version section names the version AND the date it was cut,
   `## [MAJOR.MINOR.PATCH] — YYYY-MM-DD`. A section named for a MAJOR.MINOR
   alone, or carrying no date, is refused (arm CL-11) — a two-number heading is
   exactly the thing this rule exists to stop.
3. This site publishes TWO independently versioned lines, so a section names
   which one it cut: `## [skill 0.5.0] — …`, `## [listener 0.5.2] — …`, and
   both joined by ` · ` when one wave cut both. A bare `## [0.5.0]` stays legal
   and means the skill — that is what the sections written before this rule
   are, and they are not relabelled.
4. `## Before release sections` is the one heading that is NOT a release. It
   holds the entries written before this file grouped them: they are not a cut,
   and they are never edited.

**What a cut IS here, so the heading is never invented.** This repository
publishes two versioned artefact lines on independent numbers: the **skill**,
`skill-vMAJOR.MINOR.PATCH.md`, immutable once committed, with `skill.md`
byte-identical to the newest one; and the **listener**, `events/listen-vX.Y.Z.py`,
the client the skill pins by SHA-256, with `events/listen.py` as its alias. A
bare number names two different files, which is why the heading names the line.

A section is named for the cut that closed it, and everything published since
the previous section belongs to it — a specification sentence, a landing-page
claim, an onboarding fix. Version parity fixes the skill's number: before 1.0
the protocol, the reference implementation and the skill carry the same
MAJOR.MINOR.PATCH, so a skill cut is a release of the reference implementation
too and a release there is a skill cut here, even with no text to change; from
1.0 they share MAJOR.MINOR and PATCH is the skill's own. A PATCH gets a section
exactly as a MINOR does. The listener's number is its own and tracks nothing.

The order of one cut, and it is the order that keeps the heading true:

1. Cut the artefact: `skill-vX.Y.Z.md` with its frontmatter `version` matching
   its name and `skill.md` byte-identical to it, or `events/listen-vX.Y.Z.py`
   with `events/listen.py` byte-identical to it.
2. Rename `## [Unreleased]` to `## [<line> X.Y.Z] — <the date it was cut>`,
   naming every line this wave cut, and open a fresh empty `## [Unreleased]`
   above it.
3. `bin/check-skill-immutability` green, and the
   operator pins relinked and, before 1.0, `reference` cut to the same version,
   before the merge.

## Nothing already written is edited

History is append-only. An entry that has turned out to be wrong is superseded
by a NEW entry that says so and names it, never rewritten. The length and
sentence arms read only entries that are new against the check's declared
baseline commit, so the standing backlog is counted in every run and failed by
nothing — which is why it is safe for the rule to be strict about what arrives
next.
