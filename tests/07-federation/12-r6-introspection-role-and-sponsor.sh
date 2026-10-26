#!/bin/bash
# 07-federation/12 — R6: introspection returns agent_role and the sponsor
# Validates: Lets a relying party map and audit without a second call.

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
assert_json_present "$FED_BODY" ".agent_role"

# The profile names the sponsor ("the person who registered the agent") but not the field.
fields="${AID_CONF_SPONSOR_FIELD:-sponsor sponsor_email registered_by}"
found=""
for f in $fields; do
    value=$(echo "$FED_BODY" | jq -r --arg f "$f" '.[$f] // empty | if type == "object" then tojson else tostring end')
    if [ -n "$value" ]; then found="$f"; break; fi
done
if [ -z "$found" ]; then
    fail "no sponsor in the introspection answer (looked for: ${fields}; set AID_CONF_SPONSOR_FIELD if the issuer uses another name)"
fi

pass "agent_role and ${found} present in the introspection answer"
