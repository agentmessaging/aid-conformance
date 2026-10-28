# Changelog

## Unreleased

### Security: review and updates, 2026-10-28

Reviewed the scripts with shellcheck and by hand, searched git history for committed secrets (none found). The suite has no package manifest (bash, curl, jq, openssl; the mock issuer is a single Node file with no dependencies), so there was no dependency audit. There is no CI workflow and no Dockerfile in this repo. This repo has no version number, so none was bumped.

- `lib/http.sh`: request headers (which carry bearer tokens and introspection client credentials) and POST bodies (which can carry client secrets) are no longer passed on the curl command line, where any local user can read them with `ps`. Headers go through a curl config on a pipe (`-K <(...)`) and bodies through stdin. Behaviour is unchanged: the mock-issuer run gives the same results before and after (good issuer 12/12 passed, bad issuer 3 passed, 8 failed).

Not changed: `AID_CONF_AGENT_TOKEN_CMD` is run with `bash -c`. It is an operator-supplied command in the environment, as documented, not input from a remote party.
