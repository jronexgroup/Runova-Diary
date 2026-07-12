import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isOnline = false;
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _checkSyncStatus() async {
    final online = await ref.read(syncServiceProvider).isOnline();
    if (mounted) setState(() => _isOnline = online);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Profile', style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.store),
                  title: const Text('Shop Name'),
                  subtitle: Text(user?.shopName ?? '-'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Owner Name'),
                  subtitle: Text(user?.ownerName ?? '-'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Phone Number'),
                  subtitle: Text(user?.phoneNumber ?? '-'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Security', style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Change PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/change-pin'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Data', style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(_isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: _isOnline ? Colors.green : Colors.grey),
                  title: const Text('Sync Status'),
                  subtitle: Text(_isOnline ? 'Connected - Auto-sync active' : 'Offline - Changes saved locally'),
                  trailing: Icon(
                    _isOnline ? Icons.check_circle : Icons.error_outline,
                    color: _isOnline ? Colors.green : Colors.orange,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Sync Now'),
                  onTap: () async {
                    await ref.read(syncServiceProvider).syncToFirebase();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sync completed')),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_circle),
                  title: const Text('Add Balance'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/adjust-balance/true'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  title: const Text('Decrease Balance', style: TextStyle(color: Colors.red)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/adjust-balance/false'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: Colors.indigo),
                  title: const Text('Self Transfer'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/self-transfer'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Accounts', style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance, color: Colors.teal),
                  title: const Text('Bank Accounts'),
                  subtitle: Text('${ref.watch(accountsProvider).length} account(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/bank-accounts'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune, color: Colors.deepPurple),
                  title: const Text('Commission Settings'),
                  subtitle: const Text('Customize AEPS & account commissions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/commission-settings'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: Colors.teal),
                  title: const Text('AI Settings'),
                  subtitle: const Text('Configure AI-powered form filling'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/ai-settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('About', style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info),
              title: const Text('App Version'),
              trailing: Text(AppConstants.appVersion),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

}

