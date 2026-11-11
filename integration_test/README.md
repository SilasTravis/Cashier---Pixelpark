# Birthday-sale end-to-end tests

Drive the real cashier app against a **local** maestro_backend (never prod/test
servers: they create sales, bookings and refunds).

Needs on the backend: a branch, a cashier, 3 birthday plans (VIP / O‘rta /
Standart) and customers `+998901234567` (Aziza, 600k real + 300k bonus),
`+998901111111` (bonus only), `+998902222222` (no balance), plus an open shift.

```
flutter test integration_test/birthday_sell_test.dart -d macos \
  --dart-define=API_BASE_URL=http://localhost:4000/api \
  --dart-define=CASHIER_USER=kassir1 --dart-define=CASHIER_PASS=... \
  --dart-define=SHOT_DIR=/tmp/shots
```

`birthday_events_test.dart` (Tadbirlar: payment, +child, comment, date,
cancel, complete) uses the same flags. `birthday_resilience_test.dart` kills
and restarts the backend to check the "no answer → retry" path; it also needs
`--dart-define=BACKEND_DIR=<backend checkout>`.

Screenshots are written to disk, so on macOS the debug build needs the app
sandbox off locally (`macos/Runner/DebugProfile.entitlements`); don't commit that.
