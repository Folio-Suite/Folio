<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# GitHub Actions CI assessment

Researched September 24, 2026. The implementation following this assessment is
specified in [Development CI](../development-ci.md); that document supersedes
numbering and rollout recommendations below. The owner selected static 0.1.0 (1)
for now, GitHub for development verification, and left Xcode Cloud release
engineering for a separate pilot. No release-number allocator is being introduced.

The live repository check found `Folio-Suite/Folio` public, default branch `main`,
Actions enabled, and no existing workflows. The Actions API reported a read-only
default workflow token and no permission for workflows to approve pull requests.
The workflow adds explicit read-only permissions and immutable action pins.

## Available runners and cost

GitHub currently documents `xcode-27` as a **standard ARM64 public-preview runner**
for public and private repositories: three M1 cores and 7 GB RAM. The published
September 21 image release reports macOS 27.0 (`26A428`), image
`20260921.0210.1`, and default Xcode 27.0 (`27A266a`) at
`/Applications/Xcode_27.app`. Its versioned symlink is
`/Applications/Xcode_27.0.app`. These are published inventory facts, not a Folio
job execution result. [Runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
[image release](https://github.com/actions/runner-images/releases/tag/xcode-27-arm64%2F20260921.0210).

The repository's main-branch image README still showed the September 12 image
and an RC-named Xcode directory during this research. Prefer the dated release
for this snapshot, then log `sw_vers`, `xcodebuild -version`, SDK versions, and
the actual image version in every job. Select the Xcode version explicitly.
`macos-latest` currently points to macOS 26 ARM64; `macos-26-intel` is available
for Intel coverage. An OS label is not an immutable image pin.
[Image README](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md),
[label inventory](https://github.com/actions/runner-images).

Standard hosted runners are free for public repositories. Larger runners are
charged even for public repositories. For private repositories, usage consumes
the owner's plan allowance; the published standard macOS overage rate is
$0.062/minute. Artifact storage has its own allowance and billing, so free
compute does not justify retaining every DerivedData directory. These are
service rates, not an account-specific bill estimate.
[GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

## Proposed first implementation

1. Run the Ruby release, packaging, and localization tooling tests, plus the
   read-only localization extraction check. Use macOS where the tooling invokes
   Apple utilities; do not assume all Ruby checks are portable to Linux.
2. Build the shared Folio scheme using the existing unsigned
   `scripts/check-build.sh`, which checks apps, Kits, XPC products, public Kit
   interfaces, and coherent bundle identities. Add Release/universal compilation
   separately; an ARM Debug build does not prove the Intel release slice.
3. Pilot signed `build-for-testing` followed by `test-without-building` for the
   native suites. Retain `.xcresult` and logs even on failure. Introduce required
   checks only once their actual coverage and runner reliability are understood.
4. Add installer staging and clean-install acceptance as separate work. Package
   generation, successful linking, and UI tests from DerivedData do not establish
   installed shared-framework resolution or notarized distribution.

These stages follow [contributor validation](../../CONTRIBUTING.md) and
[installer acceptance](../installer.md). Keep workflow glue small and put reusable
logic in the existing Ruby tooling.

### Build numbering decision

The owner superseded the scheme counter with a fixed **0.1.0 (1)**. The counter
and its pre-action are removed for development CI. Diagnostic artifacts use
GitHub run ID/attempt and the checked-out revision. Unique shipping identities
will be addressed with release engineering; see [the current contract](../release-numbering.md).

## Native testing and trust boundaries

An unsigned compile is not proof that XCTest can launch its host or UI runner.
For the pilot, verify the generated runner signatures, GUI session/accessibility
authorization, actual executed test counts, and resulting `.xcresult`. Ad hoc
signing without credentials is worth investigating for untrusted PR verification,
but is **not established here as sufficient for Folio's native tests**.

GitHub documents importing signing credentials from secrets into a temporary
keychain. ARM runners lack a static UDID; GitHub notes that building/signing and
testing on the same host can use a development provisioning profile. Determine
Folio's actual entitlement/profile needs before provisioning credentials.
[Signing on runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications),
[runner restrictions](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

Use ordinary `pull_request` verification with minimal token permissions
(`contents: read`), no distribution secrets, and actions pinned to verified full
commit SHAs. Keep credential-bearing release jobs on trusted revisions. Do not
execute fork code in a privileged `pull_request_target` job. Native signed tests
must not become a reason to expose release identities to PR code.
[GitHub security guidance](https://docs.github.com/en/actions/reference/security/secure-use),
[fork event trust model](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target).

Start with seven-day diagnostic artifact retention, cancel superseded PR jobs,
and impose job timeouts. Those are proposed cost/reliability choices, not service
requirements. GitHub supports per-artifact retention settings within repository
limits. [Artifacts documentation](https://docs.github.com/en/actions/tutorials/store-and-share-data).

## Xcode Cloud clarification

Xcode Cloud is integrated with App Store Connect, but **does not require App
Store submission**: Apple demonstrates a Notarize post-action and downloading
the resulting Mac app for direct distribution. Apple Developer Program membership
also includes 25 compute hours each month. It is therefore not inherently a
paid-only or App-Store-only option.
[Apple's direct-distribution demonstration](https://developer.apple.com/videos/play/wwdc2023/10224/),
[Xcode Cloud requirements and allowance](https://developer.apple.com/xcode-cloud/get-started/).

GitHub remains the recommended first choice for this public repository because
of its compute terms and control over Suite tooling and installer workflows.
That is a project-fit judgment. Neither service's general capabilities prove
Folio's multi-application installer pipeline or native UI tests work there;
those require execution evidence.

### Stacked pull requests and merge groups

GitHub's native stacks are in public preview and support atomic merging of a
selected PR together with all lower unmerged PRs. Each layer still has to satisfy
the stack base's rules. Actions receives `pull_request.stack` metadata, including
position and size, and GitHub explicitly documents running costly jobs at the
top of a stack. Default PR triggers still run once per layer; stacks alone do
not eliminate redundant CI.
[Stack semantics](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests),
[Stack-aware CI](https://docs.github.com/en/enterprise-cloud@latest/pull-requests/how-tos/merge-and-close-pull-requests/optimizing-ci-for-stacked-pull-requests).

For a merge queue, Actions supports `merge_group` directly; third-party CI must
monitor `gh-readonly-queue/{base_branch}` branches and report against their SHA.
Queue merge limits do not combine CI builds, and oversized stacks may split into
successive merge groups. Proposed layout: inexpensive per-PR checks, optional
full-stack feedback at the top, full required verification of each candidate
merge group, and artifact publication from trusted integrated revisions. Required
check design must prevent a partial-stack merge from bypassing full verification;
a passing check on the original stack tip is not evidence for every prefix.
[Merge queue configuration](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue).

Using one provider still does not automatically give a global artifact counter:
`github.run_number` is scoped to one workflow and does not change on retries.
`github.run_attempt` distinguishes retries. The numbering contract must account
for both multiple workflows and rebuilt artifacts; logs alone need not allocate
a Suite binary identity. Do not silently map those fields to `CFBundleVersion`
before settling that contract.
[Actions run identity](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts).

Apple documents ordinary pull-request validation: Xcode Cloud checks out a PR's
source and target branches, merges them in a temporary environment, and runs the
workflow. It also supports branch-prefix start conditions. Those capabilities
can accommodate dependent branches, but a per-PR source/target merge does not
establish validation of GitHub's final merge-group revision.
[Apple start conditions](https://developer.apple.com/documentation/xcode/configuring-start-conditions).

Xcode Cloud can publish required PR status checks. The Apple workflow and API
documentation reviewed on September 24, 2026 does not establish native handling
of GitHub stack metadata or `merge_group` events. This is a documentation gap,
not proof that an integration is impossible. A branch-triggered integration
would need a pilot proving it detects GitHub's temporary queue branch, builds
the exact group revision, and reports the required check on that revision.
[Apple required checks](https://developer.apple.com/documentation/xcode/configuring-requirements-for-merging-a-pull-request),
[Apple workflow reference](https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference).

Apple's API also permits starting builds with workflow and Git-reference
relationships (or a pull-request relationship). Apple demonstrates a custom
external trigger using this API, and notes that API-started builds require a
matching manual start condition. An adapter is therefore a possible research
path; its existence does not prove stack-aware scheduling or merge-queue status
reporting. Prefer the service with documented native integration if avoiding
custom CI orchestration is a selection criterion.
[Build request relationships](https://developer.apple.com/documentation/appstoreconnectapi/cibuildruncreaterequest/data-data.dictionary/relationships-data.dictionary),
[Apple's API-trigger demonstration](https://developer.apple.com/videos/play/wwdc2024/10200/).
