# OpenAI Runtime Fixes

Started: 2026-04-09

## Goal

Address the OpenAI runtime gaps found during live verification:

- `/api/v1/responses` returned `404`
- `store: true` / `previous_response_id` did not preserve practical continuity
- the fast-tier toggle appeared ineffective

## Changes

### Responses compatibility shim

Added `src/Sources/ResponsesCompatibilityStore.swift` to handle repo-side OpenAI Responses compatibility that can be fixed in the Swift proxy layer:

- normalizes `/api/v1/*` requests to `/v1/*`
- rewrites `previous_response_id` follow-ups into a plain transcript-based prompt when the previous response is known locally
- strips `store` before forwarding to the backend, then restores the requested metadata in the returned JSON response
- stores a lightweight in-memory transcript keyed by response ID for continued follow-up turns

### Proxy wiring

Updated `src/Sources/ThinkingProxy.swift` to:

- normalize rewritten request paths before routing decisions
- run the Responses compatibility preparation step on JSON `POST` requests
- pass an optional JSON response transformer through the response relay

### JSON response buffering

Updated `src/Sources/ResponsesSSEFramer.swift` / `HTTPResponseRelay` so `/v1/responses` JSON responses can be buffered and rewritten safely, including chunked transfer encoding.

### Tests

Added/updated:

- `src/Tests/ResponsesCompatibilityStoreTests.swift`
- `src/Tests/ResponsesSSEFramerTests.swift`

Coverage includes:

- `/api/v1/responses` path normalization
- `previous_response_id` transcript expansion
- restoration of `store` / `previous_response_id`
- chunked JSON body rewrite behavior

## Verification

### Build

- `cd src && swift build` ✅
- `cd src && swift test` ⚠️ fails in this environment with the pre-existing SwiftPM/XCTest issue: `no such module 'XCTest'`
- `make app` ✅

### Runtime checks after reinstall

Rebuilt and reinstalled `VibeProxy.app`, then verified against the running app on `localhost:8317`.

#### 1. `/api/v1/responses`

Direct POST to `http://127.0.0.1:8317/api/v1/responses` now returns `200 OK` and a normal response payload.

Result: fixed in the Swift proxy layer.

#### 2. `store` / `previous_response_id`

Two-turn verification:

- first request stored a response containing `LIME-ROCKET-731`
- second request sent `previous_response_id` referencing that stored response
- returned response preserved:
  - `store: true`
  - `previous_response_id: <first-response-id>`
- model successfully recalled `LIME-ROCKET-731`

Result: fixed locally via transcript-backed compatibility behavior.

#### 3. `service_tier`

Proxy test:

- sending `service_tier: "priority"` through `http://127.0.0.1:8317/v1/responses` still returned `service_tier: "default"`

Direct backend test:

- sending the same payload directly to `http://127.0.0.1:8318/v1/responses` also returned `service_tier: "default"`

Result: not fixable in the Swift repo alone; behavior is currently determined downstream by the bundled `CLIProxyAPIPlus` backend and/or provider handling.

## Repo-side follow-up

Adjusted the Settings UI copy in `src/Sources/SettingsView.swift` from “Force fast tier” to “Request fast tier” so the app no longer overpromises behavior the current backend does not actually honor.
