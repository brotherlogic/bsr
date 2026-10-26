# Phase 3: Venue Discovery, Long-Term Caching & Ranking Engine

## 1. Objective

Implement venue search (`/v4/venue/search`), venue beer discovery from recent check-ins (`/v4/venue/checkins/{VENUE_ID}`), the 30-day PostgreSQL caching layer, and the core BSR ranking engine (**Discover New** and **Rated Blend 60/40**).

---

## 2. Deliverables & Scope

### 2.1 Venue Discovery (`VenueService.SearchVenues`)
- Accepts GPS coordinates (`lat`, `lng`, optional radius) and/or a search `query` string.
- Queries Untappd `/v4/venue/search` using the authenticated user's token.
- Upserts discovered venue metadata (`venue_id`, `name`, `address`, `lat`, `lng`) into PostgreSQL `venues` and returns a ranked list of nearby/matching venues.

### 2.2 Venue Check-in Harvester & 30-Day Cache (`VenueService.GetVenueBeers` & `RefreshVenueBeers`)
- **Cache Evaluation**:
  - When `GetVenueBeers(venue_id)` is called, checks `venues.last_fetched_at` in PostgreSQL.
  - **Cache Hit (`age < 30 days`)**: Serves the venue's beer roster directly from `venue_beers` joined with `beers` and `user_beers` in PostgreSQL (**0 Untappd API calls made**).
  - **Cache Miss (`last_fetched_at IS NULL` or `age >= 30 days`)** or explicit **`RefreshVenueBeers`**:
    - Paginates through `/v4/venue/checkins/{VENUE_ID}` using `max_id` pagination for as many pages as the user's current `X-Ratelimit-Remaining` budget permits (while respecting the safety buffer).
    - Extracts unique beers (`bid`, name, brewery, style, ABV, IBU, label, `global_rating`), upserting into `beers` and `venue_beers` (recording `last_seen_checkin_id`, `last_seen_at`, and `checkin_count_at_venue`).
    - Updates `venues.last_fetched_at`.

### 2.3 BSR Ranking & Scoring Engine (`backend/internal/ranking/`)
For a given `(untappd_uid, venue_id)`, computes and returns the venue's beers with exact scoring metadata:
- **`has_had`**: `true` if a matching row exists in `user_beers` for `(untappd_uid, bid)`.
- **Mode 1: Discover New**
  - Filters to beers where `has_had == false`.
  - Sorts descending by `global_rating` (tie-breaking by `checkin_count_at_venue` descending, then `bid`).
- **Mode 2: Rated Blend (60/40)**
  - Includes all beers at the venue on a normalized `0.0–5.0` scale:
    - If `has_had == true` and `user_rating > 0`:
      $$\text{blended\_score} = (0.6 \times \text{user\_rating}) + (0.4 \times \text{global\_rating})$$
    - If `has_had == false` (or unrated check-in with `user_rating == 0`):
      $$\text{blended\_score} = 1.0 \times \text{global\_rating}$$
  - Sorts descending by `blended_score` (tie-breaking by `has_had` descending, then `global_rating` descending).

---

## 3. Realistic Integration Test Requirements

All Phase 3 functionality must be verified via integration tests running against a **real PostgreSQL database** and a **mock Untappd HTTP server (`httptest.Server`)** serving realistic multi-page `/v4/venue/search` and `/v4/venue/checkins` payloads:

1. **Venue Check-in Harvesting & Deduplication Test**:
   - Mock server serves multiple pages of `/v4/venue/checkins/{VENUE_ID}` where several patrons check in the same IPA multiple times alongside distinct stouts and sours.
   - Calls `GetVenueBeers` on an uncached venue over gRPC/Connect-RPC.
   - Asserts that duplicate beer check-ins at the venue are collapsed into single `venue_beers` rows with accurate `checkin_count_at_venue` and `last_seen_at`.
2. **30-Day Cache Hit vs. Expiry Integration Test**:
   - Calls `GetVenueBeers` once (populating the cache) and records the mock Untappd server request count (`N`).
   - Calls `GetVenueBeers` a second time immediately and asserts that the mock Untappd server received **0 additional requests** (`count == N`) while returning identical results.
   - Ages `venues.last_fetched_at` in PostgreSQL to `NOW() - INTERVAL '31 days'`, calls `GetVenueBeers` again, and asserts that the backend re-fetches from the Untappd API and updates `last_fetched_at`.
3. **End-to-End Ranking & Blending Accuracy Test**:
   - Seeds a realistic user history in PostgreSQL:
     - Beer A (Tried & Loved): `user_rating = 4.75`, `global_rating = 4.00` $\rightarrow$ `blended_score = 4.45`
     - Beer B (Untried Whale): `has_had = false`, `global_rating = 4.35` $\rightarrow$ `blended_score = 4.35`
     - Beer C (Tried & Disliked): `user_rating = 2.00`, `global_rating = 4.20` $\rightarrow$ `blended_score = 2.88`
     - Beer D (Untried Average): `has_had = false`, `global_rating = 3.70` $\rightarrow$ `blended_score = 3.70`
   - Calls `GetVenueBeers` over gRPC/Connect-RPC and verifies:
     - **Discover New** returns strictly `[Beer B (4.35), Beer D (3.70)]` and excludes Beers A and C.
     - **Rated Blend** returns all four beers in exact order: `[Beer A (4.45), Beer B (4.35), Beer D (3.70), Beer C (2.88)]`.

---

## 4. Testable Exit Criteria

- [ ] `go test -v -race ./...` in `backend/` passes all venue search, check-in harvesting, 30-day cache hit/expiry, and ranking blend integration tests against real PostgreSQL.
- [ ] Cache hit path for `GetVenueBeers` makes zero outbound HTTP requests to Untappd and responds in `< 50ms` in local integration benchmarks.
- [ ] Ranking tests verify exact floating-point tolerances ($\pm 0.001$) for the 60/40 blend formula across tried-rated, tried-unrated, and untried beers.
