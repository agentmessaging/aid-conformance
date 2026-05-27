#!/bin/bash
# =============================================================================
# assert.sh — minimal test assertion helpers
# =============================================================================
#
# Source from each test:
#   source "${LIB}/assert.sh"
#
# Each helper prints a structured line to stderr on failure and returns 1.
# Tests should `set -e` so the first failure exits with the right code.
# =============================================================================

# Print a labeled diagnostic line. Doesn't fail by itself.
note() {
    echo "  [note] $*" >&2
}

# Fail with a message + exit code.
fail() {
    echo "  [FAIL] $*" >&2
    exit 1
}

# Assert two values are equal (string comparison).
#   assert_equal <expected> <actual> [<label>]
assert_equal() {
    local expected="$1"
    local actual="$2"
    local label="${3:-values}"
    if [ "$expected" != "$actual" ]; then
        fail "${label}: expected '${expected}', got '${actual}'"
    fi
}

# Assert two values are NOT equal.
assert_not_equal() {
    local unexpected="$1"
    local actual="$2"
    local label="${3:-values}"
    if [ "$unexpected" = "$actual" ]; then
        fail "${label}: expected something other than '${unexpected}'"
    fi
}

# Assert a string is non-empty.
assert_not_empty() {
    local value="$1"
    local label="${2:-value}"
    if [ -z "$value" ]; then
        fail "${label}: expected non-empty, got empty"
    fi
}

# Assert a string contains a substring.
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local label="${3:-string}"
    if ! echo "$haystack" | grep -qF "$needle"; then
        fail "${label}: expected to contain '${needle}'"
    fi
}

# Assert an HTTP status code matches.
#   assert_status <expected> <actual>
assert_status() {
    local expected="$1"
    local actual="$2"
    if [ "$expected" != "$actual" ]; then
        fail "HTTP status: expected ${expected}, got ${actual}"
    fi
}

# Assert a JSON document has a field with a given value.
#   assert_json_field <json> <jq-path> <expected-value>
assert_json_field() {
    local json="$1"
    local path="$2"
    local expected="$3"
    local actual
    actual=$(echo "$json" | jq -r "${path} // \"\"" 2>/dev/null)
    if [ "$actual" != "$expected" ]; then
        fail "${path}: expected '${expected}', got '${actual}'"
    fi
}

# Assert a JSON document has a non-empty field at the given path.
#   assert_json_present <json> <jq-path>
assert_json_present() {
    local json="$1"
    local path="$2"
    local actual
    actual=$(echo "$json" | jq -r "${path} // empty" 2>/dev/null)
    if [ -z "$actual" ] || [ "$actual" = "null" ]; then
        fail "${path}: expected present, got empty/null"
    fi
}

# Assert a JSON array contains a given value (string).
#   assert_json_array_contains <json> <jq-path-to-array> <value>
assert_json_array_contains() {
    local json="$1"
    local path="$2"
    local needle="$3"
    local result
    result=$(echo "$json" | jq -r "${path} | index(\"${needle}\")" 2>/dev/null)
    if [ "$result" = "null" ] || [ -z "$result" ]; then
        fail "${path}: expected to contain '${needle}'"
    fi
}

# Mark a test as skipped (with reason). Exit 2 — runner treats as SKIP.
skip() {
    echo "  [SKIP] $*" >&2
    exit 2
}

# Mark a test as passed (informational).
pass() {
    echo "  [pass] $*" >&2
}
