# Firebase Backup Tool

Read-only backup tool for Runova Diary Firebase database.

## Features

- **Read-only**: Only reads data from Firebase, never writes/edits/deletes
- **Full backup**: Downloads all users, transactions, balances, and settings
- **Timestamped**: Each backup creates a timestamped directory
- **JSON format**: All data saved as readable JSON files

## Backup Structure

```
backups/
  backup_2026-09-17T12-00-00-000/
    manifest.json
    {userId}/
      user.json
      transactions.json
      daily_balances.json
      settings.json
```

## Usage

### From command line:

```bash
cd backup
dart pub get
dart run backup_firebase.dart
```

### Custom output path:

```bash
dart run backup_firebase.dart /path/to/backup
```

## Data Backed Up

| Collection | Description |
|------------|-------------|
| `users/{userId}` | User profile data |
| `users/{userId}/transactions` | All transactions |
| `users/{userId}/daily_balances` | Daily balance records |
| `users/{userId}/settings` | App settings (accounts, commissions, AI) |

## Safety

- **No write operations**: This tool only reads from Firebase
- **No authentication required**: Uses public API key for read access
- **Safe to run multiple times**: Creates new timestamped directory each time
