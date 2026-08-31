#!/usr/bin/env bash
# Validate the Kiosk protocol JSON Schemas and their example payloads.
# Draft 2020-12, via ajv-cli. Requires Node; uses a global `ajv` if present,
# otherwise `npx ajv-cli`. This is the merge gate for kiosk.tech/spec/schemas.
set -uo pipefail
set +C   # some shells default to noclobber; we truncate temp files
cd "$(dirname "$0")"

if command -v ajv >/dev/null 2>&1; then AJV=(ajv); else AJV=(npx --yes ajv-cli@5.0.0); fi
F=(--spec draft2020 --strict=false)
TMP="$(mktemp -d)"
pass=0; fail=0

chk() {
  if "${AJV[@]}" "$@" >/dev/null 2>|"$TMP/err"; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); echo "FAIL: ${@: -1}"; sed 's/^/   /' "$TMP/err"
  fi
}
# A schema is only as good as what it REFUSES, so some examples are checked for
# rejection. `chk` above passes when ajv exits 0; this one passes when it does
# not. Anything that made the schema vacuous -- a dropped `enum`, an `items`
# that stopped constraining -- turns a rejected example green here.
chkfail() {
  if "${AJV[@]}" "$@" >/dev/null 2>|"$TMP/err"; then
    fail=$((fail+1)); echo "FAIL (expected rejection, got acceptance): ${@: -1}"
  else
    pass=$((pass+1))
  fi
}
# thin wrapper schema so an example can be checked against a specific $def
ref() { printf '{"$ref":"%s"}\n' "$2" >|"$TMP/$1.json"; echo "$TMP/$1.json"; }
B="https://kiosk.tech/spec/schemas"

echo "== compile schemas =="
chk compile "${F[@]}" -s discovery.schema.json
chk compile "${F[@]}" -s pow.schema.json
chk compile "${F[@]}" -s problem.schema.json -r pow.schema.json
chk compile "${F[@]}" -s schema-descriptor.schema.json
chk compile "${F[@]}" -s mandates.schema.json
chk compile "${F[@]}" -s kyc.schema.json
chk compile "${F[@]}" -s auth.schema.json
# binding's `claimResponse` is a cross-file `$ref` into auth.schema.json, so the
# compile needs `-r` exactly as problem.schema.json's does into pow. That `$ref`
# is deliberate -- Section 6.2's claim answer IS Section 5.3's register answer,
# and restating it is how two copies of one shape drift apart.
chk compile "${F[@]}" -s binding.schema.json -r auth.schema.json

