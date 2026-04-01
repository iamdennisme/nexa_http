# nexa_http_distribution

`nexa_http_distribution` owns native artifact resolution for the `nexa_http`
workspace.

## Purpose

This package exists for carrier-package build hooks and release tooling. Normal
Flutter application code should not import it directly.

It provides:

- `resolveNexaHttpNativeArtifactFile()`
- `resolveNexaHttpNativeManifestUri()`
- `packageVersionForRoot()`
- manifest parsing, digest helpers, and file-transfer utilities used by native
  artifact distribution

## Intended Consumers

Typical consumers are:

- carrier package build hooks under `packages/nexa_http_native_*`
- release tooling that prepares or validates native asset bundles

`nexa_http` does not depend on this package at runtime.

## Versioning

`nexa_http_distribution` is versioned in lockstep with:

- `nexa_http`
- `nexa_http_runtime`
- the carrier packages

If the native asset format, manifest schema, or resolution rules change, bump
the workspace package set together.
