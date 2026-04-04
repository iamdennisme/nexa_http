## 1. Define tag-authoritative release identity

- [x] 1.1 Trace the current release-consumer native asset resolution path and identify every place that derives release URLs from local package versions.
- [x] 1.2 Introduce a shared release-identity input for native asset resolution so tagged consumers can supply the authoritative Git tag/ref independently of `pubspec.yaml` version metadata.

## 2. Update carrier and distribution resolution

- [x] 2.1 Update `nexa_http_distribution` to construct manifest and asset URLs from the authoritative release identity while preserving workspace-dev and explicit override behavior.
- [x] 2.2 Update `nexa_http_native_*` carrier hooks to pass the correct release identity into shared distribution resolution across supported platforms.
- [x] 2.3 Ensure local package versions remain advisory metadata and do not override tag-based release-consumer lookup.

## 3. Verify and document the contract

- [x] 3.1 Add focused tests covering tag-based manifest URI resolution and mismatched local package version scenarios.
- [x] 3.2 Refresh release-consumer documentation to state that Git tags/refs govern published native asset lookup while `nexa_http` remains the only public dependency surface.
- [x] 3.3 Validate the fix with a tagged consumer flow or equivalent focused reproduction showing that `v0.0.1` resolves `v0.0.1` assets instead of `v1.0.1`.
