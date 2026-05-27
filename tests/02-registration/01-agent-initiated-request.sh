#!/bin/bash
# 02-registration/01 — Agent-initiated registration returns pending + authorization_url + user_code
# Validates: POST /agent_registrations/request returns RFC 8628-style response.

set -eu
source "${LIB}/assert.sh"
source "${LIB}/http.sh"
source "${LIB}/config.sh"
require_base_config

# Discover endpoints
PRM_URL="${AID_CONF_RESOURCE_URL%/}/.well-known/oauth-protected-resource"
prm_result=$(http_get "$PRM_URL" "Accept: application/json")
AS_URL=$(http_body "$prm_result" | jq -r '.authorization_servers[0]')

ASM_URL="${AS_URL%/}/.well-known/oauth-authorization-server"
asm_result=$(http_get "$ASM_URL" "Accept: application/json")
REQ_ENDPOINT=$(http_body "$asm_result" | jq -r '.aid_grant.registration_request_endpoint')
assert_not_empty "$REQ_ENDPOINT" "registration_request_endpoint"

# Build a minimal registration request — ephemeral fingerprint
TENANT="${AID_CONF_TEST_TENANT:-conformance}"
AGENT_NAME=$(ephemeral_agent_name conf-agent)
FAKE_FINGERPRINT="SHA256:$(echo -n "${AGENT_NAME}-$(date +%s)" | shasum -a 256 | cut -d' ' -f1 | head -c 44)="

# Note: real Ed25519 key generation lives in `aid-init`; for a discovery-shape
# test we send a syntactically valid request and verify the response shape.
# Tests that need actual key material will source aid-helper.sh and use real keys.
BODY=$(jq -n \
    --arg name "$AGENT_NAME" \
    --arg address "${AGENT_NAME}@${TENANT}.local" \
    --arg fp "$FAKE_FINGERPRINT" \
    --arg pk "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEA${AGENT_NAME}placeholder=\n-----END PUBLIC KEY-----\n" \
    --arg desc "AID conformance suite ephemeral agent" \
    '{
        agent_registration: {
            name: $name,
            address: $address,
            fingerprint: $fp,
            public_key: $pk,
            key_algorithm: "Ed25519",
            description: $desc
        }
    }')

note "POST ${REQ_ENDPOINT}"

headers=()
[ -n "${AID_CONF_API_KEY:-}" ] && headers+=("X-Api-Key: ${AID_CONF_API_KEY}")

result=$(http_post_json "$REQ_ENDPOINT" "$BODY" "${headers[@]:-}")
status=$(http_status "$result")
body=$(http_body "$result")

# Server may reject placeholder public_key with 422; in that case the test
# can't verify the happy path. Skip rather than fail — a "real key required"
# test belongs in a separate, key-aware test file.
if [ "$status" = "422" ]; then
    skip "Server rejects placeholder public key (422). Use a key-aware test for full coverage."
fi

# Happy path: 201 or 202
case "$status" in
    201|202) : ;;
    *) fail "expected 201 or 202, got ${status}; body: ${body}" ;;
esac

# Response shape: id, attributes.status=pending, attributes.authorization_url, attributes.user_code
assert_json_present "$body" ".data.id"
assert_json_field "$body" ".data.attributes.status" "pending"
assert_json_present "$body" ".data.attributes.authorization_url"
assert_json_present "$body" ".data.attributes.user_code"

# expires_in and interval are MUST per spec (RFC 8628 alignment)
assert_json_present "$body" ".data.attributes.expires_in"
assert_json_present "$body" ".data.attributes.interval"

pass "Agent-initiated registration returns pending + RFC 8628 fields"
