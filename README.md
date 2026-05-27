# AID Conformance Suite

Runnable conformance tests for any implementation of the [Agent Identity (AID) protocol](https://agentids.org). Point the suite at an auth server + a protected resource URL, get back a structured report of which AID requirements the implementation passes, fails, or hasn't covered yet.

The goal is to make **"AID-conformant"** a verifiable property of an implementation rather than a marketing claim.

## Status

**v0.1 scaffold.** 12 tests across 6 categories. The full v1 target is ~100-120 tests — see the [F012 backlog item](https://github.com/agentmessaging/agent-identity/blob/main/backlog/F012-conformance-suite.md) for the planned coverage map.

This scaffold is enough to prove the harness works and dogfoods the AID protocol's own toolchain (bash + curl + jq + openssl, no other runtimes). Contributions to fill out the test count are welcome.

## Running it

```bash
# Required: where your AID-enabled server is
export AID_CONF_AUTH_URL=https://auth.example.com/tenant
export AID_CONF_RESOURCE_URL=https://api.example.com

# Optional, for tests that exercise admin-initiated flows
export AID_CONF_ADMIN_JWT=eyJhbGciOiJSUzI1NiJ9...
export AID_CONF_ROLE_ID=42

# Run
./run.sh

# Save a structured report
./run.sh --output report.json

# Run one category
./run.sh tests/01-discovery

# Stream test output (don't capture)
./run.sh --verbose
```

## What gets checked

| # | Category | What it validates |
|---|---|---|
| 01 | Discovery | RFC 9728 PRM exists & is shaped right; RFC 8414 ASM advertises `urn:aid:agent-identity`; `aid_grant` block has required fields |
| 02 | Registration | Agent-initiated registration returns RFC 8628-style response (pending + user_code + interval); admin-initiated registration rejects unauthenticated calls |
| 03 | Token issuance | Token endpoint rejects empty / invalid grant types correctly |
| 04 | Introspection | RFC 7662 endpoint reachable; invalid tokens return `active: false` with 200 |
| 05 | Lifecycle | Approval-flow endpoints discoverable |
| 06 | Errors | Method-restriction enforcement on token endpoint |

## Test outcomes

| Outcome | Exit code | Meaning |
|---|---|---|
| **PASS** | 0 | Server behaves per the AID spec |
| **FAIL** | non-zero | Server behavior diverges from the spec |
| **SKIP** | 2 | Required configuration missing (e.g. no admin JWT for an admin-initiated test); ignored when computing conformance % |

A "conformance percentage" is computed as `passed / (passed + failed)` — skipped tests don't count against the score.

## Output format

The `--output` flag writes a JSON report:

```json
{
  "suite": "aid-conformance",
  "suite_version": "0.1.0",
  "started_at": "2026-05-27T01:24:02Z",
  "ended_at": "2026-05-27T01:24:06Z",
  "duration_seconds": 4,
  "target": "tests/",
  "summary": {
    "total": 12,
    "passed": 11,
    "failed": 0,
    "skipped": 1,
    "conformance_pct": 100
  },
  "results": [
    {
      "test": "tests/01-discovery/01-prm-exists.sh",
      "outcome": "passed",
      "duration_ms": 84,
      "output": ""
    }
  ]
}
```

Use this to publish a public conformance report for your implementation. Pin the `suite_version` so the claim is verifiable.

## Why bash

The AID protocol's reference client is bash + curl + jq + openssl. Running the conformance suite in the same stack means the harness has zero dependencies that an AID-compliant client wouldn't already need. No Node, no Python (except as an optional fallback for millisecond timestamps on macOS).

Tradeoff: bash is fine for ~120 tests. Beyond that we'd want a real test framework, but at that scale the protocol probably needs its own consortium anyway.

## Adding a test

Every test is a self-contained bash script that:
1. Sources `${LIB}/assert.sh`, `${LIB}/http.sh`, `${LIB}/config.sh`
2. Calls `require_base_config` (and `require_admin_config` if needed)
3. Makes its requests
4. Uses `assert_*` helpers to validate response shapes
5. Calls `pass "summary"` on success
6. Exits with `fail "reason"` on failure, `skip "reason"` if prerequisites missing

Drop the file under `tests/<NN-category>/NN-name.sh`, `chmod +x`, run `./run.sh`.

The included tests are the structural template — copy one and adapt.

## What's NOT here yet (v0 → v1)

The current 12 tests are mostly discovery + error-shape coverage. The bulk of the v1 expansion lives in:

- **Token issuance** — full happy path with a real Ed25519 key, canonical JSON signing, scope intersection, audience binding, oidc_issuer correctness
- **Introspection** — required field assertions (`agent_address`, `agent_role`, `agent_status`, etc.) on a known-valid token
- **Lifecycle** — suspend/reactivate/revoke end-to-end, including verifying that suspension blocks new tokens within seconds
- **RFC 8628 polling errors** — `slow_down`, `authorization_pending`, `expired_token`, `access_denied` with correct HTTP status codes
- **Canonical JSON** — explicit test that the server rejects an identity document signed in non-canonical form
- **Discovery deep tests** — bidirectional cross-references (PRM points to AS, AS metadata matches discovered token_endpoint, etc.)

Filling these in requires the harness to use real Ed25519 keys (which it dogfoods AID for — see `aid-init` + `aid-token`). That's the v0.2 milestone.

## Contributing

PRs welcome. Especially:

- New tests filling out the v1 target coverage map
- Validation against second-party implementations
- Real-Ed25519-key versions of the registration / token tests (currently scaffolded with placeholder material)
- CI workflow that runs the suite against a known-conformant test server on each push

The full coverage roadmap is in [F012 of the AID backlog](https://github.com/agentmessaging/agent-identity/blob/main/backlog/F012-conformance-suite.md).

## License

MIT. See [LICENSE](./LICENSE).

## See also

- [Agent Identity (AID) spec](https://agentids.org) — the protocol this suite validates
- [agent-identity repo](https://github.com/agentmessaging/agent-identity) — reference client (`aid-init`, `aid-token`, etc.)
- [`23blocks/blocks-auth-api`](https://github.com/23blocks/blocks-auth-api) — reference server implementation (private; 23blocks org members only)
