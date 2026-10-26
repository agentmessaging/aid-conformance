#!/bin/bash
# 07-federation/05 — R3: introspection requires client credentials
# Validates: An open introspection endpoint answers 'is this stolen token good?' for anyone.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
fed_introspection_endpoint

GARBAGE="eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJub3QtcmVhbCJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
note "POST ${FED_INTRO_URL} with no credentials"
fed_introspect "$GARBAGE" none

case "$FED_STATUS" in
    400|401|403) : ;;
    000) skip "introspection endpoint not reachable" ;;
    *) fail "unauthenticated introspection answered HTTP ${FED_STATUS}, expected 401 (or 400/403)" ;;
esac

# If a real token is available, an unauthenticated call must not reveal anything about it.
if [ -n "${AID_CONF_AGENT_TOKEN_CMD:-}" ] && fed_token ""; then
    fed_introspect "$FED_TOKEN" none
    if [ "$FED_STATUS" = "200" ]; then
        fail "unauthenticated introspection of a valid token answered HTTP 200"
    fi
fi

pass "introspection refuses callers without credentials (HTTP ${FED_STATUS})"
