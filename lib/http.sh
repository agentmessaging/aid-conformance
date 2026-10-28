#!/bin/bash
# =============================================================================
# http.sh — curl wrappers that return body + status separately
# =============================================================================
#
# Why these wrappers: tests need to assert both response shape AND status
# code. Standard curl conflates them or requires juggling -w / -o files.
# These helpers return a JSON envelope { "status": ..., "body": ..., "headers": ... }.
# =============================================================================

# Headers (Authorization, client credentials) go to curl through a config file on a
# pipe, not on the command line, so they do not show up in `ps` output.
#   _http_header_cfg <header1> [<header2>] ...
_http_header_cfg() {
    local h
    for h in "$@"; do
        h=${h//\\/\\\\}
        h=${h//\"/\\\"}
        printf 'header = "%s"\n' "$h"
    done
}

# GET a URL, return { status, body, headers } as JSON.
#   http_get <url> [<header1>] [<header2>] ...
http_get() {
    local url="$1"
    shift
    local hdrs=("$@")

    local tmp_body tmp_headers tmp_status
    tmp_body=$(mktemp)
    tmp_headers=$(mktemp)
    trap "rm -f '$tmp_body' '$tmp_headers'" RETURN

    tmp_status=$(curl -sS -o "$tmp_body" -D "$tmp_headers" -w "%{http_code}" \
        --connect-timeout 10 --max-time 30 \
        -K <(_http_header_cfg "${hdrs[@]}") "$url" 2>/dev/null) || tmp_status="000"

    local body headers
    body=$(cat "$tmp_body")
    headers=$(cat "$tmp_headers")

    jq -n \
        --arg status "$tmp_status" \
        --arg body "$body" \
        --arg headers "$headers" \
        '{
            status: ($status | tonumber? // 0),
            body: $body,
            headers: $headers
        }'
}

# POST JSON to a URL, return { status, body, headers }.
#   http_post_json <url> <json-body> [<header1>] [<header2>] ...
http_post_json() {
    local url="$1"
    local json_body="$2"
    shift 2
    local hdrs=("Content-Type: application/json" "$@")

    local tmp_body tmp_status
    tmp_body=$(mktemp)
    trap "rm -f '$tmp_body'" RETURN

    tmp_status=$(printf '%s' "$json_body" | curl -sS -X POST -o "$tmp_body" -w "%{http_code}" \
        --connect-timeout 10 --max-time 30 \
        -K <(_http_header_cfg "${hdrs[@]}") \
        --data-binary @- \
        "$url" 2>/dev/null) || tmp_status="000"

    local body
    body=$(cat "$tmp_body")

    jq -n \
        --arg status "$tmp_status" \
        --arg body "$body" \
        '{
            status: ($status | tonumber? // 0),
            body: $body
        }'
}

# POST form-urlencoded data to a URL.
#   http_post_form <url> <form-data> [<header1>] ...
http_post_form() {
    local url="$1"
    local form_data="$2"
    shift 2
    local hdrs=("Content-Type: application/x-www-form-urlencoded" "$@")

    local tmp_body tmp_status
    tmp_body=$(mktemp)
    trap "rm -f '$tmp_body'" RETURN

    tmp_status=$(printf '%s' "$form_data" | curl -sS -X POST -o "$tmp_body" -w "%{http_code}" \
        --connect-timeout 10 --max-time 30 \
        -K <(_http_header_cfg "${hdrs[@]}") \
        --data-binary @- \
        "$url" 2>/dev/null) || tmp_status="000"

    local body
    body=$(cat "$tmp_body")

    jq -n \
        --arg status "$tmp_status" \
        --arg body "$body" \
        '{
            status: ($status | tonumber? // 0),
            body: $body
        }'
}

# Convenience: extract status from an http_* result.
http_status() {
    echo "$1" | jq -r '.status'
}

# Convenience: extract body from an http_* result.
http_body() {
    echo "$1" | jq -r '.body'
}
