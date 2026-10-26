#!/bin/bash
# Runs tests/07-federation against fixtures/mock-issuer.mjs (needs node) and checks that each
# test lands where the mock's mode says it should. This proves the tests parse and behave on
# the response shapes they expect; it says nothing about any real issuer.
#
#   ./fixtures/run-against-mock.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v node >/dev/null || { echo "node is required for the mock issuer" >&2; exit 1; }

portfile=$(mktemp)
pids=()
report_dir=$(mktemp -d)
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; rm -f "$portfile"; rm -rf "$report_dir"; }
trap cleanup EXIT

run_mode() {
    local mode="$1"; shift
    node "${ROOT}/fixtures/mock-issuer.mjs" "$mode" 0 > "$portfile" &
    server_pid=$!
    pids+=("$server_pid")
    sleep 1
    local port base
    port=$(head -n 1 "$portfile"); base="http://127.0.0.1:${port}"

    export AID_CONF_AUTH_URL="$base"
    export AID_CONF_RESOURCE_URL="$base"
    # prints the token, or the server's answer on stderr with exit 1; empty audience = no resource parameter
    export AID_CONF_AGENT_TOKEN_CMD="aud=\"\$AID_CONF_TOKEN_AUDIENCE\"; out=\$(curl -s -X POST ${base}/token \${aud:+--data-urlencode resource=\"\$aud\"}); echo \"\$out\" | jq -e .access_token >/dev/null && echo \"\$out\" | jq -r .access_token || { echo \"\$out\" >&2; exit 1; }"
    export AID_CONF_RESOURCE_AUDIENCE="https://crm.acme.example"
    export AID_CONF_INTROSPECT_CLIENT_ID="rp"
    export AID_CONF_INTROSPECT_CLIENT_SECRET="rp-secret"
    AID_CONF_REVOKED_TOKEN=$(curl -s "${base}/revoked-token" | jq -r .token); export AID_CONF_REVOKED_TOKEN
    AID_CONF_SAMPLE_EVENT=$(curl -s "${base}/sample-event" | jq -r .event); export AID_CONF_SAMPLE_EVENT
    "$@"
    local rc=$?
    kill "$server_pid" 2>/dev/null
    return $rc
}

for mode in good bad; do
    echo "=== mock mode: ${mode}"
    run_mode "$mode" "${ROOT}/run.sh" --output "${report_dir}/mock-${mode}.json" "${ROOT}/tests/07-federation"
    echo
done
