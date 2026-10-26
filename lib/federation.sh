#!/bin/bash
# shellcheck disable=SC2034  # FED_* variables are read by the tests that source this file
# =============================================================================
# federation.sh — helpers for tests/07-federation (issuer requirements R1-R6)
# =============================================================================
#
# Source after assert.sh, http.sh and config.sh. Every federation test starts
# with `require_auth_only_config`; helpers that need optional input skip with
# a reason instead of failing.
#
# Optional input (all env vars, all optional; a test that needs one SKIPs
# when it is missing):
#   AID_CONF_AGENT_TOKEN_CMD         Shell command that prints an access token
#                                    for a real agent and exits 0. It is run
#                                    with AID_CONF_TOKEN_AUDIENCE set to the
#                                    RFC 8707 resource to ask for (empty = no
#                                    resource, a generic token). Example with
#                                    the reference client:
#                                      aid-token.sh --auth "$AID_CONF_AUTH_URL" --no-cache -q \
#                                        ${AID_CONF_TOKEN_AUDIENCE:+--audience "$AID_CONF_TOKEN_AUDIENCE"}
#                                    A failed request must print the server's
#                                    error (for example invalid_target) on
#                                    stderr or stdout and exit non-zero.
#   AID_CONF_RESOURCE_AUDIENCE       A service registered at the issuer
#                                    (RFC 8707 resource identifier)
#   AID_CONF_RESOURCE_PROBE_URL      A relying-party endpoint that requires a
#                                    token for AID_CONF_RESOURCE_AUDIENCE
#   AID_CONF_INTROSPECT_CLIENT_ID    Introspection client credentials
#   AID_CONF_INTROSPECT_CLIENT_SECRET   (HTTP Basic)
#   AID_CONF_REVOKED_TOKEN           A token of a suspended or revoked agent
#   AID_CONF_SAMPLE_EVENT            A signed status event (JWT) the issuer
#                                    delivered or would deliver
#   AID_CONF_SPONSOR_FIELD           Name of the sponsor field in the
#                                    introspection answer, when it is not one
#                                    of: sponsor, sponsor_email, registered_by
# =============================================================================

# Only the auth server URL is needed (federation checks do not use the resource URL).
require_auth_only_config() {
    if [ -z "${AID_CONF_AUTH_URL:-}" ]; then
        echo "  [SKIP] AID_CONF_AUTH_URL not set" >&2
        exit 2
    fi
}

# Fetch the RFC 8414 metadata of AID_CONF_AUTH_URL into FED_ASM.
fed_load_asm() {
    local result
    result=$(http_get "${AID_CONF_AUTH_URL%/}/.well-known/oauth-authorization-server" "Accept: application/json")
    if [ "$(http_status "$result")" != "200" ]; then
        skip "authorization server metadata not reachable at ${AID_CONF_AUTH_URL%/}/.well-known/oauth-authorization-server (HTTP $(http_status "$result"))"
    fi
    FED_ASM=$(http_body "$result")
    echo "$FED_ASM" | jq -e . >/dev/null 2>&1 || skip "authorization server metadata is not JSON"
}

# Set FED_JWKS_URI from the metadata, falling back to the conventional path.
fed_jwks_uri() {
    fed_load_asm
    FED_JWKS_URI=$(echo "$FED_ASM" | jq -r '.jwks_uri // empty')
    if [ -z "$FED_JWKS_URI" ]; then
        FED_JWKS_URI="${AID_CONF_AUTH_URL%/}/.well-known/jwks.json"
    fi
}

# Fetch the JWKS into FED_JWKS (skip when unreachable).
fed_load_jwks() {
    fed_jwks_uri
    local result
    result=$(http_get "$FED_JWKS_URI" "Accept: application/json")
    if [ "$(http_status "$result")" != "200" ]; then
        skip "JWKS not reachable at ${FED_JWKS_URI} (HTTP $(http_status "$result"))"
    fi
    FED_JWKS=$(http_body "$result")
    echo "$FED_JWKS" | jq -e '.keys | type == "array"' >/dev/null 2>&1 || fail "JWKS at ${FED_JWKS_URI} has no keys array"
}

# Skip unless AID_CONF_AGENT_TOKEN_CMD is set.
require_token_cmd() {
    if [ -z "${AID_CONF_AGENT_TOKEN_CMD:-}" ]; then
        skip "AID_CONF_AGENT_TOKEN_CMD not set; cannot obtain an agent token to check"
    fi
}

# Skip unless AID_CONF_RESOURCE_AUDIENCE is set.
require_resource_audience() {
    if [ -z "${AID_CONF_RESOURCE_AUDIENCE:-}" ]; then
        skip "AID_CONF_RESOURCE_AUDIENCE not set; no registered service to request a token for"
    fi
}

