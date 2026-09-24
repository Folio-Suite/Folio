<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Development CI

GitHub Actions runs `.github/workflows/ci.yml` for pull requests (including stack
layers), merge-queue candidates, pushes to `main`, and manual dispatch. Superseded
runs for the same event and PR/ref are canceled. There are no path filters or
stack-tip skips. PR checks use GitHub's merge checkout; queue checks use the queue
candidate commit.

## Lightweight development builds

`.github/workflows/development-build.yml` runs on pushes to `dev/**` and
`integration/**`, and can also be dispatched manually. It uses one Mac to run the
existing Ruby tests, localization check, and `scripts/check-build.sh`. The build
uses the shared Folio scheme and verifies Kit interfaces and bundle versions.
New pushes cancel superseded runs for that branch; build logs are kept for seven
days.

This is an unsigned compile and repository check. It uses no signing secrets and
does not run native application or UI tests, so it cannot establish that runtime
loading or signing works. It does not replace the full **Suite** gate. Opening a
PR from one of these branches also triggers the full workflow described below;
merge-queue and `main` checks remain unchanged.

## Schemes and parallel work

Four macOS jobs run independently:

- **Suite analysis, build, and repository checks** runs the Ruby tests, read-only localization
  extraction, and a clean coordinated **Folio** scheme analysis and build, including Kit
  interfaces and bundle identity. This unsigned compile check does not execute
  application or UI tests and is not runtime/signing evidence.
  Analyzer findings are errors: `scripts/check-build.sh --analyze` enables
  Clang's analyzer-specific error flag, so a finding fails the full Suite gate.
- **Test Write**, **Test Research**, and **Test Composer** each build and test their
  existing shared scheme on a separate Mac. Those schemes also cover their Kits;
  Write includes FolioKitTests. A failure in one does not cancel the others.

Xcode schemes own configurations, targets, and test selection. GitHub's matrix
only chooses the three app schemes, so their UI tests have independent desktops.
No test lists or per-target build settings are reproduced in YAML. Full Suite
local testing remains available through the Folio scheme and `Folio.xctestplan`.
The generated launch-test variants are retained.

The final **Suite** job succeeds only when the build/check job and every signed
test job succeed. A skipped signing job cannot produce a green Suite check.
Configure branch protection to require **Suite** after the first hosted pass.
This change does not alter repository rules.

The runner is GitHub's ARM64 `xcode-27` public preview, explicitly selecting Xcode
27.0. Its image can change; jobs log the OS/image, Xcode, SDKs, revision, run ID,
and attempt. [Published image inventory](https://github.com/actions/runner-images/releases/tag/xcode-27-arm64%2F20260921.0210).
This first workflow is not Intel or minimum-OS acceptance.

## Development signing

Native tests require a dedicated **Apple Development** certificate and its private
key for the project team, `FT9KDL728H`. Store these environment secrets in
**ci-signing**:

| Secret | Value |
| --- | --- |
| `CI_CERTIFICATE_P12_BASE64` | Base64 of the dedicated certificate/private-key P12 |
| `CI_CERTIFICATE_PASSWORD` | Password protecting that P12 |

An individual Apple Developer membership cannot add another full Developer Program
member. A dedicated CI certificate is still issued under that membership, but
uses a separate private key from the owner's everyday identity. No Apple Account
password or App Store Connect API key is needed in this workflow.
[Apple roles](https://developer.apple.com/help/account/access/roles),
[certificate ownership](https://developer.apple.com/help/account/certificates/certificates-overview).

`scripts/ci-signing.rb` imports the identity into a temporary hosted-runner
keychain, selects that identity by fingerprint, and restores the original keychain
search list and deletes the temporary keychain in an always-run cleanup step.
The decoded P12 is removed immediately after import. GitHub-hosted runners are
disposable. [GitHub's certificate workflow](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).

Hardened Runtime and library validation remain enabled. The CI driver does not
relax either setting. Before executing tests, `scripts/check-ci-signing.rb`
verifies signatures, consistent nonempty Team IDs, Hardened Runtime on apps and
services, and the absence of the disable-library-validation entitlement.

The signing environment trusts code in this repository. Only trusted maintainers
should have branch-writing access; optionally require an environment reviewer
for signed jobs. Fork PRs receive compile/tooling checks but never this key.
After reviewing a fork's code, a maintainer must bring it to a trusted repository
branch for signed testing. The aggregate Suite check fails until those tests run.
Never switch to `pull_request_target` to execute untrusted fork code with secrets.
Actions use pinned commits, read-only repository permission, and no persisted
checkout credentials. Missing signing secrets fail explicitly.

## Run locally

With Xcode 27 selected and a valid local team identity:

```sh
for test in scripts/tests/*_test.rb; do /usr/bin/ruby "$test" || exit; done
/usr/bin/ruby scripts/update-localizations.rb
/usr/bin/ruby scripts/ci.rb /absolute/path/to/new-output Write
```

Use Research or Composer for their scheme, or omit the scheme argument to run the
full Folio plan. Outputs must be new directories. Local signing uses normal Xcode
settings; it neither imports nor exports your key. UI tests need an unobstructed
logged-in desktop. Do not launch multiple app UI suites simultaneously on one Mac;
GitHub parallelizes them across isolated runners.

Logs and `.xcresult` bundles are retained for seven days. CI does not publish apps
or installers. Version **0.1.0 (1)** remains unchanged. Distribution signing,
notarization, installed-runtime acceptance, unique release numbering, and any
Xcode Cloud artifact transfer belong to later release engineering.

## Initial verification — September 24, 2026

Xcode 27.0 (`27A266a`) on ARM64 macOS 27.0 (`26A428`): normal team-signed Suite
build, signature/runtime checks, Kit interfaces, bundle identities, localization
extraction, and the existing 10 Ruby tooling tests passed. All 30 non-UI tests passed
with normal team signing and no runtime exceptions.

The first hosted run at implementation revision `b8c3fe1` passed all four macOS
jobs and the aggregate Suite check:
[run 36031933078](https://github.com/Folio-Suite/Folio/actions/runs/36031933078).
Each app job imported the dedicated certificate and passed the explicit team
signature, Hardened Runtime, and library-validation checks before running tests.
All three test jobs reported `TEST EXECUTE SUCCEEDED`; the Write sidebar reorder
test also passed on the isolated runner. This resolves the earlier local failure
where XCTest reported an obstructing ChatGPT window.

The jobs ran concurrently: Suite checks took 1m22s, Research 2m08s, Composer 2m27s,
and Write 3m36s. The aggregate gate completed 3m42s after the macOS jobs began.
All four diagnostic artifacts were retained, and temporary-keychain cleanup
succeeded in each signed job. The earlier ad-hoc signing experiment is superseded;
the published pipeline preserves both Hardened Runtime and library validation.

Actionlint 1.7.12 validation passed with only its unknown-label diagnostic excluded
for the documented `xcode-27` preview runner.
