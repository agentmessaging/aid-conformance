#!/bin/bash
# 03-token-issuance/01 — Token endpoint rejects request with no grant_type
# Validates: /oauth/token returns 400 invalid_request when grant_type missing.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
require_base_config

# Discover token endpoint
PRM_URL="${AID_CONF_RESOURCE_URL%/}/.well-known/oauth-protected-resource"
prm_result=$(http_get "$PRM_URL" "Accept: application/json")
AS_URL=$(http_body "$prm_result" | jq -r '.authorization_servers[0]')
ASM_URL="${AS_URL%/}/.well-known/oauth-authorization-server"
asm_result=$(http_get "$ASM_URL" "Accept: application/json")
TOKEN_URL=$(http_body "$asm_result" | jq -r '.token_endpoint')
assert_not_empty "$TOKEN_URL" "token_endpoint"

note "POST ${TOKEN_URL} (no grant_type)"

result=$(http_post_form "$TOKEN_URL" "")
status=$(http_status "$result")
body=$(http_body "$result")

# OAuth 2.0 says 400 with error=invalid_request
assert_status 400 "$status"

# error field expected (some impls return {error:"invalid_request"})
if [ -n "$body" ] && echo "$body" | jq -e . >/dev/null 2>&1; then
    error_code=$(echo "$body" | jq -r '.error // empty')
    if [ -n "$error_code" ]; then
        assert_equal "invalid_request" "$error_code" "error code"
    fi
fi

pass "Token endpoint rejects missing grant_type with 400"
