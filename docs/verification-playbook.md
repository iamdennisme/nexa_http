# Verification playbook

The repository has one verification authority: the Catalog behind
`scripts/workspace_tools.dart`. GitHub Actions loads its matrices and invokes
complete suites; it does not compose checks itself.

## Toolchain

- Flutter 3.41.5 / Dart 3.11.3 through FVM locally
- Rust stable
- The platform toolchain and a real Flutter device for the selected execution

## Discover the execution matrix

```bash
fvm dart pub get
fvm dart run scripts/workspace_tools.dart matrix --suite verify-static
fvm dart run scripts/workspace_tools.dart matrix --suite verify-integration
fvm dart run scripts/workspace_tools.dart matrix --suite verify-release-candidate
```

Matrix stdout is JSON only. Diagnostics are written to stderr.

## Complete suites

Static verification:

```bash
fvm dart run scripts/workspace_tools.dart verify-static \
  --execution static-linux \
  --report-out reports/static-linux.json
```

Integration verification starts the official platform build once, then reuses
that output for ABI, development-path, and clean-host proofs:

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
fvm dart run scripts/workspace_tools.dart verify-integration \
  --execution apple-macos \
  --fixture-url http://127.0.0.1:8080/healthz \
  --device ios=<simulator-udid> \
  --device macos=macos \
  --report-out reports/apple-macos.json
```

Android uses `http://10.0.2.2:8080/healthz` from the emulator. Windows uses
`--device windows=windows`. Missing platform prerequisites fail the suite; they
are never reported as skipped success.

Candidate verification consumes an already staged, immutable local candidate
set. It does not build or copy a second candidate set:

```bash
fvm dart run scripts/workspace_tools.dart verify-release-candidate \
  --execution candidate-macos \
  --candidate-dir <staged-candidate-directory> \
  --candidate-id <opaque-candidate-id> \
  --candidate-digest <sha256> \
  --sdk-ref <commit-or-sdk-ref> \
  --fixture-url http://127.0.0.1:8080/healthz \
  --device macos=macos \
  --report-out reports/candidate-macos.json
```

Android, iOS, macOS, and Windows candidate rows are all blocking.

## Aggregate coverage

After all matrix rows have uploaded their reports, validate the exact union
without rerunning checks:

```bash
fvm dart run scripts/workspace_tools.dart verify-static \
  --aggregate-reports reports/static
fvm dart run scripts/workspace_tools.dart verify-integration \
  --aggregate-reports reports/integration
fvm dart run scripts/workspace_tools.dart verify-release-candidate \
  --aggregate-reports reports/candidate
```

Duplicate, missing, failed, or drifted reports block aggregation.

## Atomic diagnostics

`check` runs the same Catalog definition and its dependencies, but it is not a
gate conclusion:

```bash
fvm dart run scripts/workspace_tools.dart check native-abi \
  --execution android-linux \
  --fixture-url http://10.0.2.2:8080/healthz \
  --device android=emulator-5554
```

Regression testing against an already published ref remains diagnostic-only:

```bash
fvm dart run scripts/workspace_tools.dart check released-consumer \
  --execution windows-x64 \
  --repo-url https://github.com/iamdennisme/nexa_http.git \
  --ref <real-release-tag> \
  --fixture-url http://127.0.0.1:8080/healthz \
  --device windows=windows
```

## Immutable release transaction

`.github/workflows/release-native-assets.yml` is the only native release
authority. It has two entry modes:

- `pull_request`: derives version from the six package pubspecs, fixes commit
  identity to the PR head, runs the complete candidate transaction, and can
  never run the publisher.
- `workflow_dispatch`: requires `version`, a full 40-character `commit_sha`,
  and `publish`. `publish=false` runs the complete rehearsal. `publish=true`
  is the only publication authorization and is used only after release
  readiness approval.

The workflow projects both fragment and candidate matrices from the Catalog.
Android, Apple, and Windows produce release-profile fragments once. The
assembly job downloads those fragments directly into the final candidate
directory, checks the exact nine canonical assets, generates the manifest and
`SHA256SUMS` once, and uploads one immutable Actions artifact.

Each platform gate downloads that artifact by exact artifact ID and reports
the same identity:

```text
candidate:gha:<run-id>:<artifact-id>:<candidate-sha256>
```

The aggregate job rejects missing platform rows, incomplete runtime lifecycle
proof, or any candidate identity drift. The publisher downloads the same
artifact once, revalidates package version, commit, remote tag/release absence,
manifest URLs, checksums, file coverage, and candidate digest, then uploads the
original files. It performs no build, rename, copy, or metadata regeneration.

Do not create a tag, draft release, prerelease, alternate workflow, or release
script as a substitute. A failed transaction leaves only private Actions
artifacts. If publication fails after this transaction creates public state,
the publisher removes only that transaction's Release and tag.
