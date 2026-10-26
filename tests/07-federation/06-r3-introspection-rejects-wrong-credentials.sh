#!/bin/bash
# 07-federation/06 — R3: introspection refuses wrong credentials
# Validates: A bad client secret must not be treated as authentication.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
if [ -z "${AID_CONF_INTROSPECT_CLIENT_ID:-}" ]; then
    skip "AID_CONF_INTROSPECT_CLIENT_ID not set"
fi
fed_introspection_endpoint

GARBAGE="eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJub3QtcmVhbCJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
# shellcheck disable=SC2034  # read by fed_introspect
FED_BASIC=$(printf '%s:%s' "$AID_CONF_INTROSPECT_CLIENT_ID" "aid-conformance-wrong-secret-$$" | openssl base64 -A)
note "POST ${FED_INTRO_URL} with a wrong secret"
fed_introspect "$GARBAGE" auth

case "$FED_STATUS" in
    400|401|403) : ;;
    000) skip "introspection endpoint not reachable" ;;
    *) fail "wrong credentials answered HTTP ${FED_STATUS}, expected 401 (or 400/403)" ;;
esac

pass "wrong introspection credentials refused (HTTP ${FED_STATUS})"
