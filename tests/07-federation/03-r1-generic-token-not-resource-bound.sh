#!/bin/bash
# 07-federation/03 — R1: a generic token is not resource-bound
# Validates: A token requested with no resource must not carry the service's audience (confused deputy).

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
require_token_cmd
require_resource_audience

if ! fed_token ""; then
    skip "token command did not return a generic token (${FED_TOKEN_OUT:0:120})"
fi
generic="$FED_TOKEN"

claims=$(jwt_part "$generic" 2)
echo "$claims" | jq -e . >/dev/null 2>&1 || fail "token payload is not JSON"
hit=$(echo "$claims" | jq -r --arg a "$AID_CONF_RESOURCE_AUDIENCE" '[.aud] | flatten | index($a) // empty')
if [ -n "$hit" ]; then
    fail "generic token (no resource) already carries aud ${AID_CONF_RESOURCE_AUDIENCE}"
fi

# Optional: a relying party that requires the specific audience must refuse it.
if [ -n "${AID_CONF_RESOURCE_PROBE_URL:-}" ]; then
    result=$(http_get "$AID_CONF_RESOURCE_PROBE_URL" "Authorization: Bearer ${generic}")
    status=$(http_status "$result")
    case "$status" in
        401|403) note "probe refused the generic token (HTTP ${status})" ;;
        *) fail "probe ${AID_CONF_RESOURCE_PROBE_URL} accepted a generic token (HTTP ${status})" ;;
    esac
else
    note "AID_CONF_RESOURCE_PROBE_URL not set; only the aud claim was checked"
fi

pass "generic token is not bound to ${AID_CONF_RESOURCE_AUDIENCE}"
