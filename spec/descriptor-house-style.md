# Kiosk Descriptor House Style

**Companion to** the formal specification's Section 8.3 (the `schema` verb) --
<https://kiosk.tech/spec/protocol.md>. Non-normative: this is a WRITING GUIDE,
not a wire contract. The protocol says a descriptor MAY carry `description`,
`params`, `input_schema`, `example_params`, and `example_row`; this document
says how to write them WELL so a cold AI assistant can drive your origin from
the `schema` catalog alone, with no hardcoded knowledge and no call-and-observe
probing.

The consumer is an LLM that reads prose. Two things it still gets wrong by
reading -- what a call takes (types, ranges, required vs optional) and what a
row looks like -- are exactly what the machine-readable fields pin down. Write
the meaning in prose; pin the shape in schema and examples.

The acceptance test for a good descriptor is the **cold-assistant run**: a
fresh assistant, given only `GET /kiosk/schema`, reaches the user's goal on the
first well-formed call. If it has to guess a field name, a currency, an id
format, or whether a list is complete, the descriptor is under-written.

---

## The five fields

Each query/action descriptor is `{name, description, params}` plus the three
optional machine-readable extensions. Write all five for the PRIMARY read query
and PRIMARY action of an origin (the ones an assistant hits first); the rest MAY
carry only `description` + `params`.

### 1. `description` -- prose semantics (REQUIRED)

Say, in the assistant's terms, WHAT the verb does and WHAT it returns. Then
state the things prose alone must carry because a schema cannot:

- **Constraints and defaults** -- "amount is in EUR cents", "dates are
  `YYYY-MM-DD`", "page size defaults to 20". Name the currency and the id
  format explicitly; an assistant cannot infer "EUR" or "the id from a prior
  row" from types.
- **For a LIST query: say it paginates.** State the default page size, that a
  top-level `next` cursor means more rows match, and that the assistant should
  echo `next` back verbatim as `cursor` and keep paging until `next` is absent.
  An assistant that does not know a query paginates will silently act on a
  truncated list.
- **For a SEARCH query: tell it to filter, not fetch-all.** "Apply the user's
  stated constraints as filters; do not fetch the whole catalogue."
