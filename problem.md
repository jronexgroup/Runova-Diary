# Pending Problems

## 1. Balance sync race condition (HIGH)

**Reported:** 2026-09-30 — AEPS opening balance showed 0.11 on old install; after delete + reinstall it became 86.14 (the correct synced value).

### Root cause

1. **Splash doesn't await sync** — `lib/screens/splash_screen.dart:46` fires `syncFromFirebase()` **without `await`**, then immediately navigates to dashboard.
2. **Dashboard creates today's balance too early** — `lib/screens/dashboard_screen.dart:33` runs `ensureBalance(today)` while Firebase data is still downloading.
3. **`ensureBalance` falls back to 0** — `lib/providers/providers.dart:264`: if yesterday's balance record isn't in local Hive yet, it uses `aepsOpening = 0` instead of the real closing balance → creates today's record with opening **0** → and **pushes this wrong balance to Firebase**.
4. **Offline/reconnect never pulls** — the connectivity listener (`lib/services/sync_service.dart:22-25`) only **pushes** local → Firebase on reconnect, never pulls → a wrong local balance gets uploaded and never corrected.

Result: old install showed wrong local value (~0.11); fresh install pulled real Firebase value (86.14).

### Planned fixes (app code only, no manual data changes)

1. **Await sync before loading data**
   - `splash_screen.dart`: `await syncFromFirebase()` before loading providers / navigating
   - `dashboard_screen.dart._loadData`: await sync → reload balances → then `_ensureTodayBalance`

2. **Fix `ensureBalance` fallback** (`lib/providers/providers.dart:249-273`)
   - If yesterday's balance is missing locally, **fetch it from Firebase** (`firebaseService.getBalance(userId, yesterdayKey)`) and save locally
   - Only fall back to `0` if Firebase also has no yesterday doc (true first day)

3. **Fix offline race** (`lib/services/sync_service.dart:22-25`)
   - On connectivity restored: **pull first** (`syncFromFirebase`), then push
   - Re-run today's `ensureBalance`/`recalculateBalance` after pull completes

4. **Guard `syncToFirebase`**
   - Skip pushing balances until a pull has completed at least once this session (prevents offline-first overwrite of server truth)

**Note:** `updateOpeningBalances` has no UI yet (`openingBalancesEditable` flag exists but no screen calls it), so enforcing "today's opening = yesterday's closing" won't override any manual edits.

### Verification after fixes
- `dart analyze` → 0 errors
- Backup DB (`backup/backup_firebase.py`)
- Wait for explicit "push" instruction before committing
