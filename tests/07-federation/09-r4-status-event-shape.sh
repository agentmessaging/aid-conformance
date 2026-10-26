#!/bin/bash
# 07-federation/09 — R4: a status event has the profile's signed shape
# Validates: Security Event Token: RS256, kid in the JWKS, iss/aud/iat/jti, events with urn:aid:event:* and a subject.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
if [ -z "${AID_CONF_SAMPLE_EVENT:-}" ]; then
    skip "AID_CONF_SAMPLE_EVENT not set (a signed status event from the issuer)"
fi
EVENT=$(echo "$AID_CONF_SAMPLE_EVENT" | tr -d '[:space:]')
case "$EVENT" in *.*.*) : ;; *) fail "sample event is not a three-part JWT" ;; esac

header=$(jwt_part "$EVENT" 1)
claims=$(jwt_part "$EVENT" 2)
echo "$header" | jq -e . >/dev/null 2>&1 || fail "event header is not JSON"
echo "$claims" | jq -e . >/dev/null 2>&1 || fail "event payload is not JSON"

assert_json_field "$header" ".alg" "RS256"
assert_json_present "$header" ".kid"
assert_json_field "$claims" ".iss" "${AID_CONF_AUTH_URL%/}"
assert_json_present "$claims" ".aud"
assert_json_present "$claims" ".iat"
assert_json_present "$claims" ".jti"

[ "$(echo "$claims" | jq -r '.events | type')" = "object" ] || fail "events is not an object"
bad=$(echo "$claims" | jq -r '.events | keys[] | select(startswith("urn:aid:event:") | not)')
[ -z "$bad" ] || fail "event type outside urn:aid:event: namespace: ${bad}"
[ "$(echo "$claims" | jq '.events | length')" -ge 1 ] || fail "events is empty"
type=$(echo "$claims" | jq -r '.events | keys[0]')
if [ "$type" = "urn:aid:event:token-revoked" ]; then
    assert_json_present "$claims" ".events[\"${type}\"].subject.jti"
else
    assert_json_present "$claims" ".events[\"${type}\"].subject.agent_id"
    assert_json_present "$claims" ".events[\"${type}\"].subject.agent_address"
fi

# Signature against the issuer's own JWKS.
fed_load_jwks
kid=$(echo "$header" | jq -r '.kid')
n=$(echo "$FED_JWKS" | jq -r --arg k "$kid" '.keys[] | select(.kid == $k) | .n' | head -n 1)
e=$(echo "$FED_JWKS" | jq -r --arg k "$kid" '.keys[] | select(.kid == $k) | .e' | head -n 1)
assert_not_empty "$n" "JWKS key for kid ${kid}"
pem=$(mktemp)
trap 'rm -f "$pem"' EXIT
jwk_to_pem "$n" "$e" > "$pem" || skip "could not build a public key from the JWKS with this openssl"
jwt_verify_rs256 "$EVENT" "$pem" || fail "event signature does not verify against the issuer's JWKS (kid ${kid})"

pass "status event (${type}) has the profile shape and a valid signature"
