#!/bin/bash
# 01-discovery/04 — aid_grant metadata block has required fields
# Validates: the block carries aid_version, registration endpoints, key_algorithms.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
require_base_config

PRM_URL="${AID_CONF_RESOURCE_URL%/}/.well-known/oauth-protected-resource"
prm_result=$(http_get "$PRM_URL" "Accept: application/json")
prm_body=$(http_body "$prm_result")
AS_URL=$(echo "$prm_body" | jq -r '.authorization_servers[0]')

ASM_URL="${AS_URL%/}/.well-known/oauth-authorization-server"
asm_result=$(http_get "$ASM_URL" "Accept: application/json")
asm_body=$(http_body "$asm_result")

# aid_grant block must exist
assert_json_present "$asm_body" ".aid_grant"

# Required fields
assert_json_present "$asm_body" ".aid_grant.aid_version"
assert_json_present "$asm_body" ".aid_grant.registration_endpoint"
assert_json_present "$asm_body" ".aid_grant.registration_request_endpoint"

# key_algorithms_supported MUST include Ed25519 in v1.0/1.1
assert_json_array_contains "$asm_body" ".aid_grant.key_algorithms_supported" "Ed25519"

# credential_types_supported MUST include access_token; api_key is optional
assert_json_array_contains "$asm_body" ".aid_grant.credential_types_supported" "access_token"

pass "aid_grant block has required fields"
