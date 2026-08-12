# Kiosk Descriptor House Style

**Companion to** the formal specification's Section 8.3 (the `schema` verb) --
<https://kiosk.tech/spec/protocol.md>. Non-normative: this is a WRITING GUIDE,
not a wire contract. A descriptor carries `description`, `input_schema`,
`output_schema`, `example_params` and `example_row` (plus, on descriptors
written before its retirement, a free-text `params` hint); this document says
how to write them WELL -- and tells you not to write the last one -- so a cold
AI assistant can drive your origin from the `schema` catalog alone, with no
hardcoded knowledge and no call-and-observe probing.

In the reference implementation these fields are the class-level macros of
`Kiosk::Query` / `Kiosk::Action`, written in a controller the operator owns and
claimed by the next `def` (the kiosk-server README, "Declaring queries and
actions", has the mechanics). This guide is about what the fields SAY, not
where they are typed: the rules are identical however a descriptor reaches the
registry.

**The one rule: prose carries MEANING, the schemas carry SHAPE.** Every name,
type, unit, format, default, bound and required/optional marker belongs to a
schema -- `input_schema` for what the verb accepts, `output_schema` for what it
returns. `description` says what the verb does, when to call it, and what the
caller gets back *in meaning* -- never the fields it arrives in.

The consumer is an LLM, and it reads a JSON Schema as fluently as it reads a
sentence. What it cannot do is notice that your sentence and your handler
disagree. A field name written in prose is checked by nobody: it drifts from the
handler that consumes it, an assistant sends exactly what your prose told it to
send, and the call 400s. So state a fact ONCE, in the place where it can be
checked.

The acceptance test for a good descriptor is the **cold-assistant run**: a
fresh assistant, given only `GET /kiosk/schema`, reaches the user's goal on the
first well-formed call. If it has to guess a field name, a currency, an id
format, or whether a list is complete, the descriptor is under-written.

---

## The fields

Write `description` + `input_schema` + `output_schema` on **every** query and
action. Add `example_params` + `example_row` at least on the PRIMARY read query
and PRIMARY action of an origin (the ones an assistant hits first); they are
cheap enough to be worth writing everywhere.

### 1. `description` -- prose semantics (REQUIRED)

Say, in the assistant's terms, WHAT the verb does, WHEN to reach for it, and
WHAT it hands back in meaning. Useful things only prose can say:

- **What the result IS.** Summary rows or full records; a complete set or one
  page of a larger one; a quote or a commitment; per-night or per-stay. An
  assistant that thinks a page is the whole list acts on a truncated answer.
- **How to use the verb.** "Apply the human's stated constraints so the search
  narrows; do not pull the whole catalogue."
- **What happens as a side effect.** A write that reserves stock, starts a
  timer, charges someone, or emails a human is a fact no schema carries.
- **The follow-on, BY VERB NAME.** "Once the human picks one, `hotel_detail`
  returns everything this row leaves out." A verb name is not a param name --
  naming the next verb is right, naming its arguments is not. The assistant
  reads that verb's own `input_schema`.
- **Human-in-the-loop steps and preconditions** -- "the booking must already be
  paid before this action will confirm it".

And the prohibitions. A `description` MUST NOT carry:

- a field or parameter list, or any param name that `input_schema` declares;
- a type, a required/optional marker, or a range;
- a unit, a currency, a date format, or a default.

Those last ones feel like prose and are not: a unit is a property OF a field, so
it is declared ON that field (see below). The editing test: delete a sentence --
if `input_schema` still says the same thing, the sentence was duplication, and
duplication is what drifts.

### 2. `input_schema` -- the input contract (REQUIRED)

A JSON Schema object (draft 2020-12) for the verb's INPUTS. This is the ONLY
place a parameter name appears anywhere in the descriptor. Rules of house style:

- `"type": "object"` with `"additionalProperties": false` ALWAYS -- an unknown
  field is a bug, and the closed object tells the assistant it has the full set.
- List every accepted param under `properties` with its `type`, plus a one-line
  `description` per property. That per-property line is where the **unit and
  format** live -- "EUR cents", "YYYY-MM-DD", "the id from a prior row" -- and
  it is the only place they belong.
- Constrain the shape: `enum` for closed sets (neighbourhoods, statuses,
  categories, amenities), `minimum`/`maximum` for ranges (a 1..5 star rating, a
  non-negative price, a page-size cap), `default` where the handler has one,
  `pattern`/`format` where the string has a shape.
- `required` lists the fields with no default. A fetch-by-id takes
  `required: ["<thing>_id"]`; an all-optional filter search takes `required: []`.
- A verb that takes NOTHING still declares
  `{"type": "object", "additionalProperties": false, "properties": {}, "required": []}`.
  "This verb takes no arguments" is then a published fact instead of an absence
  the assistant has to interpret.

### 3. `output_schema` -- the result contract (REQUIRED)

A JSON Schema for what the verb RETURNS, so the result shape is a declaration
rather than something the assistant infers from one sample or a probe call.
For a QUERY, describe the rows it renders -- an array schema whose `items` is
the row object; for an ACTION, describe the returned object. The input rules
apply unchanged: every field with its `type`, and the per-property one-line
`description` carrying the unit or format ("EUR cents", nightly not per-stay)
on the field it belongs to.

The reference implementation publishes `output_schema` in the catalog wherever
one is declared. The formal descriptor schema does not yet name the field --
the descriptor object is open, so a descriptor carrying it validates today and
the declaration is expected to follow.

### 4. `params` -- do not write one

The free-text `params` name-to-hint hash is **retired by house style**. What a
hint used to say is either a constraint -- it belongs in `input_schema` -- or a
meaning -- it belongs in `description`; there is no third thing, and a second
place to state a name is exactly what drifts away from the handler. The
controller mixin ships no macro for it, so in the declared shape there is
nothing you could write.

The wire slot still exists for descriptors written before this rule: a
descriptor declared without a `params` hint publishes `"params": null`, which
the descriptor schema accepts -- it no longer requires the field at all, so a
descriptor that omits the key entirely is equally valid. Leave it null.

### 5. `example_params` -- a copyable starting call

One concrete inputs object the assistant can copy verbatim and adjust. Use
REAL, valid values (a seeded id, a real neighbourhood from the enum, a
plausible EUR-cents price) -- not `"string"` or `0`. For a filter search,
show two or three filters set together so the assistant sees they AND. For a
fetch-by-id, show the id shape (integer vs uuid) it will paste from a prior row.

### 6. `example_row` -- one result element

For a QUERY: one representative element of the result list (or the single
object a detail query returns), with EVERY field the real row carries -- so the
assistant learns the field names, the currency field, and the id it will feed
to the next call, at a glance. For an ACTION: the example RETURN value
(what `run` hands back -- e.g. `{booking_id, total_cents, currency, pay_hint}`),
which documents the follow-on the assistant must act on.

Examples ILLUSTRATE the contracts, they are not the contracts. If an example
and a schema disagree, the schema is right and the example is a bug.

### 7. Example currency and ids

Match the origin's real conventions EXACTLY: the demos price in EUR cents and
carry a `currency: "eur"` field; ids are the real seeded ids (integer property
ids, uuid booking ids). An example that disagrees with the live rows teaches
the assistant the wrong shape.

**A summary row's id field MUST use the SAME name as the detail/action verb's
id param** (canonical `<thing>_id`, e.g. `property_id`, `order_id`,
`reservation_id`). A `search`/list query that returns a bare `id` while its
`detail` verb takes `property_id` forces the assistant to GUESS that they are
the same key -- so a `search_hotels` row carries `property_id` (SQL
`SELECT p.id AS property_id`) and `hotel_detail` takes `property_id`; the
assistant copies the key straight through with no remapping. Never expose a row
`id` that no verb consumes (a dead field invites the same guessing).

---

## Worked example -- a hotel search

A paginated, multi-parameter search over ~100 hotels, written to the rules above
(ASCII-rendered here; the live origin serves the real Unicode area names):

```
# app/controllers/kiosk/hotel_search_controller.rb
class Kiosk::HotelSearchController < ApplicationController   # your base class, your call
  include Kiosk::Query

  description "Find Istanbul hotels matching what the human actually asked " \
              "for. Narrow with the filters this verb declares rather than " \
              "pulling the whole catalogue; filters combine, so several " \
              "constraints are one search, not several. A row is a SUMMARY " \
              "of one property -- enough to shortlist on, priced at the " \
              "cheapest room's nightly rate, not a total for the stay. The " \
              "result is a PAGE of the matching set, not the set: when more " \
              "hotels match, the response says so, and an assistant that " \
              "stops at the first page is answering from a partial list. " \
              "Once the human picks one, hotel_detail returns everything a " \
              "summary leaves out -- rooms, amenities, address."
  input_schema type: "object",
               additionalProperties: false,
               properties: {
                 neighbourhood:   { type: "string", enum: ["Sultanahmet", "Beyoglu", "Kadikoy", "..."],
                                    description: "Exact Istanbul area name." },
                 max_price_cents: { type: "integer", minimum: 0,
                                    description: "Cheapest room at or below this, EUR cents." },
                 min_stars:       { type: "integer", minimum: 1, maximum: 5,
                                    description: "Star-rating floor." },
                 amenity:         { type: "string", enum: ["wifi", "breakfast", "pool", "..."],
                                    description: "Property must offer this amenity." },
                 limit:           { type: "integer", minimum: 1, maximum: 50, default: 20,
                                    description: "Page size." },
                 cursor:          { type: "string", description: "Opaque `next` cursor from a prior page." },
               },
               required: []
  output_schema type: "array",
                items: { type: "object",
                         properties: {
                           property_id:      { type: "integer",
                                               description: "The id hotel_detail takes, same key name." },
                           name:             { type: "string" },
                           neighbourhood:    { type: "string" },
                           stars:            { type: "integer" },
                           from_price_cents: { type: "integer",
                                               description: "Cheapest room, nightly, EUR cents." },
                           currency:         { type: "string" },
                           room_type_count:  { type: "integer" },
                         } }
  example_params({ neighbourhood: "Besiktas", min_stars: 4, max_price_cents: 20000, limit: 20 })
  example_row({
    property_id: 4, name: "Bosphorus Palace", neighbourhood: "Besiktas", stars: 5,
    from_price_cents: 15000, currency: "eur", room_type_count: 2,
  })
  def search_hotels
    # ... build one page of summary rows from your models, then:
    # render_kiosk_page(rows, next_cursor: cursor)
  end
end
```

What each field is doing for the cold assistant:

- `description` tells it to filter rather than fetch everything, warns that a
  row is a summary and its price is per night, says the answer is one page of a
  larger set, and points at the verb that comes next -- and names not one
  parameter, type or unit while doing it.
- `input_schema` names every parameter exactly once, closes the object
  (`additionalProperties: false`), enumerates the neighbourhoods and amenities
  so the assistant picks a valid one, bounds `min_stars` to 1..5 and `limit` to
  50, carries the EUR-cents unit on the field it belongs to, and marks
  everything optional (`required: []`) -- a bare `search_hotels` is a valid
  whole-catalogue page 1.
- `output_schema` declares the summary row -- every field, with the
  nightly-EUR-cents unit on `from_price_cents` -- so the return shape is
  machine-read from the catalog instead of inferred from one sample.
- `example_params` shows three filters set together (they AND) with real values.
- `example_row` shows the `property_id` the assistant will pass straight to
  `hotel_detail` (SAME key name -- no remapping), the `currency` field, and the
  summary shape -- one concrete row of what `output_schema` declares.

The paired detail query, `hotel_detail`, is the other half of the pattern:
`required: ["property_id"]`, an `example_params` of `{ property_id: 4 }`, and an
`example_row` that is the full object (address, amenities, every room type). The
prose says search returns summaries and detail is fetched on demand, so the
assistant does not fetch detail for the whole result set.

Note what the paging instructions did NOT need: `next` and `cursor` are the
protocol's pagination mechanism (formal spec Section 8.4), the same on every
origin, and `cursor`/`limit` are declared in the schema like any other param.
The description only has to say that the result is a page.

---

## Checklist

Before shipping a query or an action, confirm:

- [ ] `description` says what the verb is FOR and what the result MEANS.
- [ ] `description` names no parameter, type, required/optional marker, unit,
      currency, date format, default or range.
- [ ] A LIST query's `description` says the result is a page of a larger set.
- [ ] A SEARCH query's `description` tells the assistant to filter, not fetch-all.
- [ ] A WRITE action's `description` names the follow-on verb (pay/confirm).
- [ ] `input_schema` is present, `type: "object"`, `additionalProperties: false`
      (empty `properties` for a verb that takes nothing).
- [ ] `output_schema` is present and declares the FULL result -- an array of
      the row object for a query, the return object for an action.
- [ ] Every field, in and out, has a `type`; closed sets use `enum`, ranges use
      min/max, and each property's own one-line `description` carries its
      unit/format.
- [ ] `required` is accurate (empty for all-optional search; the id for fetch-by-id).
- [ ] No `params` hint hash -- every param name appears in `input_schema` and
      nowhere else.
- [ ] A summary row's id field name == the detail/action verb's id param name (canonical `<thing>_id`); no dead row id that no verb consumes.
- [ ] `example_params` uses real, valid values (a seeded id, an enum member).
- [ ] `example_row` carries every field the real row has, including `currency`.
- [ ] The examples agree with the schemas.
- [ ] A cold assistant reaching this verb from `schema` alone would call it right.
