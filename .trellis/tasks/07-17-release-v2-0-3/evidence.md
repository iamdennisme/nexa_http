# v2.0.3 Release Evidence

## Approved Source

- Release commit: `0bdc99357e53e4f19838ce12bcd203c912fa1e73`
- Commit subject: `chore(release): prepare v2.0.3`
- `origin/main` was fast-forwarded without force and resolved to the same SHA.
- Six release package versions and five tracked path resolutions were `2.0.3`.
- Published `v2.0.2` state was never dispatched, retagged or mutated.

## Local Gates

- Android command/adapter focused suite: `30/30` passed.
- Release transaction, workflow and governance focused suite: `51/51` passed.
- Complete `test/verification` suite: `142/142` passed.
- `fvm dart analyze`: no issues found.
- `verify-static --execution static-linux`: schema v2, `passed`, all seven planned checks completed:
  - generated bindings freshness
  - root contract tests
  - Rust clippy, format and workspace tests
  - workspace Dart analyze and tests
- Final release metadata diff contained no Dart product runtime, Rust/native source, C ABI, generated binding, target matrix, carrier implementation or release workflow changes.

## Exact-SHA CI

- Actions run: `29574151246`
- URL: `https://github.com/iamdennisme/nexa_http/actions/runs/29574151246`
- Head SHA: `0bdc99357e53e4f19838ce12bcd203c912fa1e73`
- Conclusion: `success`
- Catalog matrix, static, Android integration, Apple integration, Windows integration and final `ci-gate` all succeeded.

## Non-Publishing Rehearsal

- Actions run: `29575440926`
- URL: `https://github.com/iamdennisme/nexa_http/actions/runs/29575440926`
- Run attempt: `1`
- Conclusion: `success`
- Candidate: `gha:29575440926:8404966517`
- Candidate digest: `f3914fa15db09e2e29b5d0bcd5a17bf0e13085a5ec741360c1fe866f48050db4`
- Transaction input, three fragment producers, single candidate assembly, Android/iOS/macOS/Windows gates and aggregate all succeeded.
- Four schema-v2 reports covered nine prepared targets and four runtime platforms, shared one candidate identity, completed every planned check and set request, callback, body consume, body release and client close to `true`.
- Publisher was skipped. Post-run Git and GitHub API checks found no `v2.0.3` tag, draft, prerelease or Release.

## Publishing Transaction

- Actions run: `29578369024`
- URL: `https://github.com/iamdennisme/nexa_http/actions/runs/29578369024`
- Run attempt: `1`
- Conclusion: `success`
- Candidate: `gha:29578369024:8406102416`
- Candidate digest: `eb53add7cbfe62559f746fb442bff60e55b54a9541c34c9f352bceb661a7a1ed`
- Transaction input, three fragment producers, single candidate assembly, Android/iOS/macOS/Windows gates, aggregate and the unique publisher all succeeded.
- Four schema-v2 reports covered nine prepared targets and four runtime platforms, shared one candidate identity, completed every planned check, used exactly one packaged payload per platform and set all five lifecycle fields to `true`.
- The first CLI dispatch invocation failed while reading GitHub workflow metadata with a transient `EOF`. Audit confirmed no new run and no public state before the single successful publishing dispatch above.

## Published State

- Annotated tag object: `b83776d63c8eaab6336cee94f860ba085a2b0936`
- Peeled tag target: `0bdc99357e53e4f19838ce12bcd203c912fa1e73`
- Tag message records candidate `gha:29578369024:8406102416` and digest `eb53add7cbfe62559f746fb442bff60e55b54a9541c34c9f352bceb661a7a1ed`.
- Release ID: `355660029`
- Release URL: `https://github.com/iamdennisme/nexa_http/releases/tag/v2.0.3`
- Release state: non-draft, non-prerelease, stable `v2.0.3`
- Published at: `2026-07-17T12:16:30Z`
- Asset count: exactly 11; every asset is in `uploaded` state and has a GitHub SHA-256 digest.

Published assets:

1. `nexa_http-native-android-arm64-v8a.so` - `18e80f8e5eeee359e3318609f9e064f7425638ebd78fbdf8c04d143d809bda2c`
2. `nexa_http-native-android-armeabi-v7a.so` - `2fac079a87a54a44c71bd166efc712ecee11c8076074e64cb2c710a5563b85e3`
3. `nexa_http-native-android-x86_64.so` - `7aa9efdf7c9497da5b90fc3836708c22587adc592e3ccd37df472c1e379e8161`
4. `nexa_http-native-ios-arm64.dylib` - `902798c2c34c696c8cd24c3a1c87ad898712bb30a12206ff47c24b00624c61bd`
5. `nexa_http-native-ios-sim-arm64.dylib` - `a22aa42586cc856fa78250cc298805160b0ef93cb979aeca6e6a3b2e81373dea`
6. `nexa_http-native-ios-sim-x64.dylib` - `83b230e13b0a40741c6a7752e725a6024a4af8eb63d9080b335f32836d1511dd`
7. `nexa_http-native-macos-arm64.dylib` - `1c0e14d18f5af69b6c828d79d8941ba9302a0798eaccf0bcda5ecccab2b94917`
8. `nexa_http-native-macos-x64.dylib` - `2eb294b4271fc231fc023d5fda891c7ce6c350753822e65b4390b668f17def09`
9. `nexa_http-native-windows-x64.dll` - `a0b4dd0f96edb31dd51ef0b8266271e701e8b95208fbd065e1875205cb218849`
10. `nexa_http_native_assets_manifest.json` - `78d66cda52b8628ce7364d78a8abbcf95d95733814cd2e632c4bc6deba2be1f3`
11. `SHA256SUMS` - `e02512ff1348f41829b39f35ef7cd15c72cceedf94b3ca9f14e095806ac20262`

The downloaded manifest contained exactly nine assets, used only `v2.0.3` release URLs and valid lowercase SHA-256 values. Its name/digest set matched `SHA256SUMS`, and the nine native asset digests matched GitHub's asset API. The downloaded manifest and checksum file also matched their own GitHub-reported digests.