# Run the token command for an audience ("" = generic token).
# Sets FED_TOKEN (the token when it printed one), FED_TOKEN_OUT (all output),
# and returns 0 when a three-part token came back.
fed_token() {
    local audience="${1:-}"
    FED_TOKEN_OUT=$(AID_CONF_TOKEN_AUDIENCE="$audience" bash -c "$AID_CONF_AGENT_TOKEN_CMD" 2>&1) || true
    FED_TOKEN=$(echo "$FED_TOKEN_OUT" | tail -n 1 | tr -d '[:space:]')
    case "$FED_TOKEN" in
        *.*.*) return 0 ;;
        *) FED_TOKEN=""; return 1 ;;
    esac
}

# Decode one part of a JWT (1 = header, 2 = payload) to JSON on stdout.
jwt_part() {
    local jwt="$1" index="$2" part pad
    part=$(echo "$jwt" | cut -d. -f"$index" | tr '_-' '/+')
    pad=$(( (4 - ${#part} % 4) % 4 ))
    while [ "$pad" -gt 0 ]; do part="${part}="; pad=$((pad - 1)); done
    echo "$part" | openssl base64 -d -A 2>/dev/null
}

# Locate the introspection endpoint (skip when the issuer advertises none).
fed_introspection_endpoint() {
    fed_load_asm
    FED_INTRO_URL=$(echo "$FED_ASM" | jq -r '.introspection_endpoint // empty')
    if [ -z "$FED_INTRO_URL" ]; then
        skip "authorization server metadata has no introspection_endpoint"
    fi
}

# Skip unless introspection client credentials are set; sets FED_BASIC.
require_introspect_credentials() {
    if [ -z "${AID_CONF_INTROSPECT_CLIENT_ID:-}" ] || [ -z "${AID_CONF_INTROSPECT_CLIENT_SECRET:-}" ]; then
        skip "AID_CONF_INTROSPECT_CLIENT_ID / AID_CONF_INTROSPECT_CLIENT_SECRET not set"
    fi
    FED_BASIC=$(printf '%s:%s' "$AID_CONF_INTROSPECT_CLIENT_ID" "$AID_CONF_INTROSPECT_CLIENT_SECRET" | openssl base64 -A)
}

# Introspect a token. $2 = "auth" sends the client credentials, anything else sends none.
# Sets FED_STATUS and FED_BODY.
fed_introspect() {
    local token="$1" mode="${2:-none}" result
    if [ "$mode" = "auth" ]; then
        result=$(http_post_form "$FED_INTRO_URL" "token=${token}" "Authorization: Basic ${FED_BASIC}")
    else
        result=$(http_post_form "$FED_INTRO_URL" "token=${token}")
    fi
    FED_STATUS=$(http_status "$result")
    FED_BODY=$(http_body "$result")
}

# Turn a JWK (n, e as base64url) into a PEM public key on stdout.
jwk_to_pem() {
    local n="$1" e="$2" n_hex e_hex conf
    n_hex=$(echo "$n" | tr '_-' '/+' | awk '{ while (length($0) % 4) $0 = $0 "="; print }' | openssl base64 -d -A | od -An -tx1 | tr -d ' \n')
    e_hex=$(echo "$e" | tr '_-' '/+' | awk '{ while (length($0) % 4) $0 = $0 "="; print }' | openssl base64 -d -A | od -An -tx1 | tr -d ' \n')
    conf=$(mktemp)
    printf 'asn1=SEQUENCE:k\n[k]\nn=INTEGER:0x%s\ne=INTEGER:0x%s\n' "$n_hex" "$e_hex" > "$conf"
    openssl asn1parse -genconf "$conf" -noout -out "${conf}.der" 2>/dev/null \
        && openssl rsa -RSAPublicKey_in -inform DER -in "${conf}.der" -pubout 2>/dev/null
    local rc=$?
    rm -f "$conf" "${conf}.der"
    return $rc
}

# Verify an RS256 JWT against a PEM public key file. Returns 0 when valid.
jwt_verify_rs256() {
    local jwt="$1" pem="$2" sig input rc
    sig=$(mktemp); input=$(mktemp)
    printf '%s' "$(echo "$jwt" | cut -d. -f1-2)" > "$input"
    echo "$jwt" | cut -d. -f3 | tr '_-' '/+' | awk '{ while (length($0) % 4) $0 = $0 "="; print }' | openssl base64 -d -A > "$sig" 2>/dev/null
    openssl dgst -sha256 -verify "$pem" -signature "$sig" "$input" >/dev/null 2>&1
    rc=$?
    rm -f "$sig" "$input"
    return $rc
}
