## ADDED Requirements

### Requirement: Repeated request headers survive the FFI bridge
The system SHALL preserve request header order and repeated values from Dart request construction through Rust request execution.

#### Scenario: Request contains repeated header names
- **WHEN** Dart dispatches a request with the same header name repeated multiple times
- **THEN** the FFI request payload SHALL preserve each header entry in its original order
- **AND** Rust request execution SHALL apply each repeated entry without collapsing them through a map

### Requirement: Native client creation uses structured config fields
The system SHALL create native clients through typed FFI config arguments instead of JSON config payloads.

#### Scenario: Client lease is opened with defaults
- **WHEN** Dart creates a native client with default headers, timeout, or user agent
- **THEN** `nexa_http_client_create` SHALL receive those values through structured FFI fields
- **AND** native client creation SHALL NOT parse a JSON config string

### Requirement: Final response URL metadata is only transported when changed
The system SHALL omit final URL metadata from native success results when the resolved response URL matches the original request URL.

#### Scenario: Request completes without redirect
- **WHEN** a native request completes and the resolved response URL matches the original request URL
- **THEN** the native success result SHALL leave final URL unset
- **AND** Dart response mapping SHALL reuse the original request URL
