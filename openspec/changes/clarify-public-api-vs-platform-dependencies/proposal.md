## Why

The current repository language still conflates two different concepts:

1. `nexa_http` as the only public Dart API surface
2. `nexa_http` as the only public package/dependency surface

That was acceptable while simplifying the old runtime/distribution split, but it no longer matches the intended architecture.

The intended contract is now:

- `nexa_http` is the only public Dart API surface
- platform native packages are public dependency artifacts selected explicitly by consumers per target platform
- `nexa_http_native_runtime_internal` and native core remain non-public implementation details

Without codifying that distinction, the repository continues to mix package-boundary language, example integration, and verification rules from two incompatible models.

## What Changes

- Clarify that `nexa_http` remains the only public Dart API surface.
- Redefine platform native packages as required public dependency artifacts for supported target platforms rather than hidden internal-only package surfaces.
- Require consumer-owned explicit platform package selection.
- Prohibit public integration guidance from treating `nexa_http_native_runtime_internal` as a consumer dependency.
- Rewrite dependency-boundary, verification, and example-facing architecture language to distinguish API surface from dependency artifacts.

## Capabilities

### Modified Capabilities
- `git-consumer-dependency-boundary`
- `platform-runtime-verification`
- `ci-enforced-consumer-verification`

## Impact

- Affected docs: architecture docs, package integration docs, example guidance
- Affected package contract language: `packages/nexa_http`, platform package relationship, example dependency model
- Affected verification: consumer dependency checks and public-boundary rules
- Public API impact: none
- Public dependency contract impact: yes, explicit platform package declaration becomes part of the supported integration model
