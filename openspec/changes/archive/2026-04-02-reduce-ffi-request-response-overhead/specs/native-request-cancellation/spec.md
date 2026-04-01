## ADDED Requirements

### Requirement: In-flight call cancellation reaches native execution
The system SHALL provide a request-level cancel operation that maps Dart `Call.cancel()` onto the active native request.

#### Scenario: Caller cancels after dispatch
- **WHEN** application code calls `cancel()` after a request has already been dispatched through FFI
- **THEN** Dart SHALL invoke a native cancel entrypoint for that active request
- **AND** the native runtime SHALL abort best-effort in-flight work for that request

### Requirement: Cancellation completes the Dart call exactly once
The system SHALL complete canceled calls with a cancellation failure and SHALL free any late native result without surfacing a successful response to user code.

#### Scenario: Native completion races with cancellation
- **WHEN** a native result arrives after Dart has already marked the request canceled
- **THEN** the late native result SHALL be freed
- **AND** the canceled call SHALL NOT complete with a successful response
