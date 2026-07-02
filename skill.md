---
name: kiosk-agent-commerce
description: "Universal protocol for agent-native commerce. Talk to any Kiosk-speaking provider — discover, register, browse, order, pay."
tags: [kiosk, agent-commerce, ap2]
trigger: <link rel="kiosk">
---
# Kiosk — Agent Commerce Protocol

You are an agent that transacts on behalf of your user. Any site with `<link rel="kiosk">` speaks Kiosk.

## Architecture
Five verbs exposed as REST endpoints — HTTP method carries semantics (GET = read, POST = write):

| Verb | Method | Endpoint | Role | Example body |
|------|--------|----------|------|-------------|
| `schema` | `GET` | `/schema` | Machine-readable surface | — |
| `query` | `POST` | `/query` | Read data | `{name:"catalog", ...params}` |
| `run` | `POST` | `/run` | Perform action | `{name:"create_order", ...params}` |
| `pay` | `POST` | `/pay` | Settle payment | `{intent_mandate_jws, cart_mandate_jws, payment_mandate_jws}` |

All queries go through `/query`, all actions through `/run`. The surface self-describes via `schema`.

## Flow (every provider, every time)
1. **Discover:** `GET <origin>/.well-known/kiosk.json` → `endpoint`, `issuer`, `routing` (verb→method+path map)
2. **Register:** `POST <endpoint>/agents/register` with freshly generated RSA-2048 public key → `agent_id`, `user_id`, `access_token`. Store keypair at `~/.kiosk/<domain>/key.pem` (chmod 600). **Before registering, check `~/.kiosk/<domain>/key.pem` for existing credentials — reuse if found.**
3. **Learn surface:** `GET <endpoint>/schema` → list of queries, actions, params
4. **Query:** `POST <endpoint>/query {name:"<name>", ...params}` → rows
5. **Run:** `POST <endpoint>/run {name:"<name>", ...params}` → action result
6. **Pay:** Sign 3 RS256 JWS mandates (intent → cart → payment). `iss` must match `/.well-known/kiosk.json#issuer` verbatim. Submit via `POST <endpoint>/pay {intent_mandate_jws, cart_mandate_jws, payment_mandate_jws}`. Payment mandate: `payment_method: "on_file"` for saved-card flow.

## Technical constraints
- **Use Python, not shell:** JWT signing requires `pyjwt` + `cryptography`. Keep access tokens in Python memory — never pass them as shell command arguments where they'd appear in history and process listings. Use Python's `urllib` (stdlib) or `requests` for all HTTP calls.
- **Key storage:** `~/.kiosk/<domain>/key.pem` (chmod 600). New RSA key per domain — no cross-merchant tracking.
- **Dependencies:** `pyjwt`, `cryptography`. Install if missing: `pip install pyjwt cryptography`.
- **Card setup:** `payment_setup` → `{status:"setup_required", setup_url}` → human enters card on Stripe → poll until `{status:"ready"}`.
- **Catalog items:** reference by `sku`, never display name. `create_order` uses `items: [{sku, qty}]`.
- **Mandates:** Always submit all 3 — server may reject with `payment_mandate_jws required`.
