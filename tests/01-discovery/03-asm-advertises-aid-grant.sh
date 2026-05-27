#!/bin/bash
# 01-discovery/03 — Authorization Server Metadata advertises urn:aid:agent-identity
# Validates: RFC 8414 — ASM exists and lists the AID grant type.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
require_base_config

# Discover the AS from PRM first
PRM_URL="${AID_CONF_RESOURCE_URL%/}/.well-known/oauth-protected-resource"
prm_result=$(http_get "$PRM_URL" "Accept: application/json")
prm_body=$(http_body "$prm_result")
AS_URL=$(echo "$prm_body" | jq -r '.authorization_servers[0] // empty')
assert_not_empty "$AS_URL" "authorization_servers[0] from PRM"

ASM_URL="${AS_URL%/}/.well-known/oauth-authorization-server"
note "GET ${ASM_URL}"

result=$(http_get "$ASM_URL" "Accept: application/json")
status=$(http_status "$result")
body=$(http_body "$result")
assert_status 200 "$status"

# grant_types_supported MUST contain urn:aid:agent-identity
assert_json_array_contains "$body" ".grant_types_supported" "urn:aid:agent-identity"

# token_endpoint must be present
assert_json_present "$body" ".token_endpoint"

pass "ASM advertises urn:aid:agent-identity"
