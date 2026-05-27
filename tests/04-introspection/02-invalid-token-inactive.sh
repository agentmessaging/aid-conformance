#!/bin/bash
# 04-introspection/02 — Garbage token returns active=false (RFC 7662)
# Validates: a syntactically-formed-but-invalid token introspects as inactive.

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
INTRO_URL=$(http_body "$asm_result" | jq -r '.introspection_endpoint')

# A token that's syntactically a JWT but signed by no one we know about
GARBAGE="eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJub3QtcmVhbCJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

note "POST ${INTRO_URL} with garbage token"

result=$(http_post_form "$INTRO_URL" "token=${GARBAGE}")
status=$(http_status "$result")
body=$(http_body "$result")

# RFC 7662: invalid token = 200 with active=false (NOT 401)
assert_status 200 "$status"
assert_json_field "$body" ".active" "false"

pass "Invalid token returns active=false per RFC 7662"
