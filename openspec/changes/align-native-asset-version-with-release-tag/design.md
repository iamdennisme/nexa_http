## Context

The local `other/rust_net` workspace still declares release-train package versions as `1.0.1`, while an externally consumable tag `v0.0.1` was published for integration testing. Native carrier hooks currently derive release-manifest URLs from `packageVersionForRoot(input.packageRoot)`, which reads the local package `pubspec.yaml` version, so remote git consumers request `.../releases/download/v1.0.1/...` even when they intentionally depend on tag `v0.0.1`.

This breaks the core release-consumer contract for federated Flutter native carriers. Git consumers like Kino are doing the right thing by depending on the tagged release, but the build hooks override that contract with local package metadata and become coupled to workspace-internal version state. The fix should preserve the existing federated plugin contract where external apps depend only on `nexa_http` and platform carriers remain internal implementations.

## Goals / Non-Goals

**Goals:**
- Make release-consumer native asset resolution use the authoritative Git tag/ref instead of the local package version.
- Keep the carrier/native distribution logic consistent across supported platforms.
- Preserve workspace-dev flows for local source builds and explicit override environment variables.
- Add verification that tagged git consumers resolve native assets from the tagged release even when workspace package versions differ.

**Non-Goals:**
- Remove workspace package versions entirely.
- Redesign the carrier package architecture or release asset filenames.
- Expose native carrier packages as new public direct-dependency requirements for external consumers.
- Force every package `pubspec.yaml` version to match every experimental tag before the repository can test a tagged release.

## Decisions

### Release-consumer resolution will use a single authoritative release identity
The native distribution layer should have exactly one semantic source of truth for published asset lookup: the externally selected release identity. For git-tag consumers, that means the checked-out git ref or an explicit release-identity input. Local package version metadata may still exist, but it must not act as a second version meaning for release URL construction, manifest selection, or consumer-path decisions.

**Alternatives considered:**
- Continue using `pubspec.yaml` version everywhere. Rejected because it couples external release lookup to local metadata and breaks tag-based consumers.
- Keep both package version and release identity as parallel semantic authorities. Rejected because it preserves ambiguity about which value governs published asset lookup.
- Require every experimental tag to rewrite all package versions first. Rejected because it makes testing tags unnecessarily fragile and contradicts the tag-authoritative release spec.

### Carrier hooks should pass tag-aware release identity into distribution resolution
Each `nexa_http_native_*` hook already delegates artifact lookup to `nexa_http_distribution`. The fix should preserve that layering: teach hooks/distribution to accept a tag-aware release identity rather than hardcoding package-version lookup inside each carrier, while keeping `nexa_http` as the only public dependency surface for consumers.

**Alternatives considered:**
- Patch only one carrier hook (for example macOS). Rejected because all release-consumer carriers share the same bug shape.
- Duplicate tag parsing logic separately in each carrier. Rejected because release identity belongs in distribution-owned tooling.

### Tag-based validation must become part of release-consumer verification
The repository already has tag-authoritative governance specs. The implementation should add automated verification that a git consumer pinned to a tag resolves the manifest and assets under that tag, even if package versions remain on a different maintenance line.

**Alternatives considered:**
- Rely on manual downstream reproduction. Rejected because this exact regression already escaped into a consumer integration.

## Risks / Trade-offs

- [Git checkout metadata may not expose a reliable tag/ref in every consumer environment] → Support an explicit override input and fall back carefully when tag metadata is unavailable.
- [Workspace-dev and release-consumer paths may diverge accidentally] → Keep mode selection explicit and add focused tests for both paths.
- [Tag identity parsing could disagree with release workflow naming] → Reuse the same tag-normalization contract already established by release governance specs.
- [Changing distribution resolution may affect all supported carriers] → Centralize the change in shared distribution logic and validate at least one real consumer flow plus focused hook/unit coverage.
