import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../services/firebase_backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _backupService = FirebaseBackupService();
  bool _loading = false;
  bool _loadingList = true;
  List<Map<String, dynamic>> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _loadingList = true);
    _backups = await _backupService.getBackupList();
    setState(() => _loadingList = false);
  }

  Future<void> _createBackup() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _loading = true);
    try {
      await _backupService.createBackup(user.id);
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteBackup(String path, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Delete $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _backupService.deleteBackup(path);
      await _loadBackups();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Backup')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_download, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Create Backup', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Download all your data from Firebase as a JSON file. '
                    'This only reads data, nothing is modified.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _createBackup,
                    icon: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.backup),
                    label: Text(_loading ? 'Backing up...' : 'Create Backup'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Backups (${_backups.length})', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (_backups.isNotEmpty)
                  TextButton(
                    onPressed: _loadBackups,
                    child: const Text('Refresh'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loadingList
                ? const Center(child: CircularProgressIndicator())
                : _backups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.backup_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 8),
                            Text('No backups yet', style: theme.textTheme.bodyLarge),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _backups.length,
                        itemBuilder: (ctx, i) {
                          final backup = _backups[i];
                          final name = backup['name'] as String;
                          final size = backup['size'] as int;
                          final modified = DateTime.parse(backup['modified'] as String);
                          final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(modified);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Icon(Icons.description, color: theme.colorScheme.primary),
                              ),
                              title: Text(
                                name.replaceFirst('backup_', '').replaceFirst('.json', '').replaceAll('_', ' '),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text('$dateStr • ${_formatSize(size)}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteBackup(backup['path'] as String, name),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
