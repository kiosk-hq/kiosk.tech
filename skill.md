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

Adding a new query or action NEVER adds a new route — all queries go through `/query`, all actions through `/run`. The surface self-describes via `schema`.

## Flow (every provider, every time)
1. **Discover:** `GET <origin>/.well-known/kiosk.json` → `endpoint`, `issuer`, `verbs`
2. **Register:** `POST <endpoint>/agents/register` with freshly generated RSA-2048 public key → `agent_id`, `user_id`, `access_token`. New keypair per provider domain, stored at `~/.kiosk/<domain>/key.pem`.
3. **Learn surface:** `GET <endpoint>/schema` → list of queries, actions, params
4. **Query:** `POST <endpoint>/query {name:"<name>", ...params}` → rows
5. **Run:** `POST <endpoint>/run {name:"<name>", ...params}` → action result
6. **Pay:** Sign 3 RS256 JWS mandates (intent → cart → payment). `iss` must match `/.well-known/kiosk.json#issuer`. Submit via `POST <endpoint>/pay {intent_mandate_jws, cart_mandate_jws, payment_mandate_jws}`.

## Technical constraints
- **JWT redaction:** Hermes masks JWT tokens as `***` in terminal(). Use Python `urllib` inside `execute_code` to keep tokens in memory only.
- **Key storage:** `~/.kiosk/<domain>/key.pem` (chmod 600). New RSA key per domain — no cross-merchant tracking.
- **Dependencies:** `pyjwt`, `cryptography`. Install if missing: `pip install pyjwt cryptography`.
- **Card setup:** `payment_setup` → `{status:"setup_required", setup_url}` → human enters card on Stripe → poll until `{status:"ready"}`.
- **Catalog items:** reference by `sku`, never display name. `create_order` uses `items: [{sku, qty}]`.
- **Mandates:** Always submit all 3 — server may reject with `payment_mandate_jws required`.
