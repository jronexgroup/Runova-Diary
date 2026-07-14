# Runova-Diary — Full Project Context

## Overview

Runova-Diary is a Flutter mobile app (Android-first) that replaces the traditional paper diary for shop owners offering AEPS (Aadhaar-enabled Payment System) and PhonePe cash-in/cash-out services in India. It records transactions, auto-calculates commissions, maintains daily balances across multiple accounts, works offline-first, syncs to Firebase, and uses Sarvam AI to auto-fill forms from receipt images.

**Version:** 1.0.0+1 | **SDK:** Dart ^3.6.2 | **State Management:** Riverpod | **Local DB:** Hive | **Cloud:** Firebase Firestore

---

## Architecture

### Data Flow
```
User Input → Screen → Provider (StateNotifier) → HiveService (local) → SyncService → FirebaseService (cloud)
                                                      ↕
                                              Offline-first: Hive primary, Firebase backup
```

### AI Flow
```
Image → Sarvam OCR (doc-digitization) → Raw Text → Sarvam LLM (sarvam-105b) → JSON Fields → Form Population
```

---

## Directory Structure

```
lib/
├── main.dart                    # Entry point, Firebase init, Hive init, providers
├── app.dart                     # MaterialApp.router
├── firebase_options.dart        # Firebase config
├── models/                      # 6 data models
│   ├── ai_settings.dart
│   ├── bank_account.dart
│   ├── commission_config.dart
│   ├── daily_balance.dart
│   ├── transaction.dart
│   └── user.dart
├── providers/
│   └── providers.dart           # All Riverpod providers (single file)
├── router/
│   └── app_router.dart          # GoRouter with 19 routes
├── screens/                     # 21 screens
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── dashboard_screen.dart
│   ├── new_transaction_screen.dart
│   ├── transaction_history_screen.dart
│   ├── edit_transaction_screen.dart
│   ├── transaction_detail_screen.dart
│   ├── reports_screen.dart
│   ├── settings_screen.dart
│   ├── share_handler_screen.dart
│   ├── bank_accounts_screen.dart
│   ├── commission_settings_screen.dart
│   ├── aeps_commission_screen.dart
│   ├── distributor_commission_screen.dart
│   ├── settlement_charge_screen.dart
│   ├── account_commission_screen.dart
│   ├── ai_settings_screen.dart
│   ├── change_pin_screen.dart
│   ├── adjust_balance_screen.dart
│   └── self_transfer_screen.dart
├── services/
│   ├── ai_service.dart
│   ├── auth_service.dart
│   ├── commission_service.dart
│   ├── firebase_service.dart
│   ├── hive_service.dart
│   └── sync_service.dart
├── theme/
│   └── app_theme.dart
├── utils/
│   ├── constants.dart
│   └── date_utils.dart
└── widgets/
    ├── balance_card.dart
    ├── quick_action_button.dart
    └── summary_card.dart
```

---

## Transaction Types

| Type | Enum Value | Description | Commission | Balance Effect |
|------|-----------|-------------|-----------|---------------|
| AEPS | `TransactionType.aeps` | Aadhaar-enabled cash withdrawal | Per-thousand + distributor | `aepsClosing += amount + distributorCommission` |
| Cash In | `TransactionType.cashIn` | Customer gives cash, we PhonePe them | Per-thousand or range flat | `accountBalance += amount` |
| Cash Out | `TransactionType.cashOut` | Customer PhonePe us, we give cash | Per-thousand or range flat | `accountBalance -= amount` |
| Balance Adjustment | `TransactionType.balanceAdjustment` | Manual balance correction | None | `accountBalance += amount` |
| Self Transfer | `TransactionType.selfTransfer` | Move between AEPS and PhonePe | Settlement charge | `from -= (amount + commission)`, `to += amount` |

---

## Commission Calculation

### Per-Thousand Rate
```
commission = ceil(amount / 1000) * perThousandRate
```
Example: 2500 at 10/1000 = ceil(2.5) * 10 = 30

### Range-Based (Flat Fee)
```
For each range [min, max] with rate:
  if amount >= min && amount <= max:
    commission = rate (flat fee, NOT per-thousand)
```
Example: range 1100-1500 at rate 15 → amount 1400 → commission = 15

### Distributor Commission
- 8 ranges: 200-499 (0.5), 500-999 (1), 1000-1999 (2), 2000-2999 (3), 3000-3999 (4), 4000-5999 (5), 6000-7999 (7), 8000-10000 (10)

