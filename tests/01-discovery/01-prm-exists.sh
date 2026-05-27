#!/bin/bash
# 01-discovery/01 — Protected Resource Metadata exists at /.well-known/oauth-protected-resource
# Validates: RFC 9728 — the resource server publishes PRM at the well-known URL.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
require_base_config

URL="${AID_CONF_RESOURCE_URL%/}/.well-known/oauth-protected-resource"
note "GET ${URL}"

result=$(http_get "$URL" "Accept: application/json")
status=$(http_status "$result")
body=$(http_body "$result")

assert_status 200 "$status"
assert_not_empty "$body" "response body"

# Must be valid JSON
if ! echo "$body" | jq -e . >/dev/null 2>&1; then
    fail "response body is not valid JSON"
fi

pass "PRM endpoint reachable and returns JSON"
