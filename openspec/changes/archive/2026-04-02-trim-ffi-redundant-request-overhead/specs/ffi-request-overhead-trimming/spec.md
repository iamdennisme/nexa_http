## ADDED Requirements

### Requirement: Request DTOs omit lease-level default metadata
The system SHALL treat the native client lease as the single source of truth for client-level default headers and fallback timeout values, and SHALL NOT re-encode those defaults into every request DTO.

#### Scenario: Request uses client defaults without overrides
- **WHEN** Dart dispatches a request that does not define request-specific headers or a request-specific timeout
- **THEN** the FFI request payload SHALL omit client-level default headers
- **AND** the FFI request payload SHALL leave request timeout unset
- **AND** native execution SHALL still apply the client lease defaults for that request

#### Scenario: Request overrides client defaults
- **WHEN** Dart dispatches a request with request-specific headers or a request-specific timeout
- **THEN** the FFI request payload SHALL include only those request-specific overrides
- **AND** native execution SHALL preserve request-specific behavior over the client lease defaults

### Requirement: Request body handoff avoids an unnecessary Dart-side pre-copy
The system SHALL provide an internal request-body handoff path that can pass owned request bytes into the native transfer buffer without first materializing an additional defensive Dart copy.

#### Scenario: Bridge dispatches an owned request body
- **WHEN** Dart dispatches a request body through the internal owned-bytes handoff path
- **THEN** the bridge SHALL copy those bytes at most once into native-owned transfer memory before dispatch
- **AND** Rust request parsing SHALL continue to adopt the native transfer buffer without cloning it into a second Rust-owned buffer

#### Scenario: Existing public request body usage remains compatible
- **WHEN** application code builds requests through the current public `RequestBody` API
- **THEN** request dispatch SHALL preserve existing public semantics
- **AND** the lower-copy handoff optimization SHALL remain an internal bridge detail