- **For a WRITE action: name the follow-on.** If the result must be paid for or
  confirmed, say which cart/mandate shape or which next action closes the loop
  (e.g. "sign your AP2 cart in EUR at the quoted `total_cents` referencing the
  returned `booking_id`").

Semantics live ONLY here. `input_schema` never carries meaning -- only shape.

### 2. `input_schema` -- machine input contract (JSON Schema, draft 2020-12)

A JSON Schema object for the verb's INPUTS. Rules of house style:

- `"type": "object"` with `"additionalProperties": false` ALWAYS -- an unknown
  field is a bug, and the closed object tells the assistant it has the full set.
- List every accepted param under `properties` with its `type`. Add a one-line
  `description` per property (shape only -- the prose meaning is in the
  descriptor's `description`).
- Constrain the shape: `enum` for closed sets (neighbourhoods, statuses,
  categories, amenities), `minimum`/`maximum` for ranges (a 1..5 star rating, a
  non-negative price, a page-size cap), `default` where the handler has one.
- `required` lists the fields with no default. A fetch-by-id takes
  `required: ["<id>"]`; an all-optional filter search takes `required: []`.
- Keep it consistent with `params`: every key in `params` appears in
  `input_schema.properties` and vice versa. `params` stays as the prose hint;
  `input_schema` is its machine form.

### 3. `example_params` -- a copyable starting call

One concrete inputs object the assistant can copy verbatim and adjust. Use
REAL, valid values (a seeded id, a real neighbourhood from the enum, a
plausible EUR-cents price) -- not `"string"` or `0`. For a filter search,
show two or three filters set together so the assistant sees they AND. For a
fetch-by-id, show the id shape (integer vs uuid) it will paste from a prior row.

### 4. `example_row` -- one result element

For a QUERY: one representative element of the result list (or the single
object a detail query returns), with EVERY field the real row carries -- so the
assistant learns the field names, the currency field, and the id it will feed
to the next call, without a probe. For an ACTION: the example RETURN value
(what `run` hands back -- e.g. `{booking_id, total_cents, currency, pay_hint}`),
which documents the follow-on the assistant must act on.

### 5. `example_params` / `example_row` currency and ids

Match the origin's real conventions EXACTLY: the demos price in EUR cents and
carry a `currency: "eur"` field; ids are the real seeded ids (integer property
ids, uuid booking ids). An example that disagrees with the live rows teaches
the assistant the wrong shape.

---

## Worked example -- hoteling `search_hotels`

The reference exemplar: a paginated, multi-parameter search over ~100 hotels.
All five fields, written to house style (ASCII-rendered here; the live origin
serves the real Unicode area names):

```
Kiosk::Server::Queries.register("search_hotels",
  description: "Search Istanbul hotels with optional filters, returning a " \
               "paginated page of SUMMARY rows (one row per property, cheapest " \
               "room's nightly rate). Apply the user's stated constraints as " \
               "filters; do not fetch the whole catalogue. All filters are " \
               "optional and AND together: neighbourhood (exact area name), " \
               "max_price_cents (cheapest room <= this, EUR cents), min_stars " \
               "(star rating >= this), amenity (property must offer it). Page " \
               "size defaults to 20 (override with limit, capped at 50); when " \
               "the response carries a top-level `next`, more hotels match -- " \
               "echo it back verbatim as `cursor` to fetch the following page, " \
               "and keep paging until `next` is absent. from_price_cents is EUR " \
               "cents (carts are signed in eur). Call hotel_detail with a " \
               "returned id for the full property (rooms, amenities, address).",
  params: {
    neighbourhood:   "string, optional -- exact area, e.g. \"Kadikoy\"",
    max_price_cents: "integer, optional -- cheapest room's nightly rate <= this (EUR cents)",
    min_stars:       "integer 1..5, optional -- star rating floor",
    amenity:         "string, optional -- property must offer this amenity",
    limit:           "integer, optional -- page size (default 20, max 50)",
    cursor:          "string, optional -- opaque `next` from a prior page, echoed verbatim",
  },
  input_schema: {
    type: "object",
    additionalProperties: false,
    properties: {
      neighbourhood:   { type: "string", enum: ["Sultanahmet", "Beyoglu", "Kadikoy", "..."],
                         description: "Exact Istanbul area name." },
      max_price_cents: { type: "integer", minimum: 0, description: "Cheapest room <= this, EUR cents." },
      min_stars:       { type: "integer", minimum: 1, maximum: 5, description: "Star-rating floor." },
      amenity:         { type: "string", enum: ["wifi", "breakfast", "pool", "..."],
                         description: "Property must offer this amenity." },
      limit:           { type: "integer", minimum: 1, maximum: 50, default: 20,
                         description: "Page size." },
      cursor:          { type: "string", description: "Opaque `next` cursor from a prior page." },
    },
    required: [],
  },
  example_params: { neighbourhood: "Besiktas", min_stars: 4, max_price_cents: 20000, limit: 20 },
  example_row: {
    id: 4, name: "Bosphorus Palace", neighbourhood: "Besiktas", stars: 5,
    from_price_cents: 15000, currency: "eur", room_type_count: 2,
  }) do |params|
  # ... handler returns Kiosk::Server::Page.new(rows:, next_cursor:) ...
end
```

What each field is doing for the cold assistant:

- `description` names the currency (EUR cents), says summaries-not-detail,
  tells it to filter, and spells out the `next`/`cursor` paging loop -- so the
  assistant never acts on a silently truncated list.
- `input_schema` closes the object (`additionalProperties: false`), enumerates
  the neighbourhoods and amenities so the assistant picks a valid one, bounds
  `min_stars` to 1..5 and `limit` to 50, and marks everything optional
  (`required: []`) -- a bare `search_hotels` is a valid whole-catalogue page 1.
- `example_params` shows three filters set together (they AND) with real values.
- `example_row` shows the `id` the assistant will pass to `hotel_detail`, the
  `currency` field, and the summary shape -- learned without a probe.

The paired detail query, `hotel_detail`, is the other half of the pattern:
`required: ["property_id"]`, an `example_params` of `{ property_id: 4 }`, and an
`example_row` that is the full object (address, amenities, every room type). The
prose says "search returns summaries, fetch detail on demand" so the assistant
does not fetch detail for the whole result set.

---

## Checklist

Before shipping a primary read query or primary action, confirm:

- [ ] `description` states the currency, id format, and any date/units, in prose.
- [ ] A LIST query's `description` says it paginates and how to page.
- [ ] A SEARCH query's `description` tells the assistant to filter, not fetch-all.
- [ ] A WRITE action's `description` names the follow-on (pay/confirm shape).
- [ ] `input_schema` is `type: "object"`, `additionalProperties: false`.
- [ ] Every param has a `type`; closed sets use `enum`, ranges use min/max.
- [ ] `required` is accurate (empty for all-optional search; the id for fetch-by-id).
- [ ] `params` keys and `input_schema.properties` keys match exactly.
- [ ] `example_params` uses real, valid values (a seeded id, an enum member).
- [ ] `example_row` carries every field the real row has, including `currency`.
- [ ] A cold assistant reaching this verb from `schema` alone would call it right.
