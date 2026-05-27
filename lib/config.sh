#!/bin/bash
# =============================================================================
# config.sh — load and validate test configuration
# =============================================================================
#
# Configuration is sourced from environment variables (12-factor style) so
# the suite is CI-friendly without committing secrets.
#
# Required:
#   AID_CONF_AUTH_URL          Auth server URL to test (e.g. https://auth.example.com/tenant)
#   AID_CONF_RESOURCE_URL      Resource URL for discovery tests (e.g. https://api.example.com)
#
# Required for tests that need authorization:
#   AID_CONF_ADMIN_JWT         Admin JWT for admin-initiated registration tests
#   AID_CONF_ROLE_ID           Role ID to assign agents in registration tests
#
# Optional:
#   AID_CONF_API_KEY           X-Api-Key value if the auth server requires one
#   AID_CONF_TEST_TENANT       Tenant identifier for ephemeral test agents
#                              (defaults to "conformance")
#
# Each test that needs admin/role config calls require_admin_config; tests
# that only need the auth URL (e.g. discovery) skip that check.
# =============================================================================

# Required for every test.
require_base_config() {
    if [ -z "${AID_CONF_AUTH_URL:-}" ]; then
        echo "  [SKIP] AID_CONF_AUTH_URL not set" >&2
        exit 2
    fi
    if [ -z "${AID_CONF_RESOURCE_URL:-}" ]; then
        echo "  [SKIP] AID_CONF_RESOURCE_URL not set" >&2
        exit 2
    fi
}

# Required for admin-initiated tests.
require_admin_config() {
    if [ -z "${AID_CONF_ADMIN_JWT:-}" ]; then
        echo "  [SKIP] AID_CONF_ADMIN_JWT not set — admin-initiated test requires it" >&2
        exit 2
    fi
    if [ -z "${AID_CONF_ROLE_ID:-}" ]; then
        echo "  [SKIP] AID_CONF_ROLE_ID not set — admin-initiated test requires it" >&2
        exit 2
    fi
}

# Generate a unique ephemeral agent name for an isolated test.
ephemeral_agent_name() {
    local prefix="${1:-aidconf}"
    echo "${prefix}-$(date +%s)-$$"
}
