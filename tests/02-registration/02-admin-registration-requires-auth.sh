#!/bin/bash
# 02-registration/02 — Admin-initiated registration without admin JWT is rejected
# Validates: POST /agent_registrations without Authorization returns 401.

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
REG_ENDPOINT=$(http_body "$asm_result" | jq -r '.aid_grant.registration_endpoint')
assert_not_empty "$REG_ENDPOINT" "registration_endpoint"

BODY='{"agent_registration":{"name":"unauth-attempt","address":"x@conformance.local","fingerprint":"SHA256:abc","public_key":"-----BEGIN PUBLIC KEY-----\nplaceholder\n-----END PUBLIC KEY-----\n","key_algorithm":"Ed25519"}}'

note "POST ${REG_ENDPOINT} (no Authorization header)"

result=$(http_post_json "$REG_ENDPOINT" "$BODY")
status=$(http_status "$result")

# Must reject. 401 is the canonical answer; 403 is acceptable for some impls.
case "$status" in
    401|403) pass "Unauthenticated admin registration correctly rejected (${status})" ;;
    *) fail "expected 401 or 403 for missing admin JWT, got ${status}" ;;
esac
