## Context

The previous simplification work correctly removed `runtime` and `distribution` as public-facing architectural concepts, but the resulting language still leans toward a single-public-package model where `nexa_http` is treated as both:

- the only public Dart API surface, and
- the only public dependency artifact set.

That is not the target architecture.

The target architecture distinguishes:

- API surface: what application code imports and calls
- dependency artifacts: what consumers must declare to assemble a supported integration
- internal implementation details: what consumers must not depend on directly

Under this model:

- `nexa_http` is the only public Dart API surface
- `nexa_http_native_<platform>` packages are public dependency artifacts selected explicitly by consumers
- `nexa_http_native_runtime_internal` and native core remain internal-only implementation details
- production loading follows a fixed loading contract via registered platform runtime strategies

## Goals / Non-Goals

**Goals**
- Separate public API surface from public dependency artifacts
- Make platform package selection explicit and consumer-owned
- Keep `nexa_http` as the single public API layer
- Keep internal runtime/core layers non-public
- Align docs, example guidance, and verification with the explicit dependency model

**Non-Goals**
- Redesigning the native runtime/loading contract
- Changing the Rust native core boundary
- Adding new public Dart APIs
- Preserving the old “`nexa_http` only” dependency guidance if it conflicts with the explicit platform package model

## Decisions

### 1. `nexa_http` remains the only public Dart API surface
Application code must continue to import and use `nexa_http` as the primary SDK API.

**Why:** The SDK API should remain centralized and stable.

### 2. Platform native packages are public dependency artifacts
`nexa_http_native_<platform>` packages are part of the supported public dependency contract and must be declared explicitly by consumers for every target platform they intend to support.

**Why:** Platform selection is a product/integration decision and should not be hidden behind ambiguous package-boundary language.

### 3. Public dependency artifacts are not equivalent to public Dart API surface
A package may be public as a declared dependency artifact without being part of the main imported API surface. Platform native packages are public as dependency artifacts, not as primary application-facing Dart API packages.

**Why:** This prevents confusion between “users install this package” and “users program against this package directly.”

### 4. Internal runtime and native core remain non-public
`nexa_http_native_runtime_internal` and native core must remain unavailable as supported consumer integration surfaces. Production loading must rely on registered platform runtime strategies as the only supported path.

**Why:** These layers exist to support runtime loading and shared native execution, not app-facing integration.

### 5. Example apps must validate the public dependency contract
Repository examples SHALL serve as consumer-contract validation targets and must depend only on:
- `nexa_http`
- the relevant platform native packages

They must not depend on internal runtime packages directly.

**Why:** Examples are contract-validation artifacts, not internal debugging containers.

## Architecture Model

### Public contract

- Public API surface:
  - `nexa_http`

- Public dependency artifacts:
  - `nexa_http`
  - `nexa_http_native_android`
  - `nexa_http_native_ios`
  - `nexa_http_native_macos`
  - `nexa_http_native_windows`

### Internal implementation

- `nexa_http_native_runtime_internal`
- native core
- platform-specific Rust implementation details

## Dependency Model

```text
App
 ├─ depends on → nexa_http
 └─ depends on → nexa_http_native_<platform>

nexa_http
 └─ consumes → internal runtime/loading contract

nexa_http_native_<platform>
 └─ provides → platform runtime strategy + native artifacts

internal/runtime
 └─ supports → SDK + platform packages only

native core
 └─ executes → shared Rust logic
```

## Risks / Trade-offs

- [More explicit integration surface] → consumers declare more packages. This is accepted because the architecture prioritizes explicit platform ownership.
- [Spec churn] → several current statements use “public surface” ambiguously. This change must rewrite that terminology precisely.
- [Verification updates] → consumer verification must stop assuming `nexa_http`-only dependency declarations.
- [Potential package-metadata tension] → package relationships may still temporarily reflect older wiring until implementation catches up.

## Migration Plan

1. Update specs to distinguish API surface vs dependency artifacts.
2. Update docs and example guidance to require `nexa_http` + platform package declarations.
3. Update verification to enforce the explicit dependency contract.
4. Align package-boundary language and repository structure with the new contract.
