# Kiosk Protocol -- Formal Specification

**Version 0.3** (Draft; wire format stable) - Status: for implementers and porters

This is the **formal** companion to the narrative specification at
<https://kiosk.tech/specification.html>. The narrative page is the readable
introduction; this document is the precise, citable contract, with
machine-readable [JSON Schemas](./schemas/) for every wire object. Where the two
disagree on the wire, **this document governs** and the narrative page is
corrected (audit dimension D8).

The protocol, the reference implementation, and the AI assistant skill share their
MAJOR.MINOR version (**version parity**). This document specifies protocol
version **0.3**.

---

## 1. Introduction

### 1.1 Scope

Kiosk is a thin HTTPS + JSON + JWS contract that lets an **operator** expose an
existing service API to a **customer's personal AI assistant**: the AI assistant discovers
the operator, registers a self-generated identity by proof of possession, reads a
self-describing surface, calls read (`query`) and write (`run`) verbs scoped to
its identity, and settles payment (`pay`) through a signed AP2 mandate chain. The
operator MAY meter anonymous load with a memory-hard proof-of-work toll and MAY
bind an AI assistant to an existing human account.

This document specifies the **invariants** -- everything every conforming operator
and every conforming AI assistant must agree on. The concrete queries and actions an
operator offers are operator-defined and discovered at runtime; they are not part
of this specification.

### 1.2 Conformance targets

Requirements bind two roles:

- **Operator** -- the party serving the endpoints.
- **AI assistant** -- the client calling them.

A requirement with no role prefix binds both. Section 16 gives the operator and
AI assistant conformance profiles.

### 1.3 Requirements notation

