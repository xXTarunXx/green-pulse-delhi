# Auth + User Identity Implementation Status

## Goal

Replace the prototype `demo_user` identity with a real Firebase Auth user ID, automatically create a Firestore user profile, and make trails, walk rewards, safety reports, and buddy matching belong to the signed-in user.

Current status: locally implemented and verified. Final Firebase/device validation is still required.

## Completed Phases

### Phase 1: Add `AuthService`

Status: Completed.

Implemented `lib/services/auth_service.dart`.

What it does:

- Wraps `FirebaseAuth.instance`.
- Listens to `authStateChanges()`.
- Signs in anonymously when no Firebase user exists.
- Exposes `currentUser`, `uid`, `isReady`, `isAnonymous`, `lastError`, and `displayName`.
- Uses `Citizen Scientist` as the fallback display name.
- Cleans up its auth subscription in `dispose()`.

### Phase 2: Wire Auth Into App Startup

Status: Completed.

Updated `lib/main.dart`.

What changed:

- Creates `AuthService` after Firebase initialization.
- Calls `authService.ensureSignedIn()` before `runApp`.
- Provides `AuthService` through `ChangeNotifierProvider`.
- Keeps app launch resilient if anonymous sign-in fails.

### Phase 3: Make User Profile Creation Non-Destructive

Status: Completed.

Updated `lib/services/firestore_service.dart`.

What changed:

- `createOrUpdateUser(...)` now uses a transaction.
- New users get default stats:
  - `totalPoints: 0`
  - `totalDistanceKm: 0.0`
  - `trailsCompleted: 0`
  - `createdAt`
- Existing users only get metadata updates:
  - `displayName`
  - `email`
  - `isAnonymous`
  - `lastSeenAt`
- Existing totals are no longer reset on app start.

Also updated `lib/main.dart` so startup safely creates or updates the current user's Firestore profile after anonymous sign-in.

### Phase 4: Replace `demo_user`

Status: Completed.

Updated `lib/screens/home_map_screen.dart`.

What changed:

- Added `AuthService` usage.
- Added `_requireUserId()` to guard user-owned actions.
- Trail creation now saves with the Firebase UID.
- Walk completion now increments points, distance, and completion count for the Firebase UID.
- Safety reviews now save with the Firebase UID.
- Buddy Walk now uses the Firebase UID and `authService.displayName`.
- Verified there are no remaining `demo_user` references in `lib`.

### Phase 5: Add a Readiness Guard

Status: Completed.

Updated `lib/main.dart`.

What changed:

- Added `AuthGate`.
- Shows a small loading state while auth is not ready.
- Shows `MainNavigator` only when a Firebase UID exists.
- Shows a retry screen if anonymous sign-in fails.
- Retry flow attempts anonymous sign-in again and safely creates/updates the Firestore user profile.

Also updated `GreenPulseApp` with a `homeOverride` for tests and adjusted `test/widget_test.dart` so the smoke test does not require live Firebase/Auth providers.

### Phase 6: Firestore Rules Alignment

Status: Completed locally. Deployment still pending.

Added:

- `firebase.json`
- `firestore.rules`
- `firestore.indexes.json`

Rules now enforce:

- Users can read/create/update only their own `users/{uid}` document.
- Trails can be created/read/updated only by the owner where `userId == request.auth.uid`.
- Safety reviews can be read by signed-in users and created/updated only by their owner.
- Buddy requests can be read by signed-in users, created/updated by their owner, and matched through a controlled update path.

Note: Firebase CLI was not available locally, so the rules have not yet been validated with Firebase's native rules parser or deployed.

### Phase 7: Local Verification

Status: Completed locally.

Commands run successfully:

```text
dart analyze lib test
flutter test
flutter build apk --debug
```

Results:

- Dart analyzer found no issues.
- Widget test passed.
- Debug Android APK built successfully.
- Android `google-services.json` parsed successfully.
- `firebase.json` and `firestore.indexes.json` parsed successfully.

## Final Verification Still Required

These checks require a real device/emulator and a live Firebase project.

### Firebase Console Setup

1. Confirm Anonymous Authentication is enabled:
   - Firebase Console
   - Authentication
   - Sign-in method
   - Anonymous

2. Deploy Firestore rules after installing Firebase CLI:

```bash
firebase login
firebase use <project-id>
firebase deploy --only firestore:rules
```

3. If needed, deploy indexes:

```bash
firebase deploy --only firestore:indexes
```

### Fresh Install Check

1. Uninstall the app from the test device/emulator.
2. Run a fresh debug build.
3. Open the app.
4. Confirm the app passes the auth gate and reaches the main navigator.
5. In Firebase Console, verify a new anonymous user appears under Authentication.
6. In Firestore, verify a matching document exists:

```text
users/{uid}
```

Expected fields:

- `displayName`
- `email`
- `isAnonymous`
- `lastSeenAt`
- `createdAt`
- `totalPoints`
- `totalDistanceKm`
- `trailsCompleted`

### Non-Destructive Profile Check

1. Note the current `users/{uid}` totals.
2. Close and reopen the app.
3. Confirm `lastSeenAt` updates.
4. Confirm these fields do not reset:

- `totalPoints`
- `totalDistanceKm`
- `trailsCompleted`

### Trail Ownership Check

1. Generate a trail.
2. Start the walk.
3. In Firestore, inspect the new trail document.
4. Confirm:

```text
trails/{trailId}.userId == current Firebase uid
```

### Walk Completion Check

1. Complete a walk.
2. Confirm the trail status updates to `completed`.
3. Confirm the same user's profile increments:

- `totalPoints`
- `totalDistanceKm`
- `trailsCompleted`

### Safety Review Check

1. Long-press the map and submit a safety review.
2. In Firestore, inspect the new review.
3. Confirm:

```text
safety_reviews/{reviewId}.userId == current Firebase uid
```

### Buddy Walk Check

1. Start Buddy Walk on one signed-in device/emulator.
2. Start Buddy Walk on a second signed-in device/emulator nearby.
3. Confirm both users can see/match.
4. In Firestore, verify:

- Each `buddy_requests` document has the correct `userId`.
- Matched requests move to `status: matched`.
- `matchedWith` points to the other user's UID.

### Firestore Rules Check

After rules are deployed:

1. Confirm the app can still create/update its own:
   - user profile
   - trails
   - safety reviews
   - buddy requests

2. Confirm cross-user writes are rejected. For example:
   - User A cannot update User B's `users/{uid}` document.
   - User A cannot create a trail with User B's UID.
   - User A cannot overwrite User B's safety review.

## Next Recommended Work

Once final verification passes, the next practical step is to wire the Impact Dashboard to the authenticated user's Firestore profile instead of static mock data.

