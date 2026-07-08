---
name: kiosk-agent-commerce
version: "1.0"
description: "Universal protocol for agent-native commerce. Talk to any Kiosk-speaking provider — discover, register, browse, order, pay."
tags: [kiosk, agent-commerce, ap2]
trigger: <link rel="kiosk">
---
# Kiosk — Agent Commerce Protocol

You are an agent that acts on behalf of and in the best interests of your user.
Any site with `<link rel="kiosk">` speaks Kiosk.

## Architecture
REST endpoints — HTTP method carries semantics (GET = read, POST = write):

| Verb | Method | Endpoint | Role | Example body |
|------|--------|----------|------|-------------|
| `schema` | `GET` | `/schema` | Machine-readable surface | — |
| `query` | `POST` | `/query` | Read data | `{name:"catalog", ...params}` |
| `run` | `POST` | `/run` | Perform action | `{name:"create_order", ...params}` |
| `pay` | `POST` | `/pay` | Settle payment | `{intent_mandate_jws, cart_mandate_jws, payment_mandate_jws}` |

All queries go through `/query`, all actions through `/run`. The surface self-describes via `schema`.

## Flow (every provider, every visit)

### Step 1: Discover
`GET <origin>/.well-known/kiosk.json` → `endpoint`, `issuer`, `routing` (verb→method+path map).

### Step 2: Identity (REUSE if possible)
**Check `~/.kiosk/<domain>/identity.json` first.** A public key is not a credential — every token is issued only after you prove possession of the matching PRIVATE key. Both register and login are two steps: (1) `GET <endpoint>/auth/challenge?public_key=<url-encoded PEM>` → `{challenge}`; (2) sign a compact RS256 JWS `{aud, nonce, jti, iat}` with your private key and POST it. **`aud` MUST be the origin you actually connected to** — that's the relay defense (a proof for one provider can't be replayed at another). See «Auth handshake» below.

- **Identity exists** → `POST <endpoint>/auth/login {public_key, signed}` → `{access_token}`. Same key ⇒ same `user_id`, so your saved card survives. Do NOT re-register a known key — that's a `409`; use login.
- **No identity** → generate an RSA-2048 keypair, then `POST <endpoint>/auth/register {public_key, signed}` → `{user_id, agent_id, access_token}`. Store the PRIVATE key at `~/.kiosk/<domain>/key.pem` and identity `{"user_id":"…","agent_id":"…"}` at `~/.kiosk/<domain>/identity.json`. `chmod 600` both files.

### Step 3: Learn surface
`GET <endpoint>/schema` → list of queries, actions, params.

### Step 4: Browse & order
`POST <endpoint>/query {name:"catalog"}` → available products.
`POST <endpoint>/run {name:"create_order", items:[{sku,qty},...]}` → order.

### Step 5: Card setup (human-in-the-loop)
`POST <endpoint>/run {name:"payment_setup"}` → `{status:"setup_required", setup_url}` or `{status:"ready"}`.

**If `setup_required`:** hand the `setup_url` to the human. **NEVER fill Stripe forms with browser automation.** Poll `payment_setup` every few seconds until `status:"ready"`.

### Step 6: Pay
Sign 3 RS256 JWS mandates (intent → cart → payment). `iss` must match `/.well-known/kiosk.json#issuer` verbatim. Submit via `POST <endpoint>/pay {intent_mandate_jws, cart_mandate_jws, payment_mandate_jws}`. Payment mandate: `payment_method: "on_file"` for saved-card flow.

## Technical constraints
- **Use Python, not shell:** JWT signing requires `pyjwt` + `cryptography`. Keep access tokens in Python memory — never pass them as shell command arguments where they'd appear in history and process listings. Use Python's `urllib` (stdlib) or `requests` for all HTTP calls.
- **Key storage:** `~/.kiosk/<domain>/key.pem` (private) + `~/.kiosk/<domain>/identity.json` (user_id, agent_id). Both `chmod 600`. New RSA key per domain — no cross-merchant tracking.
- **Dependencies:** `pyjwt`, `cryptography`. Install if missing: `pip install pyjwt cryptography`.
- **Card setup:** Human-only. Present the `setup_url` to the user, poll until `status:"ready"`. Never automate Stripe forms.
- **Mandates:** Always submit all 3 — server may reject with `payment_mandate_jws required`.
- **Login vs register:** existing key → `/auth/login` (fresh token, same `user_id`, card persists); new key → `/auth/register`. Re-registering a known key is a `409` — use login. Tokens are short-lived; call `/auth/login` again to refresh. To sign out other sessions, `POST /auth/revoke` (returns a fresh token).

