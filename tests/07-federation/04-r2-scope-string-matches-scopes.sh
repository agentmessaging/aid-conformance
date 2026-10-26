#!/bin/bash
# 07-federation/04 — R2: scope string claim equals the scopes list
# Validates: RFC 9068 scope claim, space-delimited, next to the scopes array (R2).

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
require_token_cmd

audience="${AID_CONF_RESOURCE_AUDIENCE:-}"
if ! fed_token "$audience"; then
    skip "token command did not return a token (${FED_TOKEN_OUT:0:120})"
fi

claims=$(jwt_part "$FED_TOKEN" 2)
echo "$claims" | jq -e . >/dev/null 2>&1 || fail "token payload is not JSON"

type=$(echo "$claims" | jq -r '.scope | type')
assert_equal "string" "$type" "scope claim type"
scope=$(echo "$claims" | jq -r '.scope')
assert_not_empty "$scope" "scope"

# Space-delimited: no leading, trailing or doubled spaces.
case "$scope" in
    " "*|*" "|*"  "*) fail "scope is not single-space delimited: '${scope}'" ;;
esac

if [ "$(echo "$claims" | jq -r '.scopes | type')" = "array" ]; then
    from_string=$(echo "$claims" | jq -c '.scope | split(" ") | sort')
    from_array=$(echo "$claims" | jq -c '.scopes | sort')
    assert_equal "$from_array" "$from_string" "scope vs scopes"
else
    note "token has no scopes array to compare with"
fi

pass "scope claim present and equal to scopes"
