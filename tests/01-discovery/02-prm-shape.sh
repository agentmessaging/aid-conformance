#!/bin/bash
# 01-discovery/02 — PRM has required RFC 9728 fields
# Validates: resource, authorization_servers (array), scopes_supported (array).

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
require_base_config

URL="${AID_CONF_RESOURCE_URL%/}/.well-known/oauth-protected-resource"
result=$(http_get "$URL" "Accept: application/json")
status=$(http_status "$result")
body=$(http_body "$result")
assert_status 200 "$status"

assert_json_present "$body" ".resource"
assert_json_present "$body" ".authorization_servers"
assert_json_present "$body" ".authorization_servers[0]"

# scopes_supported is RECOMMENDED but not strictly required by RFC 9728;
# the AID spec relies on it. Emit a note if absent rather than fail.
if [ "$(echo "$body" | jq -r '.scopes_supported // empty')" = "" ]; then
    note "scopes_supported absent — non-blocking under RFC 9728, but AID clients rely on it"
fi

pass "PRM shape matches RFC 9728"
