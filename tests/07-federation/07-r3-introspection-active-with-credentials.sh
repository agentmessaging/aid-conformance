#!/bin/bash
# 07-federation/07 — R3: introspection with credentials reports a live token active
# Validates: Baseline for the revoked-agent and R6 checks: the credentials work and a good token is active.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
require_token_cmd
require_introspect_credentials
fed_introspection_endpoint

audience="${AID_CONF_RESOURCE_AUDIENCE:-}"
if ! fed_token "$audience"; then
    skip "token command did not return a token (${FED_TOKEN_OUT:0:120})"
fi

fed_introspect "$FED_TOKEN" auth
assert_status 200 "$FED_STATUS"
assert_json_field "$FED_BODY" ".active" "true"

pass "authenticated introspection reports a live token active"