echo "== validate examples =="
chk validate "${F[@]}" -s discovery.schema.json -d examples/discovery.json
chk validate "${F[@]}" -s problem.schema.json -r pow.schema.json -d examples/problem.not-found.json
chk validate "${F[@]}" -s problem.schema.json -r pow.schema.json -d examples/problem.pow.json
chk validate "${F[@]}" -s problem.schema.json -r pow.schema.json -d examples/problem.method-not-allowed.json
chk validate "${F[@]}" -s schema-descriptor.schema.json -d examples/schema-descriptor.json
chk validate "${F[@]}" -s pow.schema.json -d examples/pow.proofs.json
chk validate "${F[@]}" -s pow.schema.json -d examples/pow.shorthand.json
# K-845: the LARGEST LEGAL index, 2**64-1, must VALIDATE. This example exists
# because it did not: with the bound written `exclusiveMaximum: 2**64` this file
# was REJECTED by ajv (and by any double-precision reader), which rounds
# 18446744073709551615 up to exactly 2**64 and then compares it against an
# exclusive bound of 2**64. An inclusive `maximum: 2**64-1` is the same set for
# an exact-integer reader and survives the round-trip for a double one. Flip the
# bound back and this line goes red.
chk validate "${F[@]}" -s pow.schema.json -d examples/pow.max-index.json
chk validate "${F[@]}" -s pow.schema.json -d examples/pow.max-header-nonce.json
chk validate "${F[@]}" -s "$(ref intent  "$B/mandates.schema.json#/\$defs/intent")"     -r mandates.schema.json -d examples/mandate.intent.json
chk validate "${F[@]}" -s "$(ref cart    "$B/mandates.schema.json#/\$defs/cart")"       -r mandates.schema.json -d examples/mandate.cart.json
chk validate "${F[@]}" -s "$(ref payment "$B/mandates.schema.json#/\$defs/payment")"    -r mandates.schema.json -d examples/mandate.payment.json
chk validate "${F[@]}" -s "$(ref payreq  "$B/mandates.schema.json#/\$defs/payRequest")" -r mandates.schema.json -d examples/pay-request.json
chk validate "${F[@]}" -s "$(ref settle  "$B/mandates.schema.json#/\$defs/settlement")" -r mandates.schema.json -d examples/settlement.json
chk validate "${F[@]}" -s "$(ref att     "$B/kyc.schema.json#/\$defs/attestation")"     -r kyc.schema.json -d examples/kyc.attestation.json
chk validate "${F[@]}" -s "$(ref kycreq  "$B/kyc.schema.json#/\$defs/request")"         -r kyc.schema.json -d examples/kyc.request.json
# T-149: Sections 5 and 6. One example per `$def`, because the claim these
# schemas exist to make honest is per-OBJECT, not per-file: a file that compiles
# while one of its six objects is a typo'd `$def` nobody validates against is the
# same fiction as no file at all.
chk validate "${F[@]}" -s "$(ref achal   "$B/auth.schema.json#/\$defs/challenge")"         -r auth.schema.json -d examples/auth.challenge.json
chk validate "${F[@]}" -s "$(ref aproof  "$B/auth.schema.json#/\$defs/possessionProof")"   -r auth.schema.json -d examples/auth.possession-proof.json
chk validate "${F[@]}" -s "$(ref acred   "$B/auth.schema.json#/\$defs/credentialRequest")" -r auth.schema.json -d examples/auth.credential-request.json
chk validate "${F[@]}" -s "$(ref areg    "$B/auth.schema.json#/\$defs/registration")"      -r auth.schema.json -d examples/auth.registration.json
chk validate "${F[@]}" -s "$(ref atok    "$B/auth.schema.json#/\$defs/token")"             -r auth.schema.json -d examples/auth.token.json
chk validate "${F[@]}" -s "$(ref aclaims "$B/auth.schema.json#/\$defs/accessTokenClaims")" -r auth.schema.json -d examples/auth.access-token-claims.json
chk validate "${F[@]}" -s "$(ref bda     "$B/binding.schema.json#/\$defs/deviceAuthorization")" -r binding.schema.json -r auth.schema.json -d examples/binding.device-authorization.json
chk validate "${F[@]}" -s "$(ref bdtok   "$B/binding.schema.json#/\$defs/deviceTokenResponse")" -r binding.schema.json -r auth.schema.json -d examples/binding.device-token.json
chk validate "${F[@]}" -s "$(ref blink   "$B/binding.schema.json#/\$defs/linkCode")"            -r binding.schema.json -r auth.schema.json -d examples/binding.link-code.json
chk validate "${F[@]}" -s "$(ref bclreq  "$B/binding.schema.json#/\$defs/claimRequest")"        -r binding.schema.json -r auth.schema.json -d examples/binding.claim-request.json
# The one that exercises the cross-file `$ref`: this document is checked against
# `binding`'s claimResponse, which is nothing but a pointer into `auth`. If the
# pointer stopped resolving, ajv would fail here rather than shrug.
chk validate "${F[@]}" -s "$(ref bclres  "$B/binding.schema.json#/\$defs/claimResponse")"       -r binding.schema.json -r auth.schema.json -d examples/binding.claim-response.json
chk validate "${F[@]}" -s "$(ref bunlink "$B/binding.schema.json#/\$defs/unlinkRequest")"       -r binding.schema.json -r auth.schema.json -d examples/binding.unlink-request.json
# K-1248: the /oauth/* error body, which had no schema while Section 6.1's closing
# list named six codes and its own step 1 required a seventh.
chk validate "${F[@]}" -s "$(ref boaerr  "$B/binding.schema.json#/\$defs/oauthError")"          -r binding.schema.json -r auth.schema.json -d examples/binding.oauth-error.json

