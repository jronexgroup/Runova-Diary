import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

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
              onTap: () => _showChangePinDialog(),
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
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Opening Balance'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showEditOpeningBalance(),
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

  void _showChangePinDialog() {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: AppConstants.maxPinLength,
                decoration: const InputDecoration(
                  labelText: 'Current PIN',
                  counterText: '',
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? 'Enter current PIN' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: newPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: AppConstants.maxPinLength,
                decoration: const InputDecoration(
                  labelText: 'New PIN',
                  counterText: '',
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Enter new PIN';
                  if ((v?.length ?? 0) < AppConstants.minPinLength) {
                    return 'PIN must be ${AppConstants.minPinLength}-${AppConstants.maxPinLength} digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: AppConstants.maxPinLength,
                decoration: const InputDecoration(
                  labelText: 'Confirm New PIN',
                  counterText: '',
                ),
                validator: (v) =>
                    v != newPinCtrl.text ? 'PINs do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ref.read(authProvider.notifier).changePin(
                  oldPinCtrl.text,
                  newPinCtrl.text,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN changed successfully')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showEditOpeningBalance() {
    final user = ref.read(authProvider);
    if (user == null) return;

    final todayKey = DateTime.now().dateKey;
    final balance = ref.read(balancesProvider)[todayKey];
    if (balance == null) return;

    final aepsCtrl = TextEditingController(
      text: balance.aepsOpeningBalance.toStringAsFixed(0),
    );
    final hasibulCtrl = TextEditingController(
      text: balance.hasibulOpeningBalance.toStringAsFixed(0),
    );
    final runaCtrl = TextEditingController(
      text: balance.runaLailaOpeningBalance.toStringAsFixed(0),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Opening Balance'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: aepsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'AEPS Opening Balance',
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: hasibulCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Hasibul PhonePe Opening',
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: runaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Runa Laila PhonePe Opening',
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await ref.read(balancesProvider.notifier).updateOpeningBalances(
                userId: user.id,
                dateKey: todayKey,
                aepsOpening: double.tryParse(aepsCtrl.text),
                hasibulOpening: double.tryParse(hasibulCtrl.text),
                runaLailaOpening: double.tryParse(runaCtrl.text),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening balance updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