### Settlement Charge
- 3 ranges: 0-25000 (5), 25001-50000 (10), 50001-200000 (10)

---

## Transaction Types

| Type | Enum | Commission | Balance Effect |
|------|------|-----------|---------------|
| AEPS | `aeps` | Per-thousand + distributor | `aepsClosing += amount + distributorCommission` |
| Cash In | `cashIn` | Per-thousand or range flat | `accountBalance += amount` |
| Cash Out | `cashOut` | Per-thousand or range flat | `accountBalance -= amount` |
| Balance Adjustment | `balanceAdjustment` | None | `accountBalance += amount` |
| Self Transfer | `selfTransfer` | Settlement charge | `from -= (amount + commission)`, `to += amount` |

---

## Commission Calculation

### Per-Thousand Rate
```
commission = ceil(amount / 1000) * perThousandRate
```
Example: 2500 at 10/1000 = ceil(2.5) * 10 = 30

### Range-Based (Flat Fee)
Ranges are flat fees, NOT per-thousand. Example: range 1100-1500 at rate 15 → amount 1400 → commission = 15.

### Distributor Commission (AEPS)
8 ranges: 200-499 (0.5), 500-999 (1), 1000-1999 (2), 2000-2999 (3), 3000-3999 (4), 4000-5999 (5), 6000-7999 (7), 8000-10000 (10)

### Settlement Charge
3 ranges: 0-25000 (5), 25001-50000 (10), 50001-200000 (10)

---

## Transaction Types

| Type | Enum | Commission | Balance Effect |
|------|------|-----------|---------------|
| AEPS | `aeps` | Per-thousand + distributor | `aepsClosing += amount + distributorCommission` |
| Cash In | `cashIn` | Per-thousand or range flat | `accountBalance += amount` |
| Cash Out | `cashOut` | Per-thousand or range flat | `accountBalance -= amount` |
| Balance Adjustment | `balanceAdjustment` | None | `accountBalance += amount` |
| Self Transfer | `selfTransfer` | Settlement charge | `from -= (amount + commission)`, `to += amount` |

---

## Models

### AppUser
`id`, `phoneNumber`, `shopName`, `ownerName`, `pinHash` (SHA-256), `createdAt`

### Transaction
`id`, `type` (TransactionType enum), `customerName`, `amount`, `commission`, `distributorCommission`, `commissionOverridden`, `mobileNumber?`, `aadhaarNumber?`, `transactionId?`, `notes?`, `bankName?`, `balanceAfterTransaction`, `createdAt`, `userId`, `account?`, `fromAccount?`, `toAccount?`

### DailyBalance
`id`, `dateKey` (yyyy-MM-dd), `userId`, `aepsOpeningBalance`, `aepsClosingBalance`, `hasibulOpeningBalance`, `hasibulClosingBalance`, `runaLailaOpeningBalance`, `runaLailaClosingBalance`, `customOpeningBalances` (Map), `customClosingBalances` (Map), `openingBalancesEditable`

### BankAccount
`id`, `name`, `holderName`, `bankName`, `upiId?`, `accountNumber?`, `lastFourDigits?`, `isActive`
- Max 5 accounts. Special IDs: `hasibul`, `runaLaila` (defaults)

### CommissionConfig
`cashInPerThousand` (default 10), `cashOutPerThousand` (default 10), `settlementCharge` (default 5), `cashInRanges` (List<CommissionRange>), `cashOutRanges` (List<CommissionRange>)

### CommissionRange
`min` (int), `max` (int), `rate` (double) — **flat fee**, NOT per-thousand

### AepsCommissionConfig
`cashWithdrawalPerThousand` (10), `balanceEnquiry` (0), `miniStatement` (0), `aadhaarPayPerThousand` (0)

### DistributorRange
`min`, `max`, `commission` — 8 ranges: 200-499 (0.5) up to 8000-10000 (10)

### SettlementRange
`min`, `max`, `charge` — 3 ranges: 0-25000 (5), 25001-50000 (10), 50001-200000 (10)

### AiSettings
`apiKey` (String), `enabled` (bool)

### AppUser
`id`, `phoneNumber`, `shopName`, `ownerName`, `pinHash` (SHA-256), `createdAt`

---

## Screens (21)

