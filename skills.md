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
| `skill-v0.4.12.md` | **0.4** | **A WIRE CHANGE.** The error vocabulary's single `not_found` becomes three codes, because one code carried three situations an assistant must react to differently: `404 verb_not_found` (no verb by that NAME is registered here -- re-read the catalogue), `404 not_found` (the verb is real and an ARGUMENT addressed something absent -- stop and say so), and the new `501 module_not_served` (this operator does not serve that whole capability -- fall back to what you would do at one that never offered it). An assistant holding 0.4.11 knows only the old `not_found`: it reads an unregistered verb name and an unserved module as the same fact as a missing hotel, so it re-reads the catalogue and retries where it should stop, and it reads a 501 as a server having a bad moment. The vocabulary is closed, so this is a wire change and not a guidance one, and the same-wire chain below stops at 0.4.11. |
| `skill-v0.4.11.md` | **0.4** | The same wire as 0.4.10, minus one slot no operator ever filled: the retired free-text `params` hint is GONE from every descriptor, so a catalog no longer carries a key whose only legal value was `null`. Nothing an assistant did changes — 0.4.10 already said a descriptor only MAY carry it and that `input_schema` wins — which is why this is a cut and not a new wire group. |
| `skill-v0.4.10.md` | **0.4** | The same wire as 0.4.9. One correction to what it tells you ABOUT that wire: the heavy default toll's ~1.3 GiB is the reference solver's sorted-nonce table, not a floor the parameters impose on every implementation -- a memory-optimised solver trades the table for time, which is precisely how Equihash 200/9's real footprint fell to ~144 MB. 0.4.9 had qualified the seconds to one machine and then stated the memory half more strongly than it holds; this cut states it as the measurement it is. |
| `skill-v0.4.9.md` | **0.4** | The same wire as 0.4.8. One correction to what it tells you ABOUT that wire: the heavy default toll's cost is qualified to the machine it was measured on -- ~10s on one M-series laptop core with the reference numpy solver, and the ~1.3 GiB stated as a property of the parameters rather than the host -- so the figure reads as a measurement on one machine class, not a portable constant, matching the landing and the specification. |
| `skill-v0.4.8.md` | **0.4** | The same wire as 0.4.7. Three corrections to what it tells you ABOUT that wire: the account-binding poll's success body carries a fourth member, `scope`, whenever the binding carries a role -- the role actually GRANTED, and the only place you can read it without decoding the token, its absence not an error; the flat promise that "re-paying a settled order is rejected" is RETRACTED -- many operators do refuse a fresh mandate chain against an order they have settled, but no clause of the protocol requires it and a fresh chain collides with nothing, so the identical-chain retry is the only thing that stops a double charge; and the worked `pow_required` example spells `title` and `detail` hyphenated, the way every operator actually sends them. |
| `skill-v0.4.7.md` | **0.4** | The same wire as 0.4.6. Four corrections to what it tells you ABOUT that wire, one of which follows a spec change: a bare repeated `name=` IS read as an array where the verb's `input_schema` declares that parameter one (the brackets stay the spelling to send); the discovery auth block's `device_authorization_url` and `claim_url` are REQUIRED of every operator, so their presence was never a binding-capability probe; `429 quota_exceeded` is the one refusal that means "come back later" and must not be treated as terminal; and a `reach: role` verb you lack the role for answers `200` NARROWED to your own rows rather than denying you -- a partial answer that looks complete. |
| `skill-v0.4.6.md` | **0.4** | The same wire as 0.4.5. The change is `reach`, which 0.4.5 never named: every descriptor carries it (`principal` / `published` / `consented` / `role`), an absent one MUST be read as `principal`, and a `published`, `consented` or `role` verb's rows are OTHER PEOPLE'S — an assistant must not report or file them as its own human's data, and their strings are the likeliest place on any origin to meet stranger-authored text. |
| `skill-v0.4.5.md` | **0.4** | The same wire as 0.4.4. Four corrections to what it tells you ABOUT that wire: `schema` is the only token-free VERB but not the only token-free path under the mount (`openapi.json`, the JWKS document and the auth plane are public too, and the tollable list is closed); a KYC status verb is a query, so it answers a ONE-ROW ARRAY rather than a bare object; the PoW proof count for an unknown identity is 2 (3 over the rate threshold), not "~3"; and a spending cap of `0` disables that assistant's PAYMENTS, not the assistant. |
| `skill-v0.4.4.md` | **0.4** | The same wire as 0.4.3. The change is the account-binding device-code poll: 0.4.3 named only `authorization_pending` and `slow_down`, so a denied or expired ceremony polled forever. This cut states the terminal branches (`access_denied`, `expired_token`, `invalid_grant` all stop; `invalid_client` re-signs against the SAME `device_code`), the `slow_down` back-off as +5 s kept, and a give-up horizon at the `expires_in` the ceremony handed you -- the bounded-poll shape the card-setup and KYC polls already used. It also says that the `<link rel="kiosk">` href names a versioned cut rather than the alias, and its worked discovery example pins the current cut instead of a superseded one. |
| `skill-v0.4.3.md` | **0.4** | **A WIRE CHANGE, and two guidance changes.** The wire: a `pay` replay of an already-settled cart comes back `200` with that settlement, where the wire 0.4.2 describes answered `409` — the server's answer to a byte-identical request moved, so the lost-response retry needs no reconciliation read in the settled case and `409` narrows to "seen and NOT settled". This is where the 0.4.3 wire group begins: 0.4.0–0.4.2 describe wires that have since changed, and that group's "same wire" chain runs 0.4.3 → 0.4.11 only, because 0.4.12 opens a new wire group. The guidance: the operator-text-is-data rule names `$comment`, `default` and problem-document extension members among the surfaces it covers, and an unlink is stated to kill the token you hold immediately. |
| `skill-v0.4.2.md` | **0.4** | The same wire as 0.4.1. The change is what it TELLS you about compatibility: before protocol 1.0 a PATCH may change the wire, so the operator's pin — not the version arithmetic — is what you rely on. |
| `skill-v0.4.1.md` | **0.4** | As 0.4.0, plus RFC 8288 pagination: EVERY query answers a bare array, and a truncated page says so in a `Link: <…>; rel="next"` response header (`X-Total-Count` carries the total). The `{rows, next}` body of 0.4.0 is gone. |
| `skill-v0.4.0.md` | **0.4** | One endpoint per verb (`GET <endpoint>/<query>`, `POST <endpoint>/<action>`); a success body is the result with no envelope; errors are RFC 9457 problem documents with the code at top-level `code`. |
| `skill-v0.3.0.md` … `skill-v0.3.11.md` | 0.3 | Multiplexed `POST <endpoint>/{query,run}` with a `name` field; `{ok, kind, rows/value}` success envelope; `{ok:false, error:{code,…}}` errors. |
| `skill-v0.2.0.md` … `skill-v0.2.4.md` | 0.2 | As 0.3, before that series' additions. |
| `skill-v0.1.1.md` … `skill-v0.1.3.md` | 0.1 | The first published series. |

