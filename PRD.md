Runova Diary – Product Requirements Document (PRD)

Version: 1.0 (MVP)

---

1. Overview

Runova Diary is a simple, fast, offline-first transaction diary for AEPS and PhonePe cash service businesses.

It replaces the traditional paper diary with a digital ledger while automatically calculating balances, commissions, and daily summaries.

The application is designed for speed and simplicity so that a shopkeeper can record a transaction within 5–10 seconds.

---

2. Goals

- Replace handwritten transaction diary.
- Automatically maintain balances.
- Automatically calculate AEPS commission.
- Work offline.
- Sync automatically with Firebase.
- Make searching previous transactions easy.
- Reduce calculation mistakes.

---

3. Target Users

- AEPS Retailers
- PhonePe Cash Service Shops
- CSP Operators
- Small Financial Service Businesses

---

4. Technology Stack

Frontend

- Flutter
- Material 3
- Android First

Backend

- Firebase

Database

- Cloud Firestore

Local Database

- Hive (Offline Storage)

State Management

- Riverpod

Routing

- GoRouter

Authentication

Custom Authentication

Login using:

- Phone Number
- PIN (4 or 6 digits)

PIN must be securely hashed before storage.

Authentication Flow

Sign Up

- Phone Number
- Shop Name
- Owner Name
- PIN

Login

- Phone Number
- PIN

Firebase verifies credentials and logs the user in.

---

5. App Structure

- Splash Screen
- Login
- Register
- Dashboard
- New Transaction
- Transaction History
- Reports
- Settings

---

6. Dashboard

Shows today's summary.

Cards

AEPS

- Transaction Count
- Total Amount

PhonePe Cash In

- Count
- Total

PhonePe Cash Out

- Count
- Total

Today's Commission

Current Balances

- AEPS Balance
- Hasibul PhonePe Balance
- Runa Laila PhonePe Balance

Quick Actions

- New AEPS
- Cash In
- Cash Out

---

7. Transaction Types

AEPS Transaction

Required

- Customer Name
- Amount
- AEPS Balance After Transaction
- Time

Optional

- Mobile Number
- Transaction ID
- Notes

Commission

Automatically calculated.

Rules

₹1 – ₹1000

Commission = ₹10

₹1001 – ₹2000

Commission = ₹20

₹2001 – ₹3000

Commission = ₹30

Pattern continues.

Formula

Commission = Ceiling(Amount ÷ 1000) × ₹10

User can manually override the commission.

---

PhonePe Cash In

Meaning

Customer sends money via PhonePe.

Shopkeeper gives cash.

Required

- Customer Name
- Bank Name
- Amount
- PhonePe Account
  - Hasibul
  - Runa Laila
- Balance After Transaction
- Time

Optional

- Mobile Number
- Transaction ID
- Notes

---

PhonePe Cash Out

Meaning

Customer gives cash.

Shopkeeper sends money through PhonePe.

Fields are identical to Cash In.

---

8. Balance System

Three independent balances.

AEPS Balance

Hasibul PhonePe Balance

Runa Laila PhonePe Balance

Each transaction updates only its corresponding balance.

---

9. Daily Balance Logic

At midnight

Today's Closing Balance

↓

Automatically becomes

↓

Tomorrow's Opening Balance

No manual entry required.

Opening Balance remains editable.

Reason

Sometimes money is:

- Withdrawn personally
- Deposited elsewhere
- Bank transferred
- Adjusted manually

User can edit Opening Balance anytime.

---

10. History

Search

- Customer Name
- Mobile Number
- Transaction ID

Filters

- Today
- Yesterday
- Custom Date
- AEPS
- Cash In
- Cash Out

Actions

- Edit
- Delete
- Duplicate

---

11. Reports

Today

Yesterday

This Week

This Month

Custom Range

Report shows

- Number of Transactions
- Total Amount
- Total Commission
- Closing Balance

---

12. Auto Sync

Offline First.

Every transaction saves instantly to Hive.

When internet becomes available

↓

Automatic Firebase Sync

No manual sync required.

---

13. Firestore Structure

users

userId

transactions

transactionId

daily_balances

date

settings

userId

---

14. Settings

Profile

Shop Name

Owner Name

Phone Number

Security

Change PIN

Data

Firebase Sync Status

About

App Version

---

15. Future Feature (To Do)

Balance Adjustment

Purpose

Handle balance changes outside normal transactions.

Fields

- Account
- Increase / Decrease
- Amount
- Reason
- Notes
- Time

Reason examples

- Self Withdrawal
- Bank Transfer
- Wallet Load
- Manual Correction
- Other

This feature keeps a complete audit trail.

---

16. Validation Rules

Customer Name required.

Amount must be greater than zero.

Phone Number optional.

Transaction ID optional.

Notes optional.

Balance cannot be negative unless explicitly allowed.

---

17. UI Principles

Minimal taps.

Large buttons.

Large text.

One-hand operation.

Fast entry.

Material 3.

Dark Mode support.

---

18. Security

PIN stored as hash.

Firestore Security Rules enabled.

Each user can access only their own data.

HTTPS communication only.

---

19. MVP Checklist

✅ Register

✅ Login

✅ Dashboard

✅ AEPS Entry

✅ PhonePe Cash In

✅ PhonePe Cash Out

✅ Auto Commission

✅ Editable Commission

✅ Auto Balance

✅ Editable Opening Balance

✅ History

✅ Search

✅ Reports

✅ Offline Storage

✅ Firebase Sync

---

20. Future Roadmap

Version 1.1

- Balance Adjustment
- Export PDF
- Excel Export
- Backup & Restore

Version 1.2

- WhatsApp Receipt
- SMS Receipt
- Daily Closing Lock
- Multiple PhonePe Accounts

Version 2.0

- Multi-Shop Support
- Employee Accounts
- Role-based Permissions
- Cloud Analytics
- Dashboard Graphs
- Customer Statistics
- Backup Scheduling
- Web Admin Panel

---

21. Success Criteria

A retailer should be able to:

- Open the app.
- Record a transaction within 10 seconds.
- View updated balances instantly.
- Find any previous transaction in seconds.
- Never need a paper diary again.
