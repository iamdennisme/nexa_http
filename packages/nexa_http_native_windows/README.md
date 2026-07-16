# nexa_http_native_windows

Windows Platform Carrier for `nexa_http`. A Host App declares this package as a dependency, while application runtime code continues to import only `package:nexa_http/nexa_http.dart`.

This package is intentionally thin and owns only Windows integration:

- plugin registration installs the carrier-owned immutable bindings factory for the Windows CodeAsset ID
- the build hook adapter maps Flutter architecture input to the internal artifact preparer and packages the exact returned file as a CodeAsset
- generated Windows bindings resolve symbols from that registered CodeAsset

It does not expose public Dart runtime APIs and does not own HTTP execution, artifact download policy, release orchestration, or the Rust Windows Proxy Source. The actual transport API remains in `package:nexa_http`.
