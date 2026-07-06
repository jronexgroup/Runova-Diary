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
                  leading: const Icon(Icons.add_circle),
                  title: const Text('Add Balance'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAdjustBalance(true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  title: const Text('Decrease Balance', style: TextStyle(color: Colors.red)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAdjustBalance(false),
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

  void _showAdjustBalance(bool isAdd) {
    final user = ref.read(authProvider);
    if (user == null) return;

    final todayKey = DateTime.now().dateKey;
    final balance = ref.read(balancesProvider)[todayKey];
    if (balance == null) return;

    String? selectedAccount;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isAdd ? 'Add Balance' : 'Decrease Balance'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select Account', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _accountBtn(ctx, 'AEPS', Icons.account_balance,
                        selectedAccount == 'aeps', () {
                      setDialogState(() => selectedAccount = 'aeps');
                    }),
                    const SizedBox(width: 8),
                    _accountBtn(ctx, 'Hasibul', Icons.phone_android,
                        selectedAccount == 'hasibul', () {
                      setDialogState(() => selectedAccount = 'hasibul');
                    }),
                    const SizedBox(width: 8),
                    _accountBtn(ctx, 'Runa Laila', Icons.phone_android,
                        selectedAccount == 'runaLaila', () {
                      setDialogState(() => selectedAccount = 'runaLaila');
                    }),
                  ],
                ),
                if (selectedAccount == null) ...[
                  const SizedBox(height: 4),
                  Text('Please select an account',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount *',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'Amount required';
                    final amt = double.tryParse(v!);
                    if (amt == null || amt <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes),
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
                if (selectedAccount == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please select an account')),
                  );
                  return;
                }
                if (!formKey.currentState!.validate()) return;

                final amount = double.parse(amountCtrl.text.trim());
                double aepsOpening = balance.aepsOpeningBalance;
                double hasibulOpening = balance.hasibulOpeningBalance;
                double runaLailaOpening = balance.runaLailaOpeningBalance;

                final delta = isAdd ? amount : -amount;
                switch (selectedAccount) {
                  case 'aeps':
                    aepsOpening += delta;
                  case 'hasibul':
                    hasibulOpening += delta;
                  case 'runaLaila':
                    runaLailaOpening += delta;
                }

                await ref.read(balancesProvider.notifier).updateOpeningBalances(
                  userId: user.id,
                  dateKey: todayKey,
                  aepsOpening: aepsOpening,
                  hasibulOpening: hasibulOpening,
                  runaLailaOpening: runaLailaOpening,
                );

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isAdd ? 'Balance added' : 'Balance decreased')),
                );
              }
            },
            child: Text(isAdd ? 'Add' : 'Decrease'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountBtn(BuildContext ctx, String label, IconData icon,
      bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(ctx).colorScheme.primaryContainer
                : Theme.of(ctx).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Theme.of(ctx).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected
                      ? Theme.of(ctx).colorScheme.primary
                      : Theme.of(ctx).colorScheme.onSurfaceVariant,
                  size: 24),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? Theme.of(ctx).colorScheme.primary
                        : null,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
