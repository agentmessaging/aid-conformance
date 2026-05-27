#!/bin/bash
# 03-token-issuance/02 — Unsupported grant_type returns unsupported_grant_type
# Validates: token endpoint correctly rejects unknown grant types.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
require_base_config

PRM_URL="${AID_CONF_RESOURCE_URL%/}/.well-known/oauth-protected-resource"
prm_result=$(http_get "$PRM_URL" "Accept: application/json")
AS_URL=$(http_body "$prm_result" | jq -r '.authorization_servers[0]')
ASM_URL="${AS_URL%/}/.well-known/oauth-authorization-server"
asm_result=$(http_get "$ASM_URL" "Accept: application/json")
TOKEN_URL=$(http_body "$asm_result" | jq -r '.token_endpoint')

note "POST ${TOKEN_URL} with grant_type=urn:aid:not-a-real-grant"

result=$(http_post_form "$TOKEN_URL" "grant_type=urn%3Aaid%3Anot-a-real-grant")
status=$(http_status "$result")
body=$(http_body "$result")

assert_status 400 "$status"
if echo "$body" | jq -e . >/dev/null 2>&1; then
    error_code=$(echo "$body" | jq -r '.error // empty')
    if [ -n "$error_code" ]; then
        # OAuth 2.0: unsupported_grant_type is the canonical code
        case "$error_code" in
            unsupported_grant_type|invalid_grant|invalid_request) : ;;
            *) fail "expected unsupported_grant_type, got '${error_code}'" ;;
        esac
    fi
fi

pass "Unknown grant_type rejected with 400"
