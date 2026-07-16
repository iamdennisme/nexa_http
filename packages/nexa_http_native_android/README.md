# nexa_http_native_android

Android Platform Carrier for `nexa_http`. A Host App declares this package as a dependency, while application runtime code continues to import only `package:nexa_http/nexa_http.dart`.

This package is intentionally thin and owns only Android integration:

- plugin registration installs the carrier-owned immutable bindings factory for the Android CodeAsset ID
- the build hook adapter maps Flutter target input to the internal artifact preparer and packages the exact returned file as a CodeAsset
- generated Android bindings resolve symbols from that registered CodeAsset

It does not expose public Dart runtime APIs and does not own HTTP execution, artifact download policy, release orchestration, or the Rust Android Proxy Source. The actual transport API remains in `package:nexa_http`.