## Versioning & verification

This skill is versioned (see frontmatter `version`). The canonical source is `https://kiosk.tech/skill.md`.

**Dual-check.** Every Kiosk provider MUST include a `skill` field in their `/.well-known/kiosk.json`:

```json
{
  "skill": {
    "url": "https://kiosk.tech/skill-v1.0.md",
    "sha256": "abc123..."
  }
}
```

The agent:
1. Compares the provider's `skill.version` (from `kiosk.json`) with its own cached version
2. **If the provider's version is newer** — the agent MUST fetch and adopt the newer skill before transacting. The provider may depend on newer protocol features.
3. Verifies the SHA-256 hash matches the fetched content
4. Falls back to its locally cached skill if hash verification fails

**Backward compatibility.** Newer minor versions are backward-compatible — new endpoints and fields are additive, existing flows never break. An agent on v1.1 can transact with a v1.0 provider. A v1.0 agent MUST update before transacting with a v1.1 provider.

---

## Auth handshake (register / login)

Prove possession of your private key, origin-bound so the proof can't be relayed to another provider:

```python
import jwt, time, json, urllib.parse, urllib.request
from uuid import uuid4

origin = "https://getgroceries.com"          # the endpoint origin you dialed
pem    = pub_pem                              # your PUBLIC key PEM
ch = json.load(urllib.request.urlopen(
    f"{origin}/kiosk/auth/challenge?public_key={urllib.parse.quote(pem)}"))

signed = jwt.encode(
    {"aud": origin, "nonce": ch["challenge"], "jti": str(uuid4()), "iat": int(time.time())},
    private_key, algorithm="RS256")

# new key  → POST {origin}/kiosk/auth/register {"public_key": pem, "signed": signed}
# known key → POST {origin}/kiosk/auth/login    {"public_key": pem, "signed": signed}
```

`aud` MUST be the origin you connected to — the provider rejects a mismatch, and that rejection is exactly what stops a relayed/phished proof from taking over an account.

## AP2 payment mandates

Kiosk uses a three-mandate chain for every payment. This creates a verifiable audit trail — the agent cryptographically commits to *what* it intends to buy, *what* it actually ordered, and *how* it paid.

### What is a mandate?

A mandate is a JSON payload signed by the agent's RSA-2048 private key as a **RS256 JWS** (RFC 7515). The `iss` (issuer) field MUST match the provider's issuer string from `/.well-known/kiosk.json` exactly — copy it verbatim. Each mandate includes `iat` (issued-at timestamp) and `jti` (unique ID).

### The three mandates (in order)

| # | Mandate | What it says | Key fields |
|---|---------|-------------|------------|
| 1 | **Intent** | «I plan to spend up to X on Y» | `cap_amount_cents`, `scope` (e.g. `"grocery"`), `iss` |
| 2 | **Cart** | «This is exactly what I ordered» | `intent_mandate_id` (binds to #1), `line_items`, `total_amount_cents`, `iss` |
| 3 | **Payment** | «Charge my saved card» | `cart_mandate_id` (binds to #2), `payment_method: "on_file"`, `iss` |

Each mandate references the previous one — intent → cart → payment — forming a cryptographically linked chain. The server verifies all three signatures against the agent's registered public key.

### Signing in Python

```python
import jwt

private_key = open("~/.kiosk/<domain>/key.pem").read()
iss = "getgroceries.com"  # from /.well-known/kiosk.json

intent_jws = jwt.encode({
    "iss": iss, "iat": now, "jti": uuid4(),
    "cap_amount_cents": 5000, "scope": "grocery"
}, private_key, algorithm="RS256")

cart_jws = jwt.encode({
    "iss": iss, "iat": now, "jti": uuid4(),
    "intent_mandate_id": intent_id,
    "line_items": [{"sku": "milk", "qty": 2}],
    "total_amount_cents": 399
}, private_key, algorithm="RS256")

payment_jws = jwt.encode({
    "iss": iss, "iat": now, "jti": uuid4(),
    "cart_mandate_id": cart_id,
    "payment_method": "on_file"
}, private_key, algorithm="RS256")
```

Submit all three in one call:

```
POST <endpoint>/pay
{"intent_mandate_jws": "...", "cart_mandate_jws": "...", "payment_mandate_jws": "..."}
```

### Why three mandates?

Without agent-signed mandates, there's no non-repudiation. If the merchant charges $500 and the agent says «I authorized $50,» neither side can prove what was agreed. The intent mandate sets a ceiling. The cart mandate lists the exact items. The payment mandate authorizes the charge. Three signed JWS documents settle any dispute.
