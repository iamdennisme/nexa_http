# Deepen Apple proxy settings parser - Design

## Architecture

Target shape:

```text
macOS SystemConfiguration adapter ┐
                                  ├─ shared Apple proxy parser ─> ProxySettings
iOS SystemConfiguration adapter   ┘
```

The shared parser is a pure native-layer internal Rust crate. It receives already-read Apple proxy values and returns `nexa_http_native_core::platform::ProxySettings`.

The platform FFI crates remain the only modules that call CoreFoundation/SystemConfiguration.

This is one cohesive refactor rather than a parent/child task tree: the shared parser contract and both adapters form one acceptance boundary, and neither platform migration is useful without the shared implementation it delegates to.

## Module Boundaries

### Shared Apple Parser Crate

Planned location:

```text
native/nexa_http_native_apple_proxy/
```

Responsibilities:

- Define an `AppleProxySettings` input struct composed of HTTP, HTTPS, and SOCKS entries plus the exceptions list and `exclude_simple_hostnames` flag.
- Represent each proxy entry with its enabled flag, optional host, and optional signed Apple port value; the parser assigns the fixed default scheme for the HTTP, HTTPS, or SOCKS field.
- Convert those values into `ProxySettings`.
- Own shared parser tests for normalization, cleanup, invalid URL handling, bypass deduplication, and `<local>`.

Non-responsibilities:

- No C ABI exports.
- No CoreFoundation/SystemConfiguration imports.
- No platform runtime state ownership.
- No request execution, artifact, or Flutter logic.

Stable module contract:

```text
AppleProxySettings
  http:  enabled + host + port
  https: enabled + host + port
  socks: enabled + host + port
  exceptions: Vec<String>
  exclude_simple_hostnames: bool
        |
        v
parse_apple_proxy_settings(...) -> ProxySettings
```

The shared crate owns value cleanup and URL normalization. Platform adapters own conversion from CoreFoundation dictionary values into this Rust input. The parser uses the `url` crate directly so iOS/macOS FFI crates can drop their parser-only direct `reqwest` dependency while preserving `reqwest::Url` parsing semantics.

### iOS/macOS FFI Crates

Responsibilities retained:

- Own `IosProxySource` / `MacosProxySource`.
- Read current platform proxy values from SystemConfiguration.
- Convert dictionary values into `AppleProxySettings`.
- Delegate pure parsing to the shared parser crate.
- Keep `RefreshMode::ConstructionBoundary`.

## Data Flow

```text
SCDynamicStoreCopyProxies
  -> platform dictionary helpers
  -> AppleProxySettings
  -> apple parser
  -> ProxySettings
  -> ManagedProxyState
  -> Rust transport core
```

## Compatibility

- iOS/macOS public Rust crate exports stay the same:
  - `IosProxySource`
  - `MacosProxySource`
  - `current_proxy_settings_for_test`
- `nexa_http_*` C ABI functions do not change.
- Existing callers of `ManagedProxyState<IosProxySource>` and `ManagedProxyState<MacosProxySource>` do not change.
- The parser's URL output must remain byte-for-byte compatible with current tests where current tests assert exact strings.
- The shared crate is compiled as an internal Rust dependency and statically linked into the existing platform dynamic libraries; it does not create a new release artifact or host-visible package.

## Flutter SDK Contract Mapping

- Host integration surface: unchanged. Apps still declare `nexa_http` plus the target platform carrier and runtime code still imports only `package:nexa_http/nexa_http.dart`.
- Hidden internal packages/artifacts: `nexa_http_native_apple_proxy` is a native-layer implementation crate linked into the existing iOS/macOS dynamic libraries. It is not a Dart package, plugin, carrier, downloadable artifact, or host dependency.
- Native lifecycle ownership: carrier hooks and `nexa_http_native_internal` keep artifact preparation/download/verification responsibilities; platform FFI crates keep SystemConfiguration reads and runtime-state ownership; the shared crate only performs pure parsing.
- Formal configuration: none added. Proxy settings continue to come from Apple SystemConfiguration with the same fallback behavior.
- Failure reporting: unchanged. A null SystemConfiguration result still becomes `ProxySettings::default()`, invalid proxy URLs are ignored, and no new host-visible error or logging channel is introduced.
- Clean-host acceptance: run `verify-development-path` and `verify-external-consumer` on macOS after Rust validation. These checks must succeed without host native-project edits, manual library copying, or imports of internal packages.

## TDD Strategy

1. RED: add a parser-level test for a rule that is duplicated today, using the planned shared crate API. Expected first failure: crate/module does not exist.
2. GREEN: create the shared crate and implement the minimum parser function for that test.
3. REFACTOR: move the remaining duplicated parser helpers from iOS/macOS into the shared parser.
4. RED/GREEN: add additional shared parser tests only when refactor needs a behavior guard not already covered.
5. Update iOS/macOS tests to focus on adapter integration and refresh mode instead of duplicating every parser rule.

## Tradeoffs

- Adding a small crate has more Cargo metadata than moving code into `native_core`, but it preserves ADR-0004 more cleanly by keeping Apple-specific parsing out of `Rust transport core`.
- Keeping duplicate platform tests would preserve coverage but weaken the deepening. Shared parser tests should own parser behavior; platform tests should prove adapter wiring.
- The new crate depends on `nexa_http_native_core` only for `ProxySettings`; it should not create dependency cycles.
- A new internal crate adds one durable native-layer package boundary. Phase 3 spec review must update the native-layer package map if the implementation confirms this boundary.

## Rollback Points

- If the new crate creates unexpected workspace or target complications, stop and return to planning before considering a shared `native_core::platform` module; that alternative changes the approved boundary and requires explicitly revisiting ADR-0004 impact.
- If any parser output changes, stop and decide whether the change is an intentional behavior change. This task defaults to preserving behavior.
