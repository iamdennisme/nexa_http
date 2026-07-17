# v2.0.2 Release Evidence

## Approved Source

- Release commit: `4baef319fbddcdb47722c5696ee6f7bacc7bda15`
- Commit subject: `chore(release): prepare v2.0.2`
- `origin/main` was fast-forwarded without force and resolved to the same SHA
- Six release package versions and tracked path resolutions were `2.0.2`

## Local Gates

- Focused release, workflow, and governance suite: `51/51` passed
- `verify-static --execution static-linux`: `passed`
- Static report completed all seven planned checks:
  - generated bindings freshness
  - root contract tests
  - Rust clippy, format, and workspace tests
  - workspace Dart analyze and tests
- Final diff contained no runtime, Rust, C ABI, generated binding, workflow,
  target matrix, build hook, or artifact naming changes

## Non-Publishing Rehearsal

- Actions run: `29559938899`
- URL: `https://github.com/iamdennisme/nexa_http/actions/runs/29559938899`
- Conclusion: `success`
- Candidate: `gha:29559938899:8398959092`
- Candidate digest:
  `c0c1d8a59ad1f2ff52c21bececf88760518e161331015d2fe4d3fd573372dc76`
- Three fragment producers, candidate assembly, Android, iOS, macOS,
  Windows, and aggregate all succeeded
- Four reports covered nine prepared targets and four runtime platforms
- Request, callback, body consume, body release, and client close were all
  `true`; every proof used one candidate identity
- Publisher was skipped and post-run checks found no `v2.0.2` tag or Release

## Publishing Transaction

- Actions run: `29560914835`
- URL: `https://github.com/iamdennisme/nexa_http/actions/runs/29560914835`
- Final run attempt: `2`
- Final conclusion: `success`
- Candidate: `gha:29560914835:8399334380`
- Candidate digest:
  `69a90f00c34e8899d5ef256c8129bcedbd0208414430bd8ad488527efb63b6b1`
- Attempt 1 stopped before aggregate/publication because the Android emulator
  package service threw a platform `PackageManagerInternal` null error during
  `adb install`; iOS, macOS, and Windows had passed and public state remained
  absent
- The failed Android job and dependent chain were rerun against the same
  candidate; Android, aggregate, and the unique publisher then succeeded
- Final reports covered nine prepared targets and four runtime platforms
- All four reports were `passed`, completed the full planned suite, shared one
  candidate identity, and had all five lifecycle fields set to `true`

## Published State

- Annotated tag object: `4f23db52e014c405f22c9546615363cdaa645c6b`
- Peeled tag target: `4baef319fbddcdb47722c5696ee6f7bacc7bda15`
- Tag message records the approved candidate ID and digest
- Release ID: `355529150`
- Release URL: `https://github.com/iamdennisme/nexa_http/releases/tag/v2.0.2`
- Release state: non-draft, non-prerelease, stable `v2.0.2`
- Asset count: exactly 11, all in `uploaded` state with GitHub SHA-256 digests

Published assets:

1. `nexa_http-native-android-arm64-v8a.so`
2. `nexa_http-native-android-armeabi-v7a.so`
3. `nexa_http-native-android-x86_64.so`
4. `nexa_http-native-ios-arm64.dylib`
5. `nexa_http-native-ios-sim-arm64.dylib`
6. `nexa_http-native-ios-sim-x64.dylib`
7. `nexa_http-native-macos-arm64.dylib`
8. `nexa_http-native-macos-x64.dylib`
9. `nexa_http-native-windows-x64.dll`
10. `nexa_http_native_assets_manifest.json`
11. `SHA256SUMS`

The nine native asset digests in GitHub matched `SHA256SUMS`; the downloaded
manifest and checksum file also matched their GitHub-reported digests.
