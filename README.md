# AID Conformance Suite

Runnable conformance tests for any implementation of the [Agent Identity (AID) protocol](https://agentids.org). Point the suite at an auth server + a protected resource URL, get back a structured report of which AID requirements the implementation passes, fails, or hasn't covered yet.

The goal is to make **"AID-conformant"** a verifiable property of an implementation rather than a marketing claim.

## Status

**v0.1 scaffold.** 24 tests across 7 categories (12 discovery-to-errors tests, 12 federation tests). The full v1 target is ~100-120 tests — see the [F012 backlog item](https://github.com/agentmessaging/agent-identity/blob/main/backlog/F012-conformance-suite.md) for the planned coverage map.

This scaffold is enough to prove the harness works and dogfoods the AID protocol's own toolchain (bash + curl + jq + openssl, no other runtimes). Contributions to fill out the test count are welcome.

## Running it

```bash
# Required: where your AID-enabled server is
export AID_CONF_AUTH_URL=https://auth.example.com/tenant
export AID_CONF_RESOURCE_URL=https://api.example.com

# Optional, for tests that exercise admin-initiated flows
export AID_CONF_ADMIN_JWT=eyJhbGciOiJSUzI1NiJ9...
export AID_CONF_ROLE_ID=42

# Optional, for the federation category (tests/07-federation); each test SKIPs
# with a reason when what it needs is missing
export AID_CONF_RESOURCE_AUDIENCE=https://crm.acme.example      # a service registered at the issuer (RFC 8707)
export AID_CONF_AGENT_TOKEN_CMD='aid-token.sh --auth "$AID_CONF_AUTH_URL" --no-cache -q ${AID_CONF_TOKEN_AUDIENCE:+--audience "$AID_CONF_TOKEN_AUDIENCE"}'
export AID_CONF_INTROSPECT_CLIENT_ID=... AID_CONF_INTROSPECT_CLIENT_SECRET=...
export AID_CONF_REVOKED_TOKEN=...        # a token of a suspended or revoked agent
export AID_CONF_SAMPLE_EVENT=...         # a signed status event (JWT) from the issuer
export AID_CONF_RESOURCE_PROBE_URL=...   # a relying-party endpoint that requires that audience
export AID_CONF_SPONSOR_FIELD=...        # sponsor field name if not sponsor, sponsor_email or registered_by

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
| 07 | Federation | Issuer requirements R1-R6 of the [AID federation profile](https://github.com/agentmessaging/agent-identity/pull/24) (section 7): per-service `aud` and `invalid_target`, `scope` string, authenticated introspection and `active:false` for a revoked agent, signed status event shape, JWKS `kid` and rotation overlap, `agent_role` and sponsor in the introspection answer |

### Federation checks (07)

`tests/07-federation` needs only `AID_CONF_AUTH_URL` (it does not use `AID_CONF_RESOURCE_URL`). It reads the issuer's RFC 8414 metadata for `jwks_uri` and `introspection_endpoint`. Because the token endpoint needs the agent's signed identity, the suite does not mint tokens itself: `AID_CONF_AGENT_TOKEN_CMD` is a shell command that prints an access token, run with `AID_CONF_TOKEN_AUDIENCE` set to the RFC 8707 resource to ask for (empty for a generic token). A failed request must print the server's error and exit non-zero.

| Test | Needs besides the auth URL | Else |
|---|---|---|
| 01 R1 audience is exactly the resource | token command, resource audience | SKIP |
| 02 R1 unregistered resource gets `invalid_target` | token command (a no-resource token must work first) | SKIP |
| 03 R1 generic token is not resource-bound | token command, resource audience (probe URL adds a relying-party check) | SKIP |
| 04 R2 `scope` string equals `scopes` | token command | SKIP |
| 05 R3 introspection refuses callers without credentials | nothing | SKIP if no `introspection_endpoint` |
| 06 R3 introspection refuses a wrong secret | client id | SKIP |
| 07 R3 authenticated introspection reports a live token active | token command, client credentials | SKIP |
| 08 R3 revoked agent's token is `active:false` | revoked token, client credentials | SKIP |
| 09 R4 status event shape and signature | sample event | SKIP |
| 10 R5 every JWKS key has a unique `kid` | nothing | SKIP if JWKS unreachable |
| 11 R5 more than one key during rotation overlap | nothing | SKIP when one key is published (the overlap is not observable) |
| 12 R6 `agent_role` and sponsor in the introspection answer | token command, client credentials | SKIP |

R4 is checkable from outside only as far as a sample event allows: whether the issuer actually delivers events to a registered receiver is not tested. The profile names the sponsor but not its field; test 12 accepts `sponsor`, `sponsor_email` or `registered_by`, or the name in `AID_CONF_SPONSOR_FIELD`.

**How far these have been exercised.** The federation tests were syntax-checked (`bash -n`), linted with shellcheck, and run only against a mock issuer (`fixtures/mock-issuer.mjs`, driven by `fixtures/run-against-mock.sh`, needs node) in a conforming and a non-conforming mode: 12 of 12 passed against the conforming mock, and the non-conforming mock produced 3 passes, 8 failures and 1 skip. They have **not** been run against any real issuer, so response shapes of real issuers (error bodies, status codes, the sponsor field name) are assumptions taken from the profile text. The other 12 tests were not re-run for this change.

Note: the older test `04-introspection/02` sends an unauthenticated introspection request and expects 200 with `active:false`, which an issuer that meets R3 will not answer. Both can be correct for different issuers; read the two together.

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
