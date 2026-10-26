# Phase 1: Protobuf Schema, Database Foundation & Backend Scaffold

## 1. Objective

Establish the foundational monorepo structure, complete Protocol Buffer API definitions (`proto/bsr/v1/bsr.proto`), generated Go and Dart stubs, PostgreSQL schema migrations, and a running Go gRPC / Connect-RPC service scaffold with Kubernetes deployment manifests for `brotherlogic/prod`.

---

## 2. Deliverables & Scope

### 2.1 Protocol Buffers (`proto/bsr/v1/bsr.proto`)
Define the full RPC and message contract for BSR:
- **`AuthService`**:
  - `GetAuthURL(GetAuthURLRequest) returns (GetAuthURLResponse)`
  - `ExchangeAuthCode(ExchangeAuthCodeRequest) returns (ExchangeAuthCodeResponse)`
- **`UserService`**:
  - `UploadHistoryCSV(UploadHistoryCSVRequest) returns (UploadHistoryCSVResponse)`
  - `SyncUserHistory(SyncUserHistoryRequest) returns (SyncUserHistoryResponse)`
  - `GetSyncStatus(GetSyncStatusRequest) returns (GetSyncStatusResponse)`
- **`VenueService`**:
  - `SearchVenues(SearchVenuesRequest) returns (SearchVenuesResponse)`
  - `GetVenueBeers(GetVenueBeersRequest) returns (GetVenueBeersResponse)`
  - `RefreshVenueBeers(RefreshVenueBeersRequest) returns (RefreshVenueBeersResponse)`
- Core domain messages: `Venue`, `Beer`, `VenueBeerRecommendation` (including `global_rating`, `user_rating`, `blended_score`, `has_had`, `checkin_count_at_venue`), `SyncStatus`.
- Code generation setup (`buf.yaml`, `buf.gen.yaml` or `Makefile`) outputting Go stubs into `backend/gen/` and Dart stubs into `mobile/lib/gen/`.

### 2.2 PostgreSQL Schema & Migrations (`backend/db/migrations/`)
Implement automated schema migrations (e.g., via `golang-migrate` or embedded SQL migrations executed on startup) creating:
- `users` (`untappd_uid` PK, `username`, `access_token`, `last_sync_at`, `created_at`)
- `beers` (`bid` PK, `name`, `brewery_name`, `style`, `abv`, `ibu`, `label_url`, `global_rating`, `updated_at`)
- `user_beers` (`untappd_uid` FK, `bid` FK, `user_rating`, `checkin_count`, `first_had_at`, `last_had_at`, PK `(untappd_uid, bid)`)
- `venues` (`venue_id` PK, `name`, `address`, `lat`, `lng`, `last_fetched_at`)
- `venue_beers` (`venue_id` FK, `bid` FK, `last_seen_checkin_id`, `last_seen_at`, `checkin_count_at_venue`, PK `(venue_id, bid)`)
- Appropriate indexes for geospatial/venue lookup and user beer joins.

### 2.3 Go Backend Scaffold & Repository Layer (`backend/`)
- Go module initialization (`backend/go.mod`), structured packages:
  - `cmd/server/main.go`: Server entrypoint with graceful shutdown, healthcheck endpoint (`/healthz`), and environment configuration.
  - `internal/db/`: Database connection pool (`pgxpool`) and repository methods for CRUD operations across `users`, `beers`, `user_beers`, `venues`, and `venue_beers`.
  - `internal/server/`: gRPC / Connect-RPC handler registrations wired to the repository layer.

### 2.4 Deployment Configuration (`deploy/`)
- Multi-stage `Dockerfile` building a minimal static Go binary.
- Kubernetes manifests (`deploy/deployment.yaml`, `deploy/service.yaml`) configured for `brotherlogic/prod` and wired to the cluster's PostgreSQL orchestrator credentials.

---

## 3. Realistic Integration Test Requirements

Backend elements in Phase 1 are **not** complete until verified by realistic integration tests against a live PostgreSQL instance (via `testcontainers-go` or an ephemeral local Postgres test instance—never mocked SQL drivers):

1. **Migration Idempotency & Schema Integrity Test**:
   - Applies all up/down/up migrations against a fresh PostgreSQL instance.
   - Verifies foreign keys, composite primary keys (`user_beers`, `venue_beers`), and conflict upsert behavior (`ON CONFLICT DO UPDATE`).
2. **Repository Persistence Integration Test**:
   - Exercises real SQL queries for inserting/updating users, bulk-upserting beers and `user_beers`, and associating `venue_beers` with venues.
   - Verifies that re-upserting an existing beer or venue beer updates metadata and timestamps without duplicating rows.
3. **End-to-End gRPC / Connect-RPC Wire Test**:
   - Boots the Go server on an ephemeral loopback port backed by the test PostgreSQL instance.
   - Connects using a generated gRPC / Connect-RPC client stub and verifies health checks, request validation, and structured gRPC error codes (`Unauthenticated`, `InvalidArgument`, `NotFound`).

---

## 4. Testable Exit Criteria

- [ ] `buf lint` (or `protoc`) succeeds with zero warnings and generates deterministic Go (`backend/gen/`) and Dart (`mobile/lib/gen/`) stubs.
- [ ] `go build ./...` in `backend/` compiles cleanly with zero errors.
- [ ] `go test -v -race ./...` in `backend/` passes all database migration, repository persistence, and live gRPC/Connect-RPC wire integration tests against a real PostgreSQL instance.
- [ ] `docker build -f deploy/Dockerfile .` succeeds and produces a runnable container image.
