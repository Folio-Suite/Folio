<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Development CI

GitHub Actions runs `.github/workflows/ci.yml` for pull requests (including stack
layers), merge-queue candidates, pushes to `main`, and manual dispatch. Superseded
runs for the same event and PR/ref are canceled. Metadata-only PR edits use a
separate concurrency group so they cannot cancel candidate validation. There are no path filters or
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
PR from one of these branches also triggers the validation selection described below.

## Validation selection

`scripts/ci-evidence.rb`, adapted from KitchenMemory, selects one of three modes:

- **Fast:** draft PRs run Ruby tooling tests and read-only localization checks.
  GitHub prevents merging drafts; marking a PR ready triggers candidate validation.
- **Full:** ready PRs, merge-queue candidates, and `main` pushes require full
  validation unless eligible evidence already exists. Manual dispatch always
  forces a full run.
- **Reuse:** an identical Git tree can reuse a successful full run from the last
  seven days. Repository checks still run. Evidence must match the policy version,
  tree, run ID, and current run attempt, and come from this workflow in this
  repository with a same-repository source branch. Failed, unfinished, expired,
  fork, and other-workflow evidence cannot authorize reuse. Downloaded evidence
  is parsed as bounded JSON data and never executed.

An evidence lookup or parsing failure falls back to full validation. Full runs
publish a small `validated-tree-*` artifact only after all required jobs succeed;
fast and reused runs never renew evidence. Increment `POLICY` in the selector
when changing the validation contract or toolchain. Whole-tree matching also
invalidates reuse when source, workflow, tests, or repository configuration changes.

## Schemes and parallel work

After selection, a full run launches five independent macOS jobs:

- **Suite analysis, build, and repository checks** runs the Ruby tests, read-only localization
  extraction, and a clean coordinated **Folio** scheme analysis and build, including Kit
  interfaces and bundle identity. This unsigned compile check does not execute
  application or UI tests and is not runtime/signing evidence.
  Analyzer findings are errors: `scripts/check-build.sh --analyze` enables
  Clang's analyzer-specific error flag, so a finding fails the full Suite gate.
- **Test Core** builds and tests the four domain frameworks, using the app hosts
  where required. **Test Write**, **Test Research**, and **Test Composer** each
  build and test their app and UI targets on a separate Mac. A failure in one
  does not cancel the others.

Xcode schemes own configurations, targets, and test selection. GitHub's matrix
chooses Core and the three app schemes, so UI tests have independent desktops.
No test lists or per-target build settings are reproduced in YAML. Full Suite
local testing remains available through the Folio scheme and `Folio.xctestplan`.
The generated launch-test variants are retained.

Branch protection requires the final **Suite** job. It checks that selection and
repository checks succeeded, then requires every signed test job for full mode,
a source evidence run for reuse mode, or draft-only checks for fast mode. Unknown
modes and unexpected skipped or failed jobs fail the gate. A skipped signing job
cannot satisfy full validation.

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
for signed jobs. Ready fork PRs receive compile/tooling checks (drafts receive
repository checks only) but never this key.
After reviewing a fork's code, a maintainer must bring it to a trusted repository
branch for signed testing. A full-mode aggregate Suite check fails until those tests run.
Never switch to `pull_request_target` to execute untrusted fork code with secrets.
Actions use pinned commits, read-only repository permission, and no persisted
checkout credentials. Evidence lookup adds read-only Actions permission. Missing
signing secrets fail explicitly. The signing environment does not create GitHub
deployment records; these jobs validate development builds.

## Run locally

With Xcode 27 selected and a valid local team identity:

```sh
for test in scripts/tests/*_test.rb; do /usr/bin/ruby "$test" || exit; done
/usr/bin/ruby scripts/update-localizations.rb
/usr/bin/ruby scripts/ci.rb /absolute/path/to/new-output Write
```

Use Core, Research, or Composer for their scheme, or omit the scheme argument to run the
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

## Current Swift migration verification

The September 24 results above predate the current Swift ports and TypographyKit/
ComposerKit preview. Integrated signed native tests and final migration acceptance
for the current source are pending; those earlier results do not cover this work.
