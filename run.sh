#!/bin/bash
# =============================================================================
# run.sh — AID conformance test runner
# =============================================================================
#
# Walks tests/ subdirectories, runs each .sh file as a separate process,
# captures exit code + stdout/stderr, emits a JSON report + a colored
# CLI summary.
#
# Exit codes per test:
#   0 = PASS
#   1 (or any other non-zero except 2) = FAIL
#   2 = SKIP
#
# Usage:
#   ./run.sh                        # run everything
#   ./run.sh tests/01-discovery     # run one category
#   ./run.sh --output report.json   # write report to a file
#   ./run.sh --verbose              # stream test output
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LIB="${SCRIPT_DIR}/lib"
export AID_CONF_ROOT="${SCRIPT_DIR}"

OUTPUT=""
VERBOSE=false
TARGET="${SCRIPT_DIR}/tests"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

while [ $# -gt 0 ]; do
    case $1 in
        --output)
            OUTPUT="$2"; shift 2 ;;
        --verbose|-v)
            VERBOSE=true; shift ;;
        --help|-h)
            sed -n '4,18p' "$0" | sed 's/^# //; s/^#//'
            exit 0 ;;
        -*)
            echo "Unknown option: $1" >&2; exit 1 ;;
        *)
            TARGET="$1"; shift ;;
    esac
done

if [ ! -d "$TARGET" ]; then
    echo "Target directory not found: $TARGET" >&2
    exit 1
fi

# Check prereqs
for cmd in jq curl shasum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required command not found: $cmd" >&2
        exit 1
    fi
done

# Millisecond timestamp helper — falls back gracefully on macOS (BSD date has no %N)
now_ms() {
    if date +%s%3N 2>/dev/null | grep -qv 'N$'; then
        date +%s%3N
    else
        python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null \
        || echo "$(date +%s)000"
    fi
}

START_TS=$(date +%s)
START_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RESULTS_JSON=$(mktemp)
echo "[]" > "$RESULTS_JSON"

TOTAL=0; PASSED=0; FAILED=0; SKIPPED=0

echo ""
echo -e "${BOLD}AID Conformance Suite${NC}"
echo -e "${GRAY}Target: ${TARGET}${NC}"
echo -e "${GRAY}Started: ${START_ISO}${NC}"
echo ""

# Find all .sh tests under TARGET
TESTS=$(find "$TARGET" -type f -name "*.sh" | sort)

if [ -z "$TESTS" ]; then
    echo -e "${YELLOW}No tests found under ${TARGET}${NC}"
    exit 0
fi

for test in $TESTS; do
    TOTAL=$((TOTAL + 1))
    rel=${test#${SCRIPT_DIR}/}

    test_start=$(now_ms)

    if [ "$VERBOSE" = true ]; then
        echo -e "${BOLD}▶ ${rel}${NC}"
        bash "$test"
        status=$?
        echo ""
    else
        output_file=$(mktemp)
        bash "$test" > "$output_file" 2>&1
        status=$?
    fi

    test_end=$(now_ms)
    duration_ms=$((test_end - test_start))

    case $status in
        0)
            PASSED=$((PASSED + 1))
            outcome="passed"
            symbol="${GREEN}✓${NC}"
            label="${GREEN}PASS${NC}"
            ;;
        2)
            SKIPPED=$((SKIPPED + 1))
            outcome="skipped"
            symbol="${YELLOW}○${NC}"
            label="${YELLOW}SKIP${NC}"
            ;;
        *)
            FAILED=$((FAILED + 1))
            outcome="failed"
            symbol="${RED}✗${NC}"
            label="${RED}FAIL${NC}"
            ;;
    esac

    printf "  %b  %-58s %b  %dms\n" "$symbol" "$rel" "$label" "$duration_ms"

    if [ "$VERBOSE" = false ] && [ -n "${output_file:-}" ]; then
        if [ "$status" -ne 0 ] && [ "$status" -ne 2 ]; then
            sed 's/^/      /' "$output_file"
        fi
        # Capture test output into the report
        test_output=$(cat "$output_file")
        rm -f "$output_file"
    else
        test_output=""
    fi

    # Append to results JSON
    jq --arg test "$rel" \
       --arg outcome "$outcome" \
       --argjson duration_ms "$duration_ms" \
       --arg output "$test_output" \
       '. + [{test: $test, outcome: $outcome, duration_ms: $duration_ms, output: $output}]' \
       "$RESULTS_JSON" > "${RESULTS_JSON}.tmp" && mv "${RESULTS_JSON}.tmp" "$RESULTS_JSON"
done

END_TS=$(date +%s)
END_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DURATION=$((END_TS - START_TS))

echo ""
echo -e "${BOLD}Summary${NC}"
echo -e "  Total:   ${TOTAL}"
echo -e "  ${GREEN}Passed:  ${PASSED}${NC}"
[ "$FAILED" -gt 0 ] && echo -e "  ${RED}Failed:  ${FAILED}${NC}" || echo -e "  Failed:  ${FAILED}"
[ "$SKIPPED" -gt 0 ] && echo -e "  ${YELLOW}Skipped: ${SKIPPED}${NC}" || echo -e "  Skipped: ${SKIPPED}"
echo -e "  Duration: ${DURATION}s"

# Conformance threshold: per the spec, ≥95% of non-skipped tests pass
EFFECTIVE=$((TOTAL - SKIPPED))
if [ "$EFFECTIVE" -gt 0 ]; then
    PCT=$(( (PASSED * 100) / EFFECTIVE ))
    echo -e "  Effective conformance: ${PCT}% (${PASSED}/${EFFECTIVE} non-skipped)"
else
    PCT=0
fi

# Build the final report
REPORT=$(jq -n \
    --arg started "$START_ISO" \
    --arg ended "$END_ISO" \
    --argjson duration_s "$DURATION" \
    --arg target "$TARGET" \
    --argjson total "$TOTAL" \
    --argjson passed "$PASSED" \
    --argjson failed "$FAILED" \
    --argjson skipped "$SKIPPED" \
    --argjson conformance_pct "$PCT" \
    --slurpfile results "$RESULTS_JSON" \
    '{
        suite: "aid-conformance",
        suite_version: "0.1.0",
        started_at: $started,
        ended_at: $ended,
        duration_seconds: $duration_s,
        target: $target,
        summary: {
            total: $total,
            passed: $passed,
            failed: $failed,
            skipped: $skipped,
            conformance_pct: $conformance_pct
        },
        results: $results[0]
    }')

if [ -n "$OUTPUT" ]; then
    echo "$REPORT" > "$OUTPUT"
    echo ""
    echo -e "${GRAY}Report written to: ${OUTPUT}${NC}"
fi

rm -f "$RESULTS_JSON"

# Exit non-zero if any test failed
[ "$FAILED" -gt 0 ] && exit 1 || exit 0
