# Phase 4: Flutter Mobile Application (`mobile/`)

## 1. Objective

Build the cross-platform Flutter mobile client (`mobile/`) communicating with the Go backend over gRPC / Connect-RPC, providing Untappd OAuth login, GPS/search venue discovery, CSV check-in history upload, and the two-tab venue beer selector (**Discover New** and **Rated Blend**).

---

## 2. Deliverables & Scope

### 2.1 Flutter Project & gRPC / Connect-RPC Client Layer (`mobile/lib/`)
- Initialize Flutter app in `mobile/` wired to generated Protobuf/gRPC stubs (`mobile/lib/gen/`).
- Secure local token storage (e.g., `flutter_secure_storage`) persisting the BSR session token across app restarts.
- Typed repository/client wrapper handling auth headers, connection errors, and loading states.

### 2.2 Authentication & Profile Sync Screen
- **Sign in with Untappd**: Launches the OAuth URL returned by `AuthService.GetAuthURL` and handles the deep-link/redirect callback to `ExchangeAuthCode`.
- **History Management Drawer / Settings**:
  - Displays current sync status (`GetSyncStatus`: total distinct beers synced, last sync timestamp, remaining API quota).
  - **Upload CSV Button**: Uses native file picker (`file_picker`) to select an Untappd CSV export and sends it to `UserService.UploadHistoryCSV`.
  - **Sync via API Button**: Triggers `UserService.SyncUserHistory` for users without a CSV export.

### 2.3 Venue Finder Screen
- Requests device location permissions (`geolocator`) on startup and automatically queries `VenueService.SearchVenues(lat, lng)`.
- Provides a search bar for manual venue name queries.
- Displays matching venues with distance/address and navigates to the Venue Beer Selector screen on tap.

### 2.4 Venue Beer Selector Screen (Two-Tab Ranking View)
- Calls `VenueService.GetVenueBeers(venue_id)` and displays a two-tab view:
  1. **Discover New Tab**:
     - Displays only beers the user has **not** had (`has_had == false`), ordered by `global_rating` descending.
     - Shows beer name, brewery, style, ABV, and Untappd Global Score badge.
  2. **Rated Blend Tab**:
     - Displays all venue beers ordered by `blended_score` descending.
     - Clearly badges beers the user has already had (`has_had == true`) with both their **Blended Score**, **Personal Rating**, and **Global Score**.
- Pull-to-refresh gesture invoking `VenueService.RefreshVenueBeers(venue_id)` when the user wants to top up the cached venue menu.

---

## 3. Realistic Integration & Widget Test Requirements

All Flutter screens and state transitions must be verified by automated integration and widget tests (`flutter test`) running against a realistic mock/in-memory gRPC server implementation (not disconnected UI snapshots):

1. **Auth & Onboarding Flow Test**:
   - Verifies that an unauthenticated launch renders the Untappd Sign-In screen, completes token exchange against a test `AuthService`, persists the session token, and transitions to the Venue Finder screen.
2. **GPS & Search Venue Discovery Test**:
   - Simulates a GPS fix (`lat`, `lng`) and verifies that `SearchVenues` is invoked with those coordinates and renders the returned venue cards.
   - Simulates typing a brewery name into the search field and verifies the updated venue list.
3. **Discover New vs. Rated Blend Tab Switching & Ordering Test**:
   - Seeds the test `VenueService` with a realistic mix of tried-loved, tried-disliked, and untried beers.
   - Asserts that the **Discover New** tab renders strictly the untried beers in descending `global_rating` order and hides tried beers.
   - Switches to the **Rated Blend** tab and asserts that all beers appear in exact `blended_score` (60/40) order, with tried beers displaying the user's personal rating badge.
4. **CSV Upload & Sync Status Test**:
   - Simulates picking a realistic CSV file in the Profile/Sync view, verifies the `UploadHistoryCSV` RPC payload, and checks that the updated beer count renders in the UI.

---

## 4. Testable Exit Criteria

- [ ] `flutter analyze` in `mobile/` passes with zero errors or warnings.
- [ ] `flutter test` passes all widget and end-to-end integration tests covering Auth, GPS/Search Venue Discovery, CSV Upload, and Discover New / Rated Blend tab sorting.
- [ ] Full-stack smoke test: Running the Flutter client against the containerized Go + PostgreSQL backend completes OAuth login, CSV upload, venue search, and beer ranking end-to-end.
