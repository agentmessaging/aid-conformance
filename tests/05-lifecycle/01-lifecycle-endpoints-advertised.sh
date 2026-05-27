#!/bin/bash
# 05-lifecycle/01 — Lifecycle endpoints are discoverable
# Validates: code_resolution_endpoint and agent_authorization_uri are present.

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

# These are SHOULD in the spec — present in well-implemented servers
CODE_ENDPOINT=$(http_body "$asm_result" | jq -r '.aid_grant.code_resolution_endpoint // empty')
AUTH_URI=$(http_body "$asm_result" | jq -r '.aid_grant.agent_authorization_uri // empty')

if [ -z "$CODE_ENDPOINT" ]; then
    note "code_resolution_endpoint absent — required for admin-UI approval flow"
fi
if [ -z "$AUTH_URI" ]; then
    note "agent_authorization_uri absent — required for human-friendly user_code entry"
fi

assert_not_empty "$CODE_ENDPOINT" "aid_grant.code_resolution_endpoint"
assert_not_empty "$AUTH_URI" "aid_grant.agent_authorization_uri"

pass "Lifecycle / approval endpoints discoverable"
