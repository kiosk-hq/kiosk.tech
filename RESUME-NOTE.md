# RESUME NOTE — spec-adr23-0811 (delete in the final commit, T-060)

Task: K-598 (ADR-0023 rollout onto the NORMATIVE surfaces), K-608 (phantom
passport in specification.html:497), K-525 (assess only).

## Verified premises (done)

- `Queries#describe` (reference/kiosk-server/lib/kiosk/server/queries.rb:76)
  always puts `params:` in the descriptor hash, so a descriptor registered
  without `params:` publishes `"params": null`. No wire break from the
  retirement; `required: ["...","params"]` is satisfied today.
- input_schema coverage: 17 of the 49 verbs the 7 demo initializers register.
  So `input_schema` CANNOT be made REQUIRED yet (T-050 owns coverage).
- Nothing in `reference` consumes kiosk.tech/spec/schemas/schema-descriptor.schema.json
  (only pow.schema.json is vendored), so relaxing its `required` breaks nothing.
- K-608 premise confirmed: kiosk-demo-prove ships a checkbox self-attestation
  page (app/views/verifications/show.html.erb) + 3 booleans (lib/claim_catalog.rb);
  README: "it never sees a document". No document handling anywhere.
- K-525: `grep -rn 'output_schema\|result_schema'` over all of reference — re-run below.

## Plan / status

1. [ ] schema-descriptor.schema.json — `params` out of `required`, descriptions rewritten
2. [ ] specification.html:175-176 + the example block :155-170
3. [ ] spec/protocol.md §8.3 (:401-427) + examples/schema-descriptor.json
4. [ ] specification.html:497 (K-608)
5. [ ] CHANGELOG lines, gates, delete this file

DO NOT: make input_schema REQUIRED; touch spec/protocol.md:653; touch any
skill-v0.*.md; touch reference/ or meta/.