| Screen | Route | Purpose |
|--------|-------|---------|
| SplashScreen | `/splash` | Animated logo, auto-navigates to dashboard or login |
| LoginScreen | `/login` | Phone + PIN login |
| RegisterScreen | `/register` | Registration with optional AI API key |
| DashboardScreen | `/dashboard` | Today's summary, balance cards, quick actions |
| NewTransactionScreen | `/new-transaction/:type` | Universal form for AEPS/CashIn/CashOut with AI auto-fill |
| TransactionHistoryScreen | `/history` | Searchable/filterable list with multi-select delete |
| EditTransactionScreen | `/edit-transaction/:id` | Edit with AI button |
| TransactionDetailScreen | `/transaction-detail/:id` | Read-only detail view |
| ReportsScreen | `/reports` | Date-range filtered totals and commissions |
| SettingsScreen | `/settings` | Profile, PIN, sync, accounts, commissions, AI |
| ShareHandlerScreen | `/share-handler` | Receives shared images, picks type, runs AI |
| BankAccountsScreen | `/bank-accounts` | CRUD for up to 5 accounts |
| CommissionSettingsScreen | `/commission-settings` | Menu for all commission configs |
| AepsCommissionScreen | `/commission-settings/aeps` | AEPS rates |
| DistributorCommissionScreen | `/commission-settings/distributor` | Distributor ranges |
| SettlementChargeScreen | `/commission-settings/settlement` | Settlement ranges |
| AccountCommissionScreen | `/commission-settings/account/:id` | Per-account rates + ranges |
| AiSettingsScreen | `/ai-settings` | Toggle + API key |
| ChangePinScreen | `/change-pin` | Old PIN → new PIN |
| AdjustBalanceScreen | `/adjust-balance/:isAdd` | Manual balance adjustment |
| SelfTransferScreen | `/self-transfer` | Transfer between accounts |

---

## Services

### HiveService
Local offline-first storage. Boxes: `transactions`, `balances`, `user`, `settings`. Keys use `{userId}_` prefix.

### FirebaseService
Cloud Firestore CRUD. Collections: `users/{userId}/transactions/`, `users/{userId}/daily_balances/`, `users/{userId}/settings/`. All methods catch errors gracefully.

### AuthService
Registration (phone + SHA-256 PIN), login, PIN verification, PIN change. Stores user in Hive, syncs to Firebase.

### CommissionService
- `calculateCommission(amount, type, ...)` — checks range matches first (flat fee), falls back to per-thousand
- `getDistributorCommission(amount)` — matches distributor ranges
- `getSettlementCharge(amount)` — matches settlement ranges
- `smartDetect(total, ...)` — deduces base amount + commission from total

### AiService
Two-step Sarvam AI pipeline:
1. **OCR**: `_runOcr()` — doc-digitization job (create → upload → start → poll → download → parse ZIP)
2. **LLM Extraction**: `_extractWithLLM()` — sends OCR text to `sarvam-105b` chat completions, returns JSON with `customerName`, `amount`, `mobileNumber`, `transactionId`, `lastFourDigits`, `aadhaarNumber`
3. **Account Matching**: `matchAccountId()` — matches `lastFourDigits` to known bank accounts

### SyncService
Offline-first sync: pushes local Hive data to Firebase when online, pulls Firebase data on login/register. Uses `connectivity_plus` to detect online status.

---

## Key Business Logic

### Commission Calculation
- **Range rates are flat fees**: range 1100-1500 at rate 15 → amount 1400 → commission = 15
- **Per-thousand rates**: `ceil(amount / 1000) * rate`
- **Distributor commission**: flat fee per amount range
- **Settlement charge**: flat fee per amount range

### Balance Recalculation
Each transaction type affects specific account balances:
- AEPS: `aepsClosing += amount + distributorCommission`
- CashIn: `accountBalance += amount`
- CashOut: `accountBalance -= amount`
- BalanceAdjustment: `accountBalance += amount`
- SelfTransfer: `fromAccount -= (amount + commission)`, `toAccount += amount`

### Daily Balance
- Opening balance = yesterday's closing balance (auto-copied)
- Closing balance = opening + all day's transactions
- Opening balances can be manually edited (until `openingBalancesEditable` is set to false)

---

## AI Integration

**Provider:** Sarvam AI | **Base URL:** `https://api.sarvam.ai` | **Auth:** `api-subscription-key` header

