---
name: kiosk-agent-commerce
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
**Check `~/.kiosk/<domain>/identity.json` first.** Only register if no identity exists.

- **Identity exists** → skip to Step 3. Re-register with the SAME key (`POST <endpoint>/agents/register` with stored public key) to get a fresh `access_token`. The server is **idempotent**: same public key ⇒ same `user_id`, so your saved card survives.
- **No identity** → generate RSA-2048 keypair, store PRIVATE key at `~/.kiosk/<domain>/key.pem`, save identity:
  ```json
  {"user_id": "...", "agent_id": "..."}
  ```
  at `~/.kiosk/<domain>/identity.json`. `chmod 600` both files.

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
- **Re-registration is safe:** Server matches existing public key → returns same `user_id`. Your card persists across sessions.
