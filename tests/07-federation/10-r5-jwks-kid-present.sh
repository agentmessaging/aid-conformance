#!/bin/bash
# 07-federation/10 — R5: every published signing key has a kid
# Validates: Relying parties select keys by kid; a key without one cannot survive rotation.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
fed_load_jwks

count=$(echo "$FED_JWKS" | jq '.keys | length')
[ "$count" -ge 1 ] || fail "JWKS has no keys"

missing=$(echo "$FED_JWKS" | jq '[.keys[] | select((.kid // "") == "")] | length')
assert_equal "0" "$missing" "keys without kid"

dupes=$(echo "$FED_JWKS" | jq '[.keys[].kid] | length - (unique | length)')
assert_equal "0" "$dupes" "duplicate kids"

# If we can get a token, its header kid must be one of the published keys.
if [ -n "${AID_CONF_AGENT_TOKEN_CMD:-}" ] && fed_token ""; then
    tkid=$(jwt_part "$FED_TOKEN" 1 | jq -r '.kid // empty')
    assert_not_empty "$tkid" "token header kid"
    echo "$FED_JWKS" | jq -e --arg k "$tkid" '.keys | map(.kid) | index($k)' >/dev/null || fail "token kid ${tkid} is not in the JWKS"
fi

pass "${count} key(s) published, all with a unique kid"
