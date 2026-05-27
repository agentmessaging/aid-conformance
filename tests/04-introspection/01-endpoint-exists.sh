#!/bin/bash
# 04-introspection/01 — Introspection endpoint is discoverable and reachable
# Validates: ASM advertises introspection_endpoint; the URL responds.

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

INTRO_URL=$(http_body "$asm_result" | jq -r '.introspection_endpoint // empty')
assert_not_empty "$INTRO_URL" "introspection_endpoint"

note "POST ${INTRO_URL} (no token — expect 400 or 401)"

result=$(http_post_form "$INTRO_URL" "")
status=$(http_status "$result")

# RFC 7662: missing token = 400. Some impls require auth = 401.
case "$status" in
    400|401) pass "Introspection endpoint reachable, returns ${status} for empty body" ;;
    200)
        # RFC 7662 says 200 with active=false is also valid for invalid token
        body=$(http_body "$result")
        active=$(echo "$body" | jq -r '.active // empty')
        if [ "$active" = "false" ]; then
            pass "Introspection endpoint reachable, returns 200 with active=false"
        else
            fail "200 returned but active is '${active}', expected false"
        fi
        ;;
    *) fail "expected 400, 401, or 200/active=false; got ${status}" ;;
esac
