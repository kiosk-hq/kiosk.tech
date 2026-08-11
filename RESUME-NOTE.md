# RESUME NOTE — K-625 (onboarding.html descriptor shape), branch onboarding-0811

Delete this file in the final commit (T-060).

## Task
K-625 (major, D8): `onboarding.html` teaches the RETIRED descriptor shape —
four registrations pass `params:` hint hashes, zero `input_schema`.
Rewrite under ADR-0023: semantics-only `description` + `input_schema`.

## Constraints
- `input_schema` is OPTIONAL in the normative spec (T-050 is the coverage work).
  SHOW it as the way; do NOT imply the spec requires it.
- `params` still travels on the wire (`describe` always writes the key →
  `"params": null`). Do NOT say it is forbidden / that omitting it breaks.
- `skill-v0.3.*.md` are sha-pinned in 7 demos — must stay byte-unchanged.

## Facts established (verified against the tree)
- getgrocery verbs: queries `catalog`, `delivery_slots`, `my_orders`;
  actions `payment_setup`, `create_order`, `reschedule_delivery`,
  `request_kyc`; query `kyc_status`.
- **`schedule_delivery` EXISTS NOWHERE in `reference/`** (only
  `reschedule_delivery`). onboarding's 4th example invents it, and the comment
  "exactly how the getgrocery demo gates schedule_delivery" is false.
- getgrocery `create_order` REQUIRES `delivery_slot_id` + `delivery_address`
  (K-468 address-upfront); delivery is part of the order, not a later step.
  `delivery_date` optional there (back-compat default = tomorrow).
- getgrocery `reschedule_delivery` required: `["order_id","delivery_slot_id"]`;
  gates = ownership/not-already-rescheduled + settlement exists.
- `lib/delivery_slots.rb` is getgrocery's shared slot-time source of truth (K-470).
- Seeds: sourdough-bread 449, greek-yogurt 389 → 2+1 = 1287 cents (matches the
  demo's own example_row).
- Register API (queries.rb/actions.rb) accepts
  `description:, params:, input_schema:, example_params:, example_row:`.
- CI (`.github/workflows/spec-schemas.yml`) enforces ASCII over `spec/` ONLY —
  onboarding.html is not ASCII-gated (it already ships en dashes, arrows, emoji).
- Page must stay at ZERO external subresources (K-519).

## Plan
1. Step 4 intro: teach prose=meaning / input_schema=shape, link house style. [done]
2. `lib/delivery_slots.rb` shared helper snippet. [done]
3. Rewrite all six registrations with `input_schema` (+ example_params/row on
   the primary read query and the primary action). [done]
4. `schedule_delivery` -> `reschedule_delivery` matching getgrocery; move
   delivery slot+address into `create_order`. [done]
5. Adjacent staleness: agent-experience list step 7, "these 7 steps",
   getgrocery `bin/demo` (does not exist; `rake demo` does). [done]
6. CHANGELOG one line. [done]
7. Gates: validate.sh, ASCII over spec/, skill_pin_spec, skill sha,
   HTML parse, zero external subresources, ajv over every input_schema. [done]
