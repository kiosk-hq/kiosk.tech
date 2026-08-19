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
# not. Anything that made the schema vacuous — a dropped `enum`, an `items`
# that stopped constraining — turns a rejected example green here.
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

echo "== validate examples =="
chk validate "${F[@]}" -s discovery.schema.json -d examples/discovery.json
chk validate "${F[@]}" -s problem.schema.json -r pow.schema.json -d examples/problem.not-found.json
chk validate "${F[@]}" -s problem.schema.json -r pow.schema.json -d examples/problem.pow.json
chk validate "${F[@]}" -s problem.schema.json -r pow.schema.json -d examples/problem.method-not-allowed.json
chk validate "${F[@]}" -s schema-descriptor.schema.json -d examples/schema-descriptor.json
chk validate "${F[@]}" -s pow.schema.json -d examples/pow.proofs.json
chk validate "${F[@]}" -s pow.schema.json -d examples/pow.shorthand.json
chk validate "${F[@]}" -s "$(ref intent  "$B/mandates.schema.json#/\$defs/intent")"     -r mandates.schema.json -d examples/mandate.intent.json
chk validate "${F[@]}" -s "$(ref cart    "$B/mandates.schema.json#/\$defs/cart")"       -r mandates.schema.json -d examples/mandate.cart.json
chk validate "${F[@]}" -s "$(ref payment "$B/mandates.schema.json#/\$defs/payment")"    -r mandates.schema.json -d examples/mandate.payment.json
chk validate "${F[@]}" -s "$(ref payreq  "$B/mandates.schema.json#/\$defs/payRequest")" -r mandates.schema.json -d examples/pay-request.json
chk validate "${F[@]}" -s "$(ref settle  "$B/mandates.schema.json#/\$defs/settlement")" -r mandates.schema.json -d examples/settlement.json
chk validate "${F[@]}" -s "$(ref att     "$B/kyc.schema.json#/\$defs/attestation")"     -r kyc.schema.json -d examples/kyc.attestation.json
chk validate "${F[@]}" -s "$(ref kycreq  "$B/kyc.schema.json#/\$defs/request")"         -r kyc.schema.json -d examples/kyc.request.json

echo "== reject what the schemas must refuse =="
# T-068 slice 5 / T-075 = A: `capabilities` names MODULES (schema, queries,
# actions, pay). This document is its accepted sibling with that ONE array
# reverted to protocol 0.3's verb names, so the only thing that can make it
# pass is the enum going soft.
chkfail validate "${F[@]}" -s discovery.schema.json -d examples/rejected/discovery.verb-names.json
# T-095: `verbs` is GONE from the catalog. It rendered the same value
# `/.well-known/kiosk.json` publishes as `capabilities` — one value under two
# names, not two facts — so the field was dropped rather than reconciled.
#
# THIS EXAMPLE IS WHY THE SCHEMA'S ROOT IS CLOSED. It is byte-for-byte the
# accepted sibling with `verbs` added back, carrying exactly the value the
# field used to hold (the CURRENT module names, not 0.3's — so a stale enum
# cannot be what fails it). With an open root the document would simply
# validate and this line would print PASS while checking nothing; it fails only
# because `additionalProperties: false` refuses a key the schema does not
# declare. Deleting either the closed root or this example silently removes a
# property from the suite. Its predecessor, `schema-descriptor.verb-names.json`,
# tested the `verbs` ENUM and had nothing left to test once the field went.
chkfail validate "${F[@]}" -s schema-descriptor.schema.json -d examples/rejected/schema-descriptor.verbs-field.json

echo "-----"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