The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**,
**SHOULD**, **SHOULD NOT**, **RECOMMENDED**, **NOT RECOMMENDED**, **MAY**, and
**OPTIONAL** in this document are to be interpreted as described in
[BCP 14](https://www.rfc-editor.org/info/bcp14) ([RFC 2119](https://www.rfc-editor.org/rfc/rfc2119)
and [RFC 8174](https://www.rfc-editor.org/rfc/rfc8174)) when, and only when, they
appear in all capitals, as shown here.

JSON is used per [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259). Data types in
field tables are JSON types (`string`, `number`, `integer`, `boolean`, `object`,
`array`, `null`). "REQUIRED" / "OPTIONAL" in a field table describe presence.

### 1.4 Relationship to other specifications

Kiosk **embraces** existing agent-web standards where they fit and defines its own
wire only where they do not:

- Payment mandates follow **AP2** (Agent Payments Protocol) shapes (Section 11).
- Access tokens are **JWT** ([RFC 7519](https://www.rfc-editor.org/rfc/rfc7519))
  signed **JWS** ([RFC 7515](https://www.rfc-editor.org/rfc/rfc7515)); operator
  signing keys are published as **JWKS** ([RFC 7517](https://www.rfc-editor.org/rfc/rfc7517)).
- The account-binding claim ceremony reuses the **OAuth 2.0 Device Authorization
  Grant** ([RFC 8628](https://www.rfc-editor.org/rfc/rfc8628)) wire.
- The two `402` gates carry a `WWW-Authenticate` challenge per
  [RFC 7235](https://www.rfc-editor.org/rfc/rfc7235); the payment gate names the
  IETF `Payment` scheme.
- Discovery is additionally emitted into the standard agent-web surfaces
  (`agents.txt`, `agents.json`, `/.well-known/agent-configuration`,
  RFC 9727 `api-catalog`) as envelopes around the canonical `kiosk.json` (Section 4.5).

Kiosk-specific is the **wire contract**: the four verbs, the response envelope,
the error vocabulary, the identity-binding (session) semantics, and the
proof-of-work gate.

---

## 2. Terminology

- **Operator** -- a server implementing the operator profile (Section 16.1); the party a
  customer has (or is forming) a relationship with (a shop, a hotel, a service). An
  operator can be a service provider, an information steward, or a merchant/aggregator.
- **AI assistant** -- a consumer-side automated client acting on a person's behalf; holds
  a private key and makes the HTTP calls in this document.
- **Identity** -- the `{user_id, agent_id}` pair minted for an AI assistant's public key.
  `user_id` is the unit of data ownership; `agent_id` names the acting AI assistant.
- **Assistant account** -- an account backing an identity. Self-standing when
  created by registration; **linked** when bound to a human's operator account.
- **Discovery document** -- the JSON served at `/.well-known/kiosk.json` (Section 4).
- **kiosk-pop** -- Kiosk's proof-of-possession challenge-response auth scheme (Section 5).
- **Access token** -- a short-lived RS256 JWT the operator issues to an identity,
  presented as `Authorization: Bearer`.
- **Possession proof** (`signed`) -- a compact RS256 JWS over a server-issued
  single-use challenge, proving control of a public key.
- **Verb** -- one of the four fixed wire operations: `schema`, `query`, `run`,
  `pay`.
- **Capability** -- a verb a given operator actually serves (Section 4.3).
- **Envelope** -- the uniform `{ok, kind, ...}` / `{ok:false, error}` wrapper on
  every verb response (Section 8).
- **Mandate** -- one link of the signed AP2 payment chain: intent, cart, or
  payment (Section 11).
- **Proof-of-work (PoW)** -- a memory-hard, request-bound challenge an operator MAY
  require before serving a request (Section 10).
- **Reputation** -- an operator-local signal on an identity that sets its PoW proof
  count (Section 13).

---

## 3. Transport and common conventions

1. All endpoints are served over **HTTPS**. All request and response bodies are
   **JSON** unless a section states otherwise (the account-binding
   `/kiosk/oauth/*` endpoints use the OAuth wire, Section 6).
2. All wire verb requests are authenticated with `Authorization: Bearer <jwt>`
   except where a section marks an endpoint unauthenticated.
3. Signatures -- access tokens, possession proofs, and payment mandates -- use
   **RS256** (RSASSA-PKCS1-v1_5 with SHA-256) over 2048-bit RSA keys, encoded as
   compact JWS.
4. Endpoint paths derive from the discovery document's `endpoint` value plus the
   fixed verb-to-path binding in Section 8; an AI assistant MUST derive URLs this way and MUST
   NOT hard-code a mount path.
5. **Version parity and additivity.** Within a MINOR series (0.3.x) the wire is
   additive and backward-compatible: new endpoints and fields only, existing
   flows never break (Section 14).

---

## 4. Discovery

Schema: [`discovery.schema.json`](./schemas/discovery.schema.json).

### 4.1 The discovery document

Every operator **MUST** serve a discovery document at
`GET /.well-known/kiosk.json`, unauthenticated, so an AI assistant can bootstrap from
the origin alone. The document is a single object under a `kiosk` wrapper key.

| Field | Type | Presence | Meaning |
|---|---|---|---|
| `kiosk.version` | string | REQUIRED | Discovery-document format version (currently `"1.0"`), independent of protocol version. |
| `kiosk.issuer` | string | REQUIRED | The AP2 mandate `iss` anchor and token `iss`/`aud`. An absolute https origin. |
| `kiosk.endpoint` | string | REQUIRED | The wire-verb root (base URL + mount path). All verb and auth URLs derive from this. |
| `kiosk.capabilities` | array | REQUIRED | The verbs this endpoint serves, from `["schema","query","run","pay"]`, in that canonical order (Section 4.2). |
| `kiosk.min_client` | string | OPTIONAL | Advisory minimum client version. |
| `kiosk.owner` | object | OPTIONAL | Operator contact info; SHOULD include at least an email. |
| `kiosk.auth` | object | REQUIRED | The kiosk-pop auth block (Section 4.3). |
| `kiosk.skill` | object | OPTIONAL | Pinned skill reference `{url, sha256}` (Section 14.4). Omitted entirely when absent. |

### 4.2 `capabilities`

`capabilities` is the subset of the canonical verb set the operator actually
serves, derived from what it has registered: `schema` (present iff at least one
query or action is registered), `query` (iff a query is registered), `run` (iff
an action is registered), `pay` (iff payments are configured). HTTP methods are
**not** encoded -- the method binding is fixed (Section 8.1). An operator **MUST** emit
the canonical order and **MUST NOT** advertise a verb it does not serve.

### 4.3 The `auth` block

`kiosk.auth` **MUST** carry `kind: "kiosk-pop"` and the six URLs an AI assistant needs
to authenticate and bind: `challenge_url`, `register_url`, `login_url`,
`revoke_url` (Section 5), and `device_authorization_url`, `claim_url` (Section 6). Each is an
absolute URL derived from `endpoint`.

### 4.4 JWKS

An operator **MUST** publish its token-signing public keys as a JWKS document
(RFC 7517) at `GET <endpoint>/.well-known/jwks.json`, unauthenticated, so any
party can verify a Kiosk-issued token (Section 5.4). Each key carries `kty`,
`use: "sig"`, `alg: "RS256"`, a `kid`, and the public parameters `n`/`e` only.

### 4.5 The "speaks Kiosk" signal and standard surfaces

An operator MAY advertise Kiosk on its human-facing pages with a
`<link rel="kiosk" href="...">` tag (or an equivalent HTTP `Link` header). The tag
is a **signal, not a source**: its `href` points at the universal skill on
kiosk.tech, and an AI assistant **MUST NOT** load skill instructions from the operator
(Section 15.6). An operator MAY additionally emit the standard agent-web discovery
surfaces -- `agents.txt`, `agents.json`, `/.well-known/agent-configuration`
(RFC 8414-style), `/.well-known/api-catalog` (RFC 9727), and `/auth.md` -- as
envelopes around `kiosk.json`; when present they are rendered from the same
registry model and MUST NOT drift from `kiosk.json`, which remains canonical.
The payment directives on these surfaces are **conditional on the `pay`
capability**: `agents.txt` emits `Protocols: ap2` and `Payments: required`,
and `agents.json` includes its `payments` block (`ap2`, `required: true`),
**only** when the operator serves `pay` (Section 4.2); an operator that serves no
`pay` omits them, so the surfaces stay consistent with `capabilities`.

---

## 5. Registration and login (kiosk-pop)

Kiosk's auth scheme is **kiosk-pop**: a proof-of-possession challenge-response.
It is **not** OAuth. A public key is public, not a credential; before issuing a
token the operator requires proof of possession of the matching private key.

### 5.1 Challenge

`GET <endpoint>/auth/challenge?public_key=<url-encoded PEM>` returns a single-use,
short-lived challenge:

| Field | Type | Presence |
|---|---|---|
| `challenge` | string | REQUIRED -- the server-issued nonce to sign |
| `exp` | integer | REQUIRED -- Unix expiry |

### 5.2 The possession proof

The `signed` field submitted to register/login/claim/token is a compact **RS256
JWS** whose payload carries:

| Claim | Type | Presence | Rule |
|---|---|---|---|
| `aud` | string | REQUIRED | MUST be the origin the AI assistant dialed (Section 15.1); the operator rejects any other `aud`. |
| `nonce` | string | REQUIRED | The `challenge` from Section 5.1; single-use, server-TTL-bounded. |
| `jti` | string | REQUIRED | A unique id. |
| `pub` | string | OPTIONAL | RFC 7638 thumbprint of the public key; verified only when present. |
| `iat` | integer | OPTIONAL | Informational only; the server-issued `nonce` is the authoritative freshness bound. |

### 5.3 Register and login

Both take `{public_key, signed}` (register also accepts an optional `pow` field,
Section 5.5):

- `POST <endpoint>/auth/register` -- a **new** key. Returns `201` with
  `{agent_id, user_id, access_token}`. Registering an already-known key **MUST**
  answer `409 conflict` (use login).
- `POST <endpoint>/auth/login` -- a **known** key. Returns `200` with
  `{access_token}`. An unknown key **MUST** answer `404 not_found` (register
  first).

An operator **MUST** verify the possession proof before issuing a token, and
**MUST** map a known key to the same `user_id` so a saved payment card survives
across sessions. An AI assistant **SHOULD** generate a fresh keypair per operator origin
(Section 15.3).

### 5.4 Access-token format

The `access_token` is a 3-part **RS256 JWT** signed by the operator (verifiable
statelessly against the JWKS of Section 4.4) and presented as `Authorization: Bearer`.
Its claims:

| Claim | Type | Presence | Meaning |
|---|---|---|---|
| `sub` | string | REQUIRED | The identity's `user_id`. |
| `agent_id` | string | REQUIRED | The acting agent id. |
| `actor` | string | REQUIRED | `"agent"`. |
| `role` | string | OPTIONAL | Operator-assigned role; **omitted** (not null) when absent. Registration **MUST NOT** accept a client-requested role. An operator **MAY** source an AI assistant's role from a configured IdP from 0.3, INDIRECTLY via the bound human's role: at the account-binding link ceremony (Section 6) the human's IdP role is captured and set as the bound AI assistant's role. Direct agent-IdP (ID-JAG) role assertion stays planned. |
| `iss` / `aud` | string | REQUIRED | The operator issuer. |
| `iat` / `nbf` / `exp` | integer | REQUIRED | Validity window (default 1 hour). |
| `jti` | string | REQUIRED | Unique token id. |

### 5.5 Token lifetime, revocation, and the registration toll

Access tokens are short-lived; the durable credential is the private key. Multiple
concurrent tokens for one identity remain valid. `POST <endpoint>/auth/revoke`
(Bearer) stamps a per-identity "revoked-before" watermark -- every token issued
before that instant stops verifying -- and returns a fresh token (Section 15.4). An
operator **MAY** price fresh-identity minting: `POST /auth/register` **MAY**
answer `402 pow_required` (Section 10) bound to the registering public key; the AI assistant
solves and resubmits the same `signed` with a `pow` field. Default is no toll.

---

## 6. Account binding -- claim and link

kiosk-pop registration creates a self-standing assistant account. When the human
already has an operator account, Kiosk **binds** the AI assistant to it via a one-time
ceremony. Binding requires **BOTH** human approval **AND** a valid possession
proof; a failed proof binds nothing (Section 15.8). After binding, the AI assistant uses
`/auth/login` like any identity.

### 6.1 Claim (AI-assistant-initiated, RFC 8628 device grant)

1. `POST <endpoint>/oauth/device_authorization` (form-encoded) with
   `client_id` (REQUIRED), `public_key` (REQUIRED), and an optional `scope`/`role`.
   Returns `{device_code, user_code, verification_uri, verification_uri_complete,
   expires_in, interval}`.
2. The AI assistant shows the human `verification_uri` + `user_code`; the human approves
   on the operator's session-authenticated page (Section 15.8).
3. The AI assistant polls `POST <endpoint>/oauth/token` (form-encoded) with
   `grant_type=urn:ietf:params:oauth:grant-type:device_code`, `device_code`, and
   -- once approved -- `signed` (the possession proof of Section 5.2). On success it
   returns OAuth-shaped `{access_token, token_type: "Bearer", expires_in}` (the
   bound identity rides in the JWT claims, not the body).

The `/oauth/*` endpoints are the **one exception** to the Kiosk envelope: they use
the OAuth wire, with errors `authorization_pending`, `slow_down`, `expired_token`,
`access_denied`, `invalid_grant`, and `invalid_client` (a failed possession proof).

### 6.2 Link (human-initiated -- Kiosk extension)

The human, signed in on the operator's site, mints a single-use link code:

- `POST <endpoint>/auth/link` (operator session) -> `{link_code, expires_in}`. The
  code is a long opaque token (paste-grade).
- The AI assistant redeems it: `POST <endpoint>/auth/claim` with `{code, public_key,
  signed}` -> `201 {agent_id, user_id, access_token}`.

### 6.3 Fresh vs. rebind, and unlink

A key the operator has never seen becomes a **linked assistant account** under the
human's `user_id`. A key that already had a self-standing account is **rebound**:
its `agent_id` is stable, its `user_id` becomes the human's, and its reputation
carries over -- claiming is **not** a reputation reset (Section 13). Because a rebind is a
principal change, the key's **pre-link tokens** (still carrying the old `user_id`)
**MUST** stop verifying, watermark-revoked exactly as unlink revokes (Section 15.4); the
AI assistant obtains a token under the new principal from the `access_token` the claim
returns, or by re-running `/auth/login`. `POST <endpoint>/auth/unlink` (operator
session, `{agent_id}`) is registration-layer revocation: the key's tokens stop
verifying and `/auth/login` answers `404` (Section 15.4). Codes are stored hashed,
single-use, short-TTL, and attempt-capped.

---

## 7. Identity binding (the session contract)

Every authenticated verb call executes **as** the identity carried by its Bearer
token -- the `{user_id, agent_id}` pair.

1. The operator **MUST** resolve the token to its identity on every authenticated
   request, before the verb runs.
2. The operator **MUST** scope every read a `query` performs and every write or
   side effect a `run` or `pay` performs to the authenticated `user_id`. Rows
   owned by another `user_id` **MUST NOT** be readable or affectable through this
   token.
3. Operator-registered queries and actions **MUST NOT** execute with no identity
   bound.

How the operator enforces scoping (application-layer filtering, database
row-level security, or both) is out of scope for the wire. The requirement is the
observable behavior: cross-identity reads and writes fail (`403 forbidden` or
`403 rls_denied`, Section 9).

> *Reference note (non-normative).* The Ruby reference propagates the identity
> into PostgreSQL as a transaction-scoped setting (`kiosk.current_user_id()`) and
> offers opt-in row-level-security policies as defense in depth.

---

## 8. Wire verbs and the response envelope

Schemas: [`envelope.schema.json`](./schemas/envelope.schema.json),
[`schema-descriptor.schema.json`](./schemas/schema-descriptor.schema.json).

### 8.1 Verb-to-path binding

The four verbs are bound to fixed methods and paths under `endpoint`:

| Verb | Method | Path | Auth |
|---|---|---|---|
| `schema` | GET | `<endpoint>/schema` | Bearer |
| `query` | POST | `<endpoint>/query` | Bearer |
| `run` | POST | `<endpoint>/run` | Bearer |
| `pay` | POST | `<endpoint>/pay` | Bearer |

All POST bodies are JSON. The concrete query and action **names** are
operator-defined and discovered via `schema`; they are not part of this
specification.

### 8.2 Response envelope

Every `schema`/`query`/`run`/`pay` response -- success or error -- **MUST** be one
of two shapes. A success carries `ok: true` and a `kind` discriminator naming the
payload field:

- `kind: "rows"` -> payload under `rows` (array; queries).
- `kind: "value"` -> payload under `value` (object; `schema`, actions, `pay`).
- `kind: "events"` -> payload under `events` (reserved).

An error carries `ok: false` and an `error` object (Section 9). An AI assistant **MUST** branch
on the envelope and on `error.code`, never on the HTTP status alone.

### 8.3 The `schema` verb

`GET <endpoint>/schema` (Bearer) returns a `kind: "value"` envelope whose `value`
is `{verbs, queries, actions}`. `verbs` is the invariant four -- all of
`query`, `run`, `pay`, `schema`, always (`events` is reserved) -- naming the
protocol surface itself, NOT the served subset. The served subset is
`capabilities` in `/.well-known/kiosk.json`, which is computed from what the
operator actually registered (it drops `pay` when no payment provider is
configured); do not treat these `verbs` as mirroring what the origin advertises.
`queries` and `actions` are arrays of `{name, description, params}` descriptors,
sorted by name; `description` is a string or `null`, and `params` is a free-form
operator-defined hint object or `null` -- documentation, not a validation contract
(the operator validates arguments server-side).

---

## 9. Error vocabulary

Schema: [`error.schema.json`](./schemas/error.schema.json).

The `error` object is `{code, message?, hint?, challenges?}`. `code` is a closed,
stable vocabulary; `hint` is an optional remediation pointer; `challenges` appears
**only** on `pow_required`.

| `code` | HTTP | Meaning |
|---|---|---|
| `bad_request` | 400 | Malformed request: unparseable body, missing/invalid fields, unknown verb. |
| `unauthenticated` | 401 | Missing, invalid, expired, wrong-issuer, or revoked Bearer token. |
| `forbidden` | 403 | Authenticated, but this identity may not do this. |
| `rls_denied` | 403 | A row-level-security policy denied the statement (opt-in RLS). |
| `spending_cap_exceeded` | 403 | The acting assistant's per-assistant spending cap would be exceeded by this `pay` (Section 11.5); the human must raise the cap. |
| `kyc_required` | 403 | An Action requires KYC attribute(s) the AI assistant has not attested (Section 12.2); `hint` names what is needed. The AI assistant submits a KYC attestation carrying the missing attributes, then retries. |
| `not_found` | 404 | Unknown query/action name or missing resource; `hint` carries known names. |
| `conflict` | 409 | State conflict -- e.g. registering an already-registered key. |
| `pow_required` | 402 | Proof-of-work gate; carries `challenges` and `WWW-Authenticate: Kiosk-PoW` (Section 10). |
| `payment_setup_required` | 402 | Payment gate: no card on file; no `challenges`; carries `WWW-Authenticate: Payment` (Section 11.4). |
| `quota_exceeded` | 429 | Reserved for the quotas companion; the core operator never emits it. |
| `action_failed` | 500 | An operator-registered action raised. |
| `internal_error` | 500 | Catch-all server error. |

The auth endpoints speak the same envelope; the only exception on the wire is the
account-binding `/oauth/*` pair, which uses the OAuth error object (Section 6.1).

---

## 10. Proof-of-work

Schema: [`pow.schema.json`](./schemas/pow.schema.json).

An operator **MAY** require proof-of-work before serving a request. The gate
responds `402` with `error.code: "pow_required"` and `WWW-Authenticate: Kiosk-PoW
realm="<issuer>"` (Section 9), carrying a `challenges` array. Each challenge is
`{id, alg, params, salt, exp, sig}`:

| Field | Type | Rule |
|---|---|---|
| `id` | string | Opaque unique id. |
| `alg` | string | Algorithm; default `"equihash"`. |
| `params` | object | Algorithm parameters; for equihash `{n, k}` (default n=168, k=7). |
| `salt` | string | Per-challenge random salt (no amortization across proofs). |
| `exp` | integer | Expiry; scales with the number of requested proofs. |
| `sig` | string | HMAC-SHA256 over the challenge fields plus a fingerprint of the exact request. |

Each challenge is **stateless and request-bound** (the server stores nothing to
trust it) and single-use. The AI assistant **MUST** solve **every** challenge and retry
the **identical** request body with an added top-level `pow` field -- either
`{proofs: [{challenge, nonce}, ...]}` or, for a single challenge, the shorthand
`{challenge, nonce}`. The `pow` field is excluded from the request fingerprint so
the retry matches the original. `nonce` is `{indices: [...]}`; the `indices` array
**MUST** be in **Zcash canonical (subtree/tree) order** -- a globally-sorted array
is rejected. An operator requests **N independent proofs** as a rate-limiting knob
(reputation sets N, Section 13); PoW is a metered toll, not a hardware wall (Section 15.5).

---

## 11. Payment (AP2 mandate chain)

Schema: [`mandates.schema.json`](./schemas/mandates.schema.json).

### 11.1 The three mandates

Payment follows **AP2**: the AI assistant authorizes a purchase through a chain of three
signed mandates rather than by handling card data. Each mandate is an **RS256
JWS** signed with the AI assistant's private key. Every mandate **MUST** carry the base
claims `id`, `user_id`, `agent_id`, `iss`, `iat`, `exp`; the server **MUST**
reject a mandate whose `user_id`/`agent_id` do not match the authenticated
identity, whose `iss` is not its own issuer (verbatim from `kiosk.json`), or whose
`exp` is missing or passed.

| # | Mandate | Own fields (all REQUIRED unless noted) |
|---|---|---|
| 1 | Intent | `cap_amount_cents`, `currency`, `scope`? |
| 2 | Cart | `intent_mandate_id`, `total_amount_cents`, `currency`, `line_items`? |
| 3 | Payment | `cart_mandate_id`, `amount_cents`, `currency`, `payment_method`? |

### 11.2 Binding rules

`cart.intent_mandate_id` **MUST** equal the intent's `id`; the cart total **MUST
NOT** exceed the intent cap; `cart.currency` **MUST** equal the intent currency.
`payment.cart_mandate_id` **MUST** equal the cart's `id`; `payment.amount_cents`
**MUST** equal the cart total in the same `currency`. The server verifies all
three signatures against the AI assistant's registered key -- providing non-repudiation.

### 11.3 The pay call

`POST <endpoint>/pay` (Bearer) with
`{intent_mandate_jws, cart_mandate_jws, payment_mandate_jws}`. On success it
returns a `kind: "value"` envelope whose `value` is
`{settlement_id, psp_reference, settled_amount_cents, currency}`.

### 11.4 Card setup

Payment uses the PSP's card-on-file (SetupIntent) model. An AI assistant **SHOULD** call
the operator's `payment_setup` action before paying. If no card is on file, `pay`
answers `402` with `payment_setup_required` (no `challenges`) and
`WWW-Authenticate: Payment realm="<issuer>", method="ap2"`. The AI assistant **MUST NOT**
automate the card form: it hands the returned `setup_url` to the human, who enters
the card on the PSP's hosted page, then the AI assistant retries pay (Section 15.7).

### 11.5 Per-assistant spending cap (optional)

An operator MAY cap what an individual bound assistant (Section 6) may settle -- the
natural governance control when one human has several assistants bound to their
account. When a cap is configured for the acting `agent_id` and this `pay` would
push the assistant's settled total (optionally within a rolling window) past the
cap, the operator **MUST** reject it with `403 spending_cap_exceeded` **before**
the irreversible capture -- no charge, no settlement row. A cap of `0` disables the
assistant's payments entirely. The AI assistant cannot pay past the cap; it surfaces the
condition to the human, who raises the cap out of band. Caps are operator policy
and off by default; how an operator stores and edits them is out of scope for the
wire.

> *Reference note (non-normative).* The Ruby reference enforces this via the
> `config.spending_cap` pay-hook seam and ships a column-backed default
> (`agents.spending_cap_cents`) editable from the manage-assistants page.

---

## 12. KYC

Schema: [`kyc.schema.json`](./schemas/kyc.schema.json).

An operator MAY require a KYC attestation. The AI assistant carries a signed
**attestation** from a KYC provider -- never raw documents. The attestation is an
**RS256 JWS** with claims `{sub, level, iss, iat, exp}` and an OPTIONAL
`attributes` object: `sub` **MUST** equal the authenticated `user_id`, `iss`
**MUST** equal the operator-configured KYC issuer, `exp` **MUST** be present and
unexpired, and `level` **MUST** be exactly `"verified"` (anything else is
rejected). The AI assistant submits it to `POST <endpoint>/agents/kyc` (Bearer) as
`{kyc_jws}`; on a clean verify the operator records verification and returns
`{kyc_verified: true, attributes: {...}}`.

### 12.1 Named anonymized attributes

The attestation MAY carry an **`attributes`** object of `{name: true}` booleans
(e.g. `{"age_over_18": true, "licence_a": true}`). These are **anonymized**: the
operator learns only the booleans the KYC issuer signed -- it **MUST NOT** receive
or store the underlying documents (date of birth, licence number, passport scan).
An operator **MUST** honour only values that are literally `true`; any other value
(`false`, string, number) is **NOT** a grant. The operator **MUST** record the
granted attributes with the verification (the reference stores them in a
`kyc_attributes` column) and **MUST NOT** log the underlying documents. The field
is **additive**: a bare `level: "verified"` attestation with no `attributes` still
verifies (the binary path), yielding an empty attribute set.

### 12.2 Attribute-gated Actions

An Action MAY be **gated** on a set of required attribute names. When the calling
AI assistant's recorded attributes do not include every required name as `true`, the
operator **MUST** reject with `kyc_required` (HTTP **403**), carrying a hint
naming what is needed (e.g. "complete KYC: age>=18 and category-A licence
required"). The reference `kiosk-demo-skooti` gates `rent_motorcycle` (a
combustion-engine motorcycle) on `age_over_18` **AND** `licence_a`, while the
licence-free electric scooter needs neither -- the gate is per-Action.

---

## 13. Reputation

Reputation is an **operator-local** signal on an identity: successful transactions
raise it, suspicious behavior lowers it. It is operator-local because a keypair is
unique per origin (Section 5), so no cross-operator identifier exists.

1. An operator **MAY** vary the PoW **proof count** (Section 10) as a function of
   reputation rather than varying difficulty: an established identity solves 0-1
   proofs, an unknown one ~3, a flagged abuser ~10.
2. Minting a fresh identity **MUST NOT** be blocked; it starts at the unknown tier
   and pays the corresponding toll. Shedding a reputation therefore costs at least
   as much work as complying and forfeits accrued standing -- whitewashing is
   priced, not prevented.

---

## 14. Versioning

1. **Version parity.** The protocol, the reference implementation, and the AI assistant
   skill share MAJOR.MINOR. An operator on Kiosk 0.3 pins a 0.3 skill against a 0.3
   wire.
2. **Additivity within a MINOR series.** A new MINOR (0.2 -> 0.3) is a feature
   milestone that bundles backward-compatible additions -- new endpoints and
   fields only. Within 0.3.x the wire stays backward-compatible and additive:
   patches add endpoints and fields only; existing request/response fields and
   their meaning **MUST NOT** change or be removed. An AI assistant **MUST** ignore
   unknown response fields.
3. **Discovery-document format version.** The `version` field inside
   `/.well-known/kiosk.json` is the **discovery-document format version**
   (currently `"1.0"`), independent of the protocol version this document
   specifies.
4. **Skill version.** Published skill files are immutable and versioned
   (`skill-vX.Y.Z.md`); a change ships a new file. An operator's optional `skill`
   pin is a versioned URL plus its SHA-256 and cannot drift by construction (Section 4.1).
   An AI assistant performs the dual-check before transacting: read the pinned version
   from the URL, adopt it if newer than its cached skill, fetch it **from
   kiosk.tech** (never from the operator), and verify both the frontmatter
   `version` and the `sha256`.

---

## 15. Security considerations

This section consolidates the security-relevant requirements stated throughout
the document.

### 15.1 Origin binding (relay/phishing defense)

The possession proof's `aud` claim (Section 5) **MUST** be the origin the AI assistant actually
connected to, filled in by the AI assistant from the connection it dialed and never
echoed from server-supplied data. An operator **MUST** reject any proof whose
`aud` is not its own origin. This prevents a signature captured by a malicious
endpoint from being relayed to a different operator (the WebAuthn anti-phishing
model). The AP2 mandate `iss` claim (Section 11) carries the same audience-binding.

### 15.2 Replay and freshness

Auth challenges are server-issued, single-use, and expire on a server-held TTL;
the server-held nonce is the authoritative anti-replay bound. PoW challenges are
request-bound (their HMAC `sig` covers a fingerprint of the exact request) and
single-use (a spent-id set). Payment mandates carry their own `iat`/`exp` window
and are chain-bound (Section 11); a non-expiring mandate **MUST** be rejected.

### 15.3 Key hygiene and per-origin identity

An AI assistant **SHOULD** generate a fresh keypair per operator origin: the keypair is
the identity, and a per-origin key means no cross-operator identifier exists. The
private key is the durable credential; access tokens are short-lived and
disposable.

### 15.4 Token revocation

`/kiosk/auth/revoke` stamps a per-identity "revoked-before" watermark so every
token issued before that instant stops verifying, then returns a fresh token.
Unlink (Section 6) is registration-layer revocation: an unlinked key's tokens stop
verifying and `/auth/login` answers `404`.

### 15.5 Proof-of-work is a toll, not a wall

PoW meters and prices anonymous load; it does not equalize a laptop against
special-purpose hardware (Equihash is neither ASIC- nor GPU-proof). Abuse
resistance comes from reputation and caps (Section 13); PoW makes free-riding cost
something and gives the operator a cheap verify (Section 10). Operators **MUST NOT** rely
on PoW alone for abuse prevention.

### 15.6 Skill instructions come from kiosk.tech only

An AI assistant **MUST NOT** load skill (executable) instructions from the operator; a
`<link rel="kiosk">` tag is a discovery *signal*, not an instruction *source*
(Section 4.5). Operator-served content (schema, prices, availability) is data, not
instructions.

### 15.7 Card data

An AI assistant **MUST NOT** automate the card-entry form; card capture happens on the
PSP's hosted page (Section 11). The AI assistant only relays the setup URL to the human.

### 15.8 Binding ceremony integrity

The claim/link ceremonies (Section 6) require BOTH human approval AND a valid possession
proof before a binding is created; a failed proof binds nothing. Codes are stored
hashed, are single-use, expire on a short TTL, and are attempt-capped; the human
verify page **MUST** require an authenticated session and **MUST** display what is
being bound.

---

## 16. Conformance

### 16.1 Operator profile

An implementation is a **Kiosk operator** when it serves the core plus whichever
optional modules it advertises in `capabilities`:

1. **Core -- discovery** (Section 4): `/.well-known/kiosk.json` and the JWKS document.
2. **Core -- auth (kiosk-pop)** (Section 5): challenge / register / login / revoke with
   proof-of-possession verification, origin-bound `aud` rejection, single-use
   server-held nonces, RS256 JWT access tokens, and the revoked-before watermark.
3. **Core -- wire** (Section 8, Section 9): `schema` (GET), `query`/`run` (POST), the response
   envelope, and the error vocabulary.
4. **Core -- identity binding** (Section 7): every verb scoped to the authenticated
   identity.
5. **Module `pay`** (Section 11): AP2 mandate-chain verification and the
   `payment_setup_required` 402 with `WWW-Authenticate: Payment`.
6. **Module proof-of-work** (Section 10): the Equihash 402 gate.
7. **Module binding** (Section 6): the claim ceremony and/or link-code redeem, with
   fresh/rebind semantics and unlink.
8. **Module KYC** (Section 12): the attestation endpoint.

### 16.2 AI assistant profile

A client is a **Kiosk-compatible AI assistant** when it: branches on `error.code`, never
the HTTP status alone; fills the proof `aud` from the origin it dialed; solves
every challenge in a `pow_required` list and retries the identical body plus the
`pow` field; runs `payment_setup` and hands `setup_url` to the human rather than
automating card entry; performs the skill dual-check; and, when the human owns an
existing operator account, binds instead of registering.

### 16.3 Conformance anchors

Two oracles pin behavior beyond this text:

1. **JSON Schemas** (`./schemas/`) -- every wire object validates against its
   schema. Operators and AI assistants SHOULD validate against them.
2. **Frozen Equihash known-answer tests** at production parameters (n=168, k=7) --
   a ported verifier MUST reproduce them.

The reference end-to-end harness exercises the golden path
(discovery -> register -> schema -> query -> run -> pay, plus the error envelopes) an
independent implementation should survive. A published stack-neutral black-box
conformance suite does not exist yet (Tier 3, deferred).

---

## 17. JSON Schemas

Machine-readable schemas for every wire object live in
[`./schemas/`](./schemas/) (JSON Schema draft 2020-12):

| Object | Schema |
|---|---|
| Discovery document | [`discovery.schema.json`](./schemas/discovery.schema.json) |
| Response envelope | [`envelope.schema.json`](./schemas/envelope.schema.json) |
| Error object | [`error.schema.json`](./schemas/error.schema.json) |
| Schema descriptor | [`schema-descriptor.schema.json`](./schemas/schema-descriptor.schema.json) |
| PoW challenge + proof | [`pow.schema.json`](./schemas/pow.schema.json) |
| AP2 mandates | [`mandates.schema.json`](./schemas/mandates.schema.json) |
| KYC attestation | [`kyc.schema.json`](./schemas/kyc.schema.json) |

---

## 18. References

- BCP 14 (RFC 2119, RFC 8174) -- Requirement keywords
- RFC 7515 (JWS), RFC 7517 (JWK), RFC 7519 (JWT) -- token formats
- RFC 7235 -- HTTP authentication framework (`WWW-Authenticate`)
- RFC 8259 -- JSON
- RFC 8628 -- OAuth 2.0 Device Authorization Grant
- AP2 -- Agent Payments Protocol (mandate shapes)
- Narrative specification -- <https://kiosk.tech/specification.html>
