# Runova Diary - User Guide

## What is Runova Diary?

Runova Diary is a mobile app for shop owners who offer AEPS (Aadhaar-enabled Payment System) and PhonePe cash-in/cash-out services. It helps you track every transaction, manage multiple bank accounts, calculate commissions automatically, and keep daily balance records.

---

## Features

### 1. Dashboard
The main screen shows:
- **Today's Summary**: Number of AEPS, Cash In, and Cash Out transactions with total amounts
- **Today's Commission**: Total commission earned today (excludes self-transfer settlement charges)
- **Current Balances**: Opening and closing balances for AEPS and each PhonePe account
- **Quick Actions**: Buttons to quickly start a new AEPS, Cash In, or Cash Out transaction

### 2. Transactions

#### AEPS Transaction
- Record Aadhaar-enabled payment system transactions
- Enter customer name, Aadhaar number, bank name, amount
- Commission is calculated automatically based on AEPS commission settings
- Distributor commission is also tracked

#### Cash In / Cash Out (PhonePe)
- Select which PhonePe account the transaction belongs to
- Enter customer name, amount, bank name
- Commission is calculated based on per-account commission settings (flat rate or range-based)
- You can override the commission manually if needed

#### Self Transfer
- Move money between AEPS and PhonePe accounts
- Settlement charges apply when transferring from AEPS
- Choose NEFT or IMPS settlement type

#### Balance Adjustment
- Manually increase or decrease any account balance
- Useful for corrections or external deposits/withdrawals

### 3. Commission Settings

#### Per-Account Commission
Each PhonePe account has its own commission settings:
- **Flat Rate**: Set a fixed commission per ₹1,000 (e.g., ₹10 per ₹1,000)
- **Range-based**: Set different rates for different amount ranges (e.g., ₹5 for ₹0-₹5,000, ₹10 for ₹5,000+)
- **Settlement Charge**: Flat fee for AEPS settlement transfers

#### AEPS Commission
- Set commission rates for AEPS transactions
- Configure distributor commission sharing

### 4. Reports
- View transaction history with date range filters (Today, Yesterday, Custom)
- Filter by transaction type
- See total cash-in, cash-out, and commission earned
- Commission report excludes self-transfer settlement charges

### 5. Bank Accounts
- Add up to 5 PhonePe bank accounts
- Each account has its own balance tracking and commission settings
- Accounts: Hasibul, Runa Laila (default), plus up to 3 custom accounts

### 6. AI-Powered Form Filling
- Uses Sarvam AI API to extract transaction details from images
- Auto-fills customer name, amount, mobile number, transaction ID, and Aadhaar number
- AI auto-enables when an API key is saved
- Tap the AI button (sparkle icon) on any New Transaction screen to use

### 7. Data Sync
- All data is stored locally using Hive
- Automatically syncs to Firebase when online
- Manual sync option in Settings
- Works offline - changes are saved locally and synced later

### 8. Security
- PIN-protected access (4-6 digits)
- Change PIN from Settings
- All data is stored locally and synced securely

---

## Daily Workflow

### Morning
1. Open the app and enter your PIN
2. Dashboard shows today's summary and current balances
3. Verify opening balances are correct (they carry forward from yesterday's closing)

### During the Day
1. **AEPS Transaction**: Tap "New AEPS" → Enter customer name, Aadhaar, bank, amount → Save
2. **Cash In**: Tap "Cash In" → Select account → Enter customer name, bank, amount → Save
3. **Cash Out**: Tap "Cash Out" → Select account → Enter customer name, bank, amount → Save
4. **Self Transfer**: Go to Settings → Self Transfer → Move money between accounts

### End of Day
1. Check today's commission on the dashboard
2. View reports in the Reports section
3. Verify all balances are correct
4. If needed, use Balance Adjustment to correct any discrepancies

### Commission Settings
- Go to Settings → Commission Settings
- Tap any account to customize its commission
- Set flat rate (e.g., ₹10 per ₹1,000) or add range-based rates
- Set AEPS commission and distributor commission separately
- Settlement charge is a flat fee for AESE transfers (not counted as commission income)

---

## Account Types

### AEPS
- Main account for Aadhaar-enabled transactions
- Opening/closing balance tracked daily
- Settlement charges apply when transferring out

### PhonePe Accounts
- Each account (Hasibul, Runa Laila, etc.) has its own balance
- Each account has independent commission settings
- Cash In increases balance, Cash Out decreases balance

### Custom Accounts
- You can add up to 5 PhonePe accounts
- Each has its own opening/closing balance tracking
- Each has independent commission configuration

---

## Commission Calculation

### Flat Rate
- Set a fixed amount per ₹1,000 (e.g., ₹10 per ₹1,000)
- Commission = (amount / 1000) × rate
- Example: ₹5,000 at ₹10/₹1,000 = ₹50

### Range-based
- Define amount ranges with different rates
- Example: ₹0-₹5,000 at ₹5/₹1,000, ₹5,000+ at ₹10/₹1,000
- The system automatically detects the correct range

### AEPS Commission
- Separate commission settings for AEPS transactions
- Distributor commission can be configured separately

### Settlement Charge
- Flat fee for AEPS-to-bank transfers
- This is an expense, NOT counted as commission income
- Not shown in commission reports

---

## Troubleshooting

### Balance doesn't match
- Go to Settings → Add Balance or Decrease Balance to correct
- The system recalculates balances automatically when transactions are added

### Commission seems wrong
- Go to Settings → Commission Settings
- Check the flat rate and range settings for the account
- Make sure the correct account is selected for the transaction

### AI not working
- Go to Settings → AI Settings
- Enter a valid Sarvam AI API key
- AI auto-enables when a key is saved
- Make sure you have an internet connection
- Try uploading a clearer image

### Data not syncing
- Go to Settings → Sync Now to manually sync
- Check internet connection
- Data is always saved locally first, so no data is lost

---

## Technical Notes

- All data is stored locally on your device using Hive
- Firebase is used for cloud backup and sync across devices
- Balances are calculated per day with opening and closing values
- Each day's opening balance is carried forward from the previous day's closing
- Commission settings are per-account and can include flat rates and range-based rates
- Settlement charges are expenses, not commission income
