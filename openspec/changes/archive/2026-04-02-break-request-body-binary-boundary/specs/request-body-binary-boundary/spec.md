## ADDED Requirements

### Requirement: Request body construction is binary-first
The system SHALL expose a public request-body API whose canonical payload representation is an owned binary buffer, and SHALL NOT accept a generic `List<int>` contract as the primary request-body input type.

#### Scenario: Caller constructs a binary request body
- **WHEN** application code creates a request body from binary payload bytes
- **THEN** the request-body API SHALL require an explicit binary buffer representation
- **AND** the request body SHALL retain one canonical owned payload for subsequent reads and transport handoff

#### Scenario: Caller constructs a text request body
- **WHEN** application code creates a request body from text
- **THEN** the API SHALL encode that text into owned bytes before dispatch
- **AND** the resulting request body SHALL follow the same binary-first payload model as any other body

### Requirement: Request body transport does not expose dual public views
The system SHALL NOT expose separate public accessors for \"read bytes\" and \"FFI transfer bytes\" for the same request body payload.

#### Scenario: Bridge dispatches a request body through FFI
- **WHEN** Dart request mapping and FFI encoding prepare a request body for native dispatch
- **THEN** they SHALL consume the request body's canonical owned payload
- **AND** the bridge SHALL NOT require a second public transport-specific view of the same bytes

### Requirement: Request DTOs use explicit binary buffer typing
The system SHALL model request-body bytes in Dart transport DTOs as explicit binary buffers rather than generic integer lists.

#### Scenario: Request mapper emits a native request DTO
- **WHEN** the request mapper includes a request body in a `NativeHttpRequestDto`
- **THEN** the DTO SHALL carry that body as an explicit binary buffer type
- **AND** the FFI encoder SHALL copy from that binary buffer into native-owned transfer memory before dispatch

### Requirement: Dead request-default helper abstractions are removed
The system SHALL remove stale request-default helper abstractions that are no longer part of the active Flutter-to-Rust request design.

#### Scenario: Client options expose default headers
- **WHEN** Dart client configuration is represented in `ClientOptions`
- **THEN** it SHALL expose only state that is still used by the current request path
- **AND** stale cached helper views for per-request default-header expansion SHALL NOT remain in the implementation