### OCR Flow (doc-digitization)
1. `POST /doc-digitization/job/v1` → get job_id
2. `POST /doc-digitization/job/v1/upload-files` → get Azure blob URL
3. `PUT {azure_url}` → upload image as `document.jpg`
4. `POST /doc-digitization/job/v1/{jobId}/start`
5. `GET /doc-digitization/job/v1/{jobId}/status` — poll every 2-5s, up to 30 tries
6. `POST /doc-digitization/job/v1/{jobId}/download-files` → get download URL
7. Download ZIP, parse markdown text from it

### LLM Extraction
- **Model:** `sarvam-105b` (via `/v1/chat/completions`)
- **Prompt:** Extract `customerName`, `amount`, `mobileNumber`, `transactionId`, `lastFourDigits`, `aadhaarNumber` as JSON
- **Post-processing:** Strip ₹/commas from amount, extract last 4 digits from masked strings

### Account Matching
`matchAccountId(fields, accounts)` — matches extracted `lastFourDigits` against `BankAccount.lastFourDigits`

### API Key (test)
`sk_f9xingij_yhFq7DU468sOK0f5y61TSTUJ`

---

## Share Handler Flow

1. App registered as share target for images via `receive_sharing_intent`
2. `ShareHandlerScreen` opens when image shared from another app
3. User picks transaction type (Cash In / Cash Out / AEPS)
4. AI processes image → extracts fields
5. Navigates to `NewTransactionScreen` with pre-filled fields and auto-selected account

---

## Known Issues

1. **`bank_accounts_screen.dart:147`** — References `acctCtrl` (account number controller) which is never declared. Would crash if add/edit account dialog is opened.
2. **Firebase Security Rules** use `request.auth.uid` but app does NOT use Firebase Auth (uses custom PIN auth). Cloud sync would fail silently.
3. **AI mobileNumber extraction** sometimes returns UPI IDs (e.g., `Q731799696@ybl`) instead of phone numbers — this is a Sarvam LLM limitation.

---

## API Key (Test)
`sk_f9xingij_yhFq7DU468sOK0f5y61TSTUJ`

---

## Routes (GoRouter)

| Path | Screen | Auth Required |
|------|--------|---------------|
| `/splash` | SplashScreen | No |
| `/login` | LoginScreen | No |
| `/register` | RegisterScreen | No |
| `/dashboard` | DashboardScreen | Yes |
| `/new-transaction/:type` | NewTransactionScreen | Yes |
| `/history` | TransactionHistoryScreen | Yes |
| `/edit-transaction/:id` | EditTransactionScreen | Yes |
| `/transaction-detail/:id` | TransactionDetailScreen | Yes |
| `/reports` | ReportsScreen | Yes |
| `/settings` | SettingsScreen | Yes |
| `/share-handler` | ShareHandlerScreen | Yes |
| `/bank-accounts` | BankAccountsScreen | Yes |
| `/commission-settings` | CommissionSettingsScreen | Yes |
| `/commission-settings/aeps` | AepsCommissionScreen | Yes |
| `/commission-settings/distributor` | DistributorCommissionScreen | Yes |
| `/commission-settings/settlement` | SettlementChargeScreen | Yes |
| `/commission-settings/account/:id` | AccountCommissionScreen | Yes |
| `/ai-settings` | AiSettingsScreen | Yes |
| `/change-pin` | ChangePinScreen | Yes |
| `/adjust-balance/:isAdd` | AdjustBalanceScreen | Yes |
| `/self-transfer` | SelfTransferScreen | Yes |

---

## Known Issues

1. **`bank_accounts_screen.dart:147`** — References `acctCtrl` (account number controller) which is never declared. Would crash if add/edit account dialog is opened.
2. **Firebase Security Rules** use `request.auth.uid` but app does NOT use Firebase Auth (uses custom PIN auth). Cloud sync would fail silently.
3. **AI mobileNumber extraction** sometimes returns UPI IDs (e.g., `Q731799696@ybl`) instead of phone numbers — Sarvam LLM limitation.

---

## Dependencies (pubspec.yaml)

- `flutter_riverpod` — State management
- `go_router` — Navigation
- `hive` + `hive_flutter` — Local storage
- `firebase_core` + `cloud_firestore` — Cloud database
- `http` — API calls
- `image_picker` — Image selection
- `receive_sharing_intent` — Android share target
- `connectivity_plus` — Network status
- `crypto` — SHA-256 PIN hashing
- `uuid` — ID generation
- `intl` — Date formatting
