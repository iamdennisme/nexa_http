### Requirement: Request body dispatch avoids a second Rust-side copy
The system SHALL materialize request body bytes into native-owned memory at most once before dispatch and SHALL NOT clone those bytes into a second Rust-owned buffer during request parsing.

#### Scenario: Non-empty request body is dispatched
- **WHEN** Dart dispatches a request with a non-empty body
- **THEN** the bridge SHALL allocate a native-owned request buffer for that payload
- **AND** Rust request parsing SHALL adopt that buffer without using a second body clone such as `to_vec()`

### Requirement: Response body adoption avoids Rust-side re-boxing
The system SHALL return successful response body bytes to Dart through the original native response owner instead of copying them into a second boxed byte buffer after reqwest completes.

#### Scenario: Native request returns a response body
- **WHEN** reqwest completes with a non-empty response body
- **THEN** the native success result SHALL expose body bytes from the original native response owner
- **AND** Dart SHALL release that owner through the existing result-free / finalizer lifecycle
