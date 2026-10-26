#!/bin/bash
# 07-federation/11 — R5: more than one key is published during a rotation overlap
# Validates: Observable only mid-rotation; a single key SKIPs because it proves nothing about the overlap.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
fed_load_jwks

count=$(echo "$FED_JWKS" | jq '.keys | length')
if [ "$count" -lt 2 ]; then
    skip "JWKS has ${count} key; a rotation overlap is only observable while the old and new key are both published"
fi

distinct=$(echo "$FED_JWKS" | jq '[.keys[].kid] | unique | length')
assert_equal "$count" "$distinct" "distinct kids among ${count} keys"

pass "${count} keys published with distinct kids (rotation overlap)"
