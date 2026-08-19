# Published Kiosk skill cuts

`https://kiosk.tech/skill.md` is the **latest** alias and always has the same
bytes as the newest cut below. `https://kiosk.tech/skill-vX.Y.Z.md` files are
**immutable**: a published cut is never edited, and every change ships a new
file. An operator's `/.well-known/kiosk.json` `skill` pin is one of these URLs
plus its SHA-256, so a pin cannot drift by construction.

**MAJOR.MINOR is the protocol the cut describes** (version parity, formal spec
§14). PATCH is a skill-only revision — a wording or guidance fix against the
same protocol. So the table below is also the answer to "which of these can talk
to this operator": a cut whose MAJOR.MINOR does not match the operator's
protocol cannot transact with it.

| Cut | Protocol | Wire it describes |
|---|---|---|
| `skill-v0.4.1.md` | **0.4** | As 0.4.0, plus RFC 8288 pagination: EVERY query answers a bare array, and a truncated page says so in a `Link: <…>; rel="next"` response header (`X-Total-Count` carries the total). The `{rows, next}` body of 0.4.0 is gone. |
| `skill-v0.4.0.md` | **0.4** | One endpoint per verb (`GET <endpoint>/<query>`, `POST <endpoint>/<action>`); a success body is the result with no envelope; errors are RFC 9457 problem documents with the code at top-level `code`. |
| `skill-v0.3.0.md` … `skill-v0.3.11.md` | 0.3 | Multiplexed `POST <endpoint>/{query,run}` with a `name` field; `{ok, kind, rows/value}` success envelope; `{ok:false, error:{code,…}}` errors. |
| `skill-v0.2.0.md` … `skill-v0.2.4.md` | 0.2 | As 0.3, before that series' additions. |
| `skill-v0.1.1.md` … `skill-v0.1.3.md` | 0.1 | The first published series. |

**0.4.0 and 0.4.1 differ on the wire, which a PATCH normally does not.** 0.4.1
moved the pagination cursor out of the body and into a `Link` header, so an
assistant holding 0.4.0 will look for a `next` field that no 0.4.1 operator
sends. Adopt the cut the operator pins — that is what the dual-check is for.

**0.3 and 0.4 are not interoperable.** 0.4 removed the multiplexed endpoints and
the response envelope outright, with no tombstones and no compatibility mode. An
assistant holding a 0.3.x cut against an operator pinning 0.4.x must adopt the
pinned cut first: the paths, the argument channel and the response shape all
differ. The pre-0.4 cuts stay published, unedited, because live pins reference
their bytes — not because the wire they describe is still served.
