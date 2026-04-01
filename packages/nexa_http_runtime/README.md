# nexa_http_runtime

`nexa_http_runtime` owns the native runtime SPI for the `nexa_http` workspace.

## Purpose

This package exists for platform carrier packages and test infrastructure.
Normal Flutter application code should not import it directly.

It provides:

- `NexaHttpNativeRuntime`
- `registerNexaHttpNativeRuntime()`
- `isNexaHttpNativeRuntimeRegistered()`
- dynamic-library loading and host-platform resolution helpers

## Intended Consumers

Typical consumers are:

- `nexa_http_native_android`
- `nexa_http_native_ios`
- `nexa_http_native_macos`
- `nexa_http_native_windows`
- transport tests that need to register a host runtime explicitly

`nexa_http` depends on this package internally for native library loading, but
does not re-export it.

## Versioning

`nexa_http_runtime` is versioned in lockstep with:

- `nexa_http`
- `nexa_http_distribution`
- the carrier packages

Treat it as part of one release train, not as an independently evolving public
package.

The workspace enforces this with
`dart run scripts/workspace_tools.dart verify`, and release publication also
checks the repository tag through
`dart run scripts/workspace_tools.dart check-release-train --tag vX.Y.Z`.
