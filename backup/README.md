# Firebase Backup Tool

A Python developer tool to backup the entire Firebase Firestore database.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. No additional setup needed - uses your app's Firebase credentials.

## Usage

```bash
python backup_firebase.py
```

## Output

Backups are saved in `backups/` directory:
```
backups/backup_2026-09-17_14-30-00.json
```

## Notes

- Only READS from Firebase (no writes/edits/deletes)
- Transactions sorted by date (newest first)
- Daily balances sorted by date (newest first)
