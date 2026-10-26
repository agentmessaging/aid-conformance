#!/bin/bash
# 07-federation/02 — R1: an unregistered resource is refused with invalid_target
# Validates: RFC 8707 section 2: an unknown resource gets invalid_target, not a token.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
source "${LIB}/federation.sh"
require_auth_only_config
require_token_cmd

note "baseline: a request with no resource must work, or the command cannot be trusted"
if ! fed_token ""; then
    skip "token command could not get a baseline token (${FED_TOKEN_OUT:0:120}); a refusal would prove nothing"
fi

BOGUS="https://aid-conformance.invalid/unregistered-$$"
note "requesting a token with resource=${BOGUS}"
if fed_token "$BOGUS"; then
    fail "issuer issued a token for an unregistered resource (${BOGUS})"
fi

assert_contains "$FED_TOKEN_OUT" "invalid_target" "refusal"

pass "unregistered resource refused with invalid_target"
