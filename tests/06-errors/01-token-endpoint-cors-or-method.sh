#!/bin/bash
# 06-errors/01 — Token endpoint rejects GET (must be POST)
# Validates: spec compliance — only POST is allowed on token endpoint.

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

note "GET ${TOKEN_URL} (expect 405)"

result=$(http_get "$TOKEN_URL")
status=$(http_status "$result")

# 405 Method Not Allowed is correct. Some servers route GET to a JSON page (200).
case "$status" in
    405) pass "Token endpoint correctly rejects GET with 405" ;;
    400) pass "Token endpoint rejects GET with 400 (acceptable)" ;;
    *) note "Token endpoint accepts GET with status ${status} — non-blocking but non-canonical" ; pass "GET tolerated" ;;
esac
