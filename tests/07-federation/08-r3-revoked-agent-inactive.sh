#!/bin/bash
# 07-federation/08 — R3: a revoked or suspended agent's token is inactive
# Validates: Freshness: introspection returns active:false (200) once the agent is no longer allowed.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
if [ -z "${AID_CONF_REVOKED_TOKEN:-}" ]; then
    skip "AID_CONF_REVOKED_TOKEN not set (a token of a suspended or revoked agent)"
fi
require_introspect_credentials
fed_introspection_endpoint

fed_introspect "$AID_CONF_REVOKED_TOKEN" auth
assert_status 200 "$FED_STATUS"
# not assert_json_field: its jq "// empty" fallback turns a literal false into an empty string
assert_equal "false" "$(echo "$FED_BODY" | jq -r '.active')" "active"

pass "revoked agent's token introspects as active=false"
