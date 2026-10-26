#!/bin/bash
# 07-federation/01 — R1: a token requested with resource=X has aud exactly X
# Validates: RFC 8707 per-service audience (federation profile section 7, R1).

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
require_token_cmd
require_resource_audience

note "requesting a token with resource=${AID_CONF_RESOURCE_AUDIENCE}"
if ! fed_token "$AID_CONF_RESOURCE_AUDIENCE"; then
    skip "token command did not return a token (${FED_TOKEN_OUT:0:120}); cannot check aud"
fi

claims=$(jwt_part "$FED_TOKEN" 2)
echo "$claims" | jq -e . >/dev/null 2>&1 || fail "token payload is not JSON"

aud=$(echo "$claims" | jq -c '[.aud] | flatten | sort')
expected=$(jq -cn --arg a "$AID_CONF_RESOURCE_AUDIENCE" '[$a]')
assert_equal "$expected" "$aud" "aud"

pass "aud is exactly ${AID_CONF_RESOURCE_AUDIENCE}"