echo "== reject what the schemas must refuse =="
# T-068 slice 5 / T-075 = A: `capabilities` names MODULES (schema, queries,
# actions, pay). This document is its accepted sibling with that ONE array
# reverted to protocol 0.3's verb names, so the only thing that can make it
# pass is the enum going soft.
chkfail validate "${F[@]}" -s discovery.schema.json -d examples/rejected/discovery.verb-names.json
# T-095: `verbs` is GONE from the catalog. It rendered the same value
# `/.well-known/kiosk.json` publishes as `capabilities` -- one value under two
# names, not two facts -- so the field was dropped rather than reconciled.
#
# THIS EXAMPLE IS WHY THE SCHEMA'S ROOT IS CLOSED. It is byte-for-byte the
# accepted sibling with `verbs` added back, carrying exactly the value the
# field used to hold (the CURRENT module names, not 0.3's -- so a stale enum
# cannot be what fails it). With an open root the document would simply
# validate and this line would print PASS while checking nothing; it fails only
# because `additionalProperties: false` refuses a key the schema does not
# declare. Deleting either the closed root or this example silently removes a
# property from the suite. Its predecessor, `schema-descriptor.verb-names.json`,
# tested the `verbs` ENUM and had nothing left to test once the field went.
chkfail validate "${F[@]}" -s schema-descriptor.schema.json -d examples/rejected/schema-descriptor.verbs-field.json
# K-949 / ADR-0028: `reach` is a CLOSED vocabulary, and the closure is the
# whole enforcement. `reach` is what lets a verb answer with another
# principal's rows and still conform, so an unrecognised value must be a
# refusal rather than a shrug: "public" is the word an operator reaches for
# first, it is not one of the four, and a schema that accepted it would let a
# typo publish a claim no assistant and no sweep can read. This example is the
# accepted sibling's first query with that one word substituted, so nothing but
# the enum can be what fails it.
chkfail validate "${F[@]}" -s schema-descriptor.schema.json -d examples/rejected/schema-descriptor.bad-reach.json
# K-1275: `params` is WITHDRAWN, and until this line the withdrawal was prose
# only. T-085 deleted the property declaration, and deleting a declaration from
# an OPEN object does not forbid the key -- it unconstrains it. Measured then and
# re-measured when this fixture landed: `"params": null` validated at exit 0 with
# the property gone, and the wave LOOSENED the document by one step, because while
# the property was declared `["object","null"]` a `"params": 42` was refused and
# afterwards it was not. The remedy is deliberately the narrowest one that closes
# it -- `{"not": {}}`, the object spelling of the `false` schema, on that one key
# -- rather than `additionalProperties: false` on the whole descriptor, which
# would also refuse operator-defined members no prose surface has ever forbidden
# (unsettled; K-1278). This example is the accepted sibling's first query with the
# withdrawn key added back at the only value a 0.3 origin ever published, so
# nothing but that key can be what fails it.
chkfail validate "${F[@]}" -s schema-descriptor.schema.json -d examples/rejected/schema-descriptor.params-field.json
# K-839: `indices` items are u64. The description said so from the start; only
# the bound makes the schema REFUSE what a conforming verifier refuses.
# `pack("Q<")` truncates mod 2**64, so without the upper bound `idx` and
# `idx + 2**64` were two spellings of one leaf and the schema admitted a proof
# every implementation rejects. Both examples are the accepted
# examples/pow.shorthand.json with ONE index moved out of range -- the only
# thing that can turn either green is the bound going away.
#
# K-845: the over-range example is 2**64 + 4096, NOT 2**64 itself, and the
# distance is not slack. ajv reads JSON numbers as IEEE-754 doubles, whose
# spacing at this magnitude is 4096, so 2**64-1, 2**64 and everything between
# them collapse onto ONE double -- no bound expressible in JSON Schema can
# separate a legal 2**64-1 from an illegal 2**64 for such a reader. The bound
# is therefore written to keep the LEGAL value (see examples/pow.max-index.json
# above), and this example is moved to the first magnitude a double can still
# tell apart. An exact-integer reader (the reference verifier) refuses both.
# K-741: `line_items` is REQUIRED on a cart mandate. This example is the
# accepted examples/mandate.cart.json with that one key deleted and nothing
# else changed, so the only thing that can turn it green is `line_items`
# leaving the cart's `required` array again. The field was optional while the
# settlement and reconciliation path already read it, which let a conforming
# assistant pay and leave a capture nobody can match to a domain object.
chkfail validate "${F[@]}" -s "$(ref cartnoitems "$B/mandates.schema.json#/\$defs/cart")" -r mandates.schema.json -d examples/rejected/mandate.cart.no-line-items.json
# K-857: and an EMPTY array is not a cart either -- the question K-741 left open.
# `[]` satisfies `required` while carrying exactly as much reconciliation value
# as omission did, and `total_amount_cents` has `minimum: 1`, so an empty cart
# is a positive charge with nothing itemised under it. This example is the
# accepted examples/mandate.cart.json with `line_items` emptied and nothing else
# changed, so only `minItems` leaving the schema can turn it green.
chkfail validate "${F[@]}" -s "$(ref cartempty "$B/mandates.schema.json#/\$defs/cart")" -r mandates.schema.json -d examples/rejected/mandate.cart.empty-line-items.json
# K-1250: and an EMPTY `currency` is not a currency, for the same reason an empty
# `line_items` is not a cart -- presence was the whole check on both sides, in the
# schema and in the reference verifier, and presence is not the constraint. Section 11.2
# compares the three mandates' currencies to EACH OTHER and never to a domain, so
# `""` is internally consistent from intent to payment and reaches the PSP. This
# example is the accepted examples/mandate.intent.json with that one value emptied
# and nothing else changed, so only `minLength` leaving the schema can turn it green.
chkfail validate "${F[@]}" -s "$(ref intemptycur "$B/mandates.schema.json#/\$defs/intent")" -r mandates.schema.json -d examples/rejected/mandate.intent.empty-currency.json
# T-159 / K-1252: and a currency NAME is not a currency either. Phil closed the
# domain on ISO 4217 on 2026-08-31 ("accept iso codes"), so `currency` now carries
# `pattern: ^[A-Za-z]{3}$` -- three ASCII letters, either case -- and "Euro", "US"
# and the numeric-3 spelling "978" that ISO 4217 also publishes are all refusals.
# Until then the reference accepted "Euro", canonicalised it to "euro", signed it
# into the chain and handed it to the PSP, so the human was told a card had failed
# when nothing was wrong with the card. Three letters that name no currency still
# pass, and that is stated in Section 11.1 rather than hidden here: the pattern is
# the operator's MINIMUM refusal, and no list this repository could ship would do
# better, because the vendored PSP client documents a server-side supported set and
# enumerates nothing. This example is the accepted examples/mandate.intent.json
# with that one value replaced by the name of the same currency and nothing else
# changed, so only the `pattern` leaving the schema can turn it green.
chkfail validate "${F[@]}" -s "$(ref intcurname "$B/mandates.schema.json#/\$defs/intent")" -r mandates.schema.json -d examples/rejected/mandate.intent.currency-name.json
chkfail validate "${F[@]}" -s pow.schema.json -d examples/rejected/pow.index-above-u64.json
chkfail validate "${F[@]}" -s pow.schema.json -d examples/rejected/pow.index-negative.json
# K-842: `header_nonce` is a u32 and was an unbounded integer, so the schema
# admitted values the reference verifier folds down to a DIFFERENT number --
# `pack("V")` truncates mod 2**32, which made 0, 2**32 and -(2**32) three
# spellings of one proof. Unlike the u64 case above there is no double-rounding
# problem at this magnitude (2**32-1 is exactly representable), so the accepted
# example carries the largest LEGAL value and the two rejected ones sit exactly
# one step outside it in each direction. The only thing that can turn either
# green is the bound going away.
chkfail validate "${F[@]}" -s pow.schema.json -d examples/rejected/pow.header-nonce-above-u32.json
chkfail validate "${F[@]}" -s pow.schema.json -d examples/rejected/pow.header-nonce-negative.json
# T-149. Six negatives, and each one is its accepted sibling with EXACTLY one
# key changed -- generated from it rather than typed, so nothing but the
# constraint named can be what fails them.
#
# `role` and `scope` are the same rule twice, and it is a real one rather than a
# tidiness: Section 5.4 says the role claim is OMITTED, not null, when absent,
# and Section 6.1 says the same of `scope`. An assistant that branches on
# `"role" in claims` and an assistant that branches on truthiness disagree about
# `null`, so a schema that admitted it would let two conforming readers of one
# token reach two different answers about what the principal may do. `type:
# string` is what refuses it; drop the type and these two lines go green.
chkfail validate "${F[@]}" -s "$(ref rolenull "$B/auth.schema.json#/\$defs/accessTokenClaims")" -r auth.schema.json -d examples/rejected/auth.access-token-claims.role-null.json
chkfail validate "${F[@]}" -s "$(ref scopenull "$B/binding.schema.json#/\$defs/deviceTokenResponse")" -r binding.schema.json -r auth.schema.json -d examples/rejected/binding.device-token.scope-null.json
# The two `const`s. `actor` is what says a token is an AGENT's, and `token_type`
# is what an OAuth client dispatches its Authorization header on; a soft enum in
# either place is a schema that has stopped saying the one thing it was for.
chkfail validate "${F[@]}" -s "$(ref actoruser "$B/auth.schema.json#/\$defs/accessTokenClaims")" -r auth.schema.json -d examples/rejected/auth.access-token-claims.actor-user.json
chkfail validate "${F[@]}" -s "$(ref ttmac "$B/binding.schema.json#/\$defs/deviceTokenResponse")" -r binding.schema.json -r auth.schema.json -d examples/rejected/binding.device-token.token-type-mac.json
# `aud` is the origin binding of Section 15.1 -- the single claim that makes a
# relayed possession proof worthless. A proof without it is the phishing case,
# not a lenient one.
chkfail validate "${F[@]}" -s "$(ref noaud "$B/auth.schema.json#/\$defs/possessionProof")" -r auth.schema.json -d examples/rejected/auth.possession-proof.no-aud.json
# `interval` is the member where the Kiosk contract is NARROWER than RFC 8628,
# which makes it optional -- Section 6.1 enumerates all six as returned. That is
# exactly the constraint a later editor is most likely to loosen back toward the
# RFC without noticing it is this document's own promise, so it gets the fixture.
chkfail validate "${F[@]}" -s "$(ref nointerval "$B/binding.schema.json#/\$defs/deviceAuthorization")" -r binding.schema.json -r auth.schema.json -d examples/rejected/binding.device-authorization.no-interval.json
# K-1248: the /oauth/* code vocabulary is CLOSED at eight, and the closure is the
# whole point of publishing it -- an assistant polling this ceremony branches on
# `error`, so a code outside the list is a branch it cannot take. This example is
# the accepted sibling with that one member set to `invalid_scope`: a REAL RFC 6749
# code that is deliberately not on this wire, so nothing but the enum can fail it,
# and it is exactly the value a later editor widening toward "all of RFC 6749"
# would let back in.
chkfail validate "${F[@]}" -s "$(ref oaerrbad "$B/binding.schema.json#/\$defs/oauthError")" -r binding.schema.json -r auth.schema.json -d examples/rejected/binding.oauth-error.unknown-code.json

echo "-----"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
