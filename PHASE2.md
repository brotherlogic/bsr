# Phase 2: Untappd OAuth & User History Pipeline

## 1. Objective

Implement the complete user identity and history ingestion pipeline: Untappd OAuth 2.0 authentication, a rate-limit-aware Untappd v4 API client, bulk CSV history import, and incremental background syncing of a user's rated beers via `/v4/user/beers`.

---

## 2. Deliverables & Scope

### 2.1 Rate-Limit-Aware Untappd API v4 Client (`backend/internal/untappd/`)
- HTTP client wrapper for `https://api.untappd.com/v4/` and `https://untappd.com/oauth/`.
- **Rate-Limit Tracking**:
  - Parses `X-Ratelimit-Limit` and `X-Ratelimit-Remaining` headers on every API response and records remaining quota per user token.
  - Enforces a configurable safety buffer (default: reserve 20 calls/hour for live venue searches) so background history syncs automatically pause when remaining quota drops to the threshold.
- **Supported Endpoints**:
  - OAuth token exchange (`GET /oauth/authorize/`)
  - Authenticated user profile (`GET /v4/user/info`)
  - User distinct beers pagination (`GET /v4/user/beers/{USERNAME}?limit=50&offset=N`)

### 2.2 Untappd OAuth 2.0 Service (`AuthService`)
- `GetAuthURL`: Generates the Untappd OAuth redirect URL with `client_id`, `redirect_url`, and a signed/stored CSRF `state` token.
- `ExchangeAuthCode`: Validates `state`, exchanges the authorization `code` for an Untappd `access_token`, fetches the user's profile via `/v4/user/info`, persists the user in PostgreSQL (`users`), and returns a signed session token (JWT or opaque bearer token) to the client.
- Authentication interceptor/middleware validating the session token on protected RPCs.

### 2.3 CSV Check-in History Parser (`UserService.UploadHistoryCSV`)
- Accepts an Untappd CSV export payload (`beer_name`, `brewery_name`, `beer_type`, `beer_abv`, `beer_ibu`, `rating_score`, `created_at`, `bid`, `global_rating_score`, etc.).
- Aggregates multiple check-ins of the same `bid` for the user (tracking `checkin_count`, `first_had_at`, `last_had_at`, and latest/average `user_rating`).
- Bulk-upserts beer definitions into `beers` and user ratings into `user_beers` inside a single PostgreSQL transaction.

### 2.4 Background API History Syncer (`UserService.SyncUserHistory` & `GetSyncStatus`)
- Paginates through `/v4/user/beers` (50 beers per request), upserting `beers` and `user_beers` into PostgreSQL.
- Stops cleanly when either:
  1. All pages of the user's beer history have been ingested, or
  2. `X-Ratelimit-Remaining` reaches the reserved safety buffer (recording pagination progress so the next sync resumes or tops up seamlessly).
- `GetSyncStatus` reports total distinct beers stored for the user, `last_sync_at`, and remaining Untappd API quota.

---

## 3. Realistic Integration Test Requirements

All Phase 2 components must be verified through end-to-end integration tests running against a **real PostgreSQL database** and a **realistic mock Untappd HTTP server (`httptest.Server`)** serving authentic Untappd v4 JSON payloads and HTTP headers:

1. **OAuth 2.0 End-to-End Handshake Test**:
   - Calls `GetAuthURL` over gRPC/Connect-RPC, simulates the Untappd callback, and invokes `ExchangeAuthCode`.
   - Mock Untappd server verifies query parameters (`client_id`, `client_secret`, `code`, `redirect_url`) and returns a realistic token payload followed by a `/v4/user/info` response.
   - Asserts that the user row and token are persisted in PostgreSQL and that subsequent authenticated RPCs succeed while unauthenticated RPCs fail with `Unauthenticated`.
2. **Realistic Untappd CSV Ingestion Integration Test**:
   - Uploads a multi-row test fixture matching Untappd's real CSV export schema (including duplicate check-ins of the same beer, missing `rating_score` values, decimal ratings like `4.25`, Unicode brewery/beer names, and escaped quotes).
   - Queries PostgreSQL directly and via `GetSyncStatus` to verify accurate deduplication, `checkin_count` aggregation, and `user_rating` persistence.
3. **Multi-Page API Sync & Rate-Limit Throttling Test**:
   - Configures the mock Untappd server with 3 pages of `/v4/user/beers` JSON responses and decrements `X-Ratelimit-Remaining` on each response (e.g., `22 -> 21 -> 20`).
   - Triggers `SyncUserHistory` and verifies that the syncer ingests pages 1 and 2 into PostgreSQL, halts automatically when `X-Ratelimit-Remaining` hits the safety threshold of `20`, and accurately reports status via `GetSyncStatus`.
4. **CSV + API Hybrid Merge Test**:
   - Uploads a historical CSV fixture first, then runs `SyncUserHistory` returning newer check-ins and an updated rating for an existing beer.
   - Verifies that PostgreSQL reflects the merged union of both sources without data loss or duplicate key errors.

---

## 4. Testable Exit Criteria

- [ ] `go test -v -race ./internal/untappd/... ./internal/server/...` passes all OAuth handshake, CSV ingestion, pagination, and rate-limit cutoff integration tests against real PostgreSQL.
- [ ] Uploading a 1,000-row realistic Untappd CSV fixture via `UploadHistoryCSV` completes in `< 500ms` and persists exact counts in `beers` and `user_beers`.
- [ ] Rate-limit budget enforcement guarantees that `SyncUserHistory` never consumes calls below the configured `X-Ratelimit-Remaining` safety reserve.