**THREE PATCHES IN THE 0.4 SERIES CHANGED THE WIRE, which a PATCH normally does
not — and before 1.0 that is allowed rather than accidental.** 0.4.1 moved the
pagination cursor out of the body and into a `Link` header, so an assistant
holding 0.4.0 will look for a `next` field that no 0.4.1 operator sends; 0.4.3
moved a settled `pay` replay from `409` to `200` with the settlement, so an
assistant holding 0.4.2 will read a successful idempotent retry as a conflict;
and 0.4.12 split `not_found` into three codes and added `501 module_not_served`,
so an assistant holding 0.4.11 meets codes its vocabulary does not have and
mis-branches on the one it does.
All three are why the "same wire as" column has to be read as a chain and not as a
transitive licence: 0.4.1 = 0.4.2, and 0.4.3 = 0.4.4 = 0.4.5 = 0.4.6 = 0.4.7 = 0.4.8 = 0.4.9 = 0.4.10 = 0.4.11,
while 0.4.12 opens a new wire group and is so far its only member,
but the three groups are NOT the same wire, and only the third describes
what a 0.4.12 operator serves. The formal spec
§14.2 now scopes its additivity promise to 1.0 and later, for the reason this
table already made visible: the compatibility mechanism on this protocol is the
operator's pin, which names one exact cut and its SHA-256. Adopt the cut the
operator pins — that is what the dual-check is for.

**0.3 and 0.4 are not interoperable.** 0.4 removed the multiplexed endpoints and
the response envelope outright, with no tombstones and no compatibility mode. An
assistant holding a 0.3.x cut against an operator pinning 0.4.x must adopt the
pinned cut first: the paths, the argument channel and the response shape all
differ. The pre-0.4 cuts stay published, unedited, because live pins reference
their bytes — not because the wire they describe is still served.
