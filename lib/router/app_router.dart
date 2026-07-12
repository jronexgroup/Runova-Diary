import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/new_transaction_screen.dart';
import '../screens/transaction_history_screen.dart';
import '../screens/edit_transaction_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/transaction_detail_screen.dart';
import '../screens/bank_accounts_screen.dart';
import '../screens/commission_settings_screen.dart';
import '../screens/ai_settings_screen.dart';
import '../screens/aeps_commission_screen.dart';
import '../screens/distributor_commission_screen.dart';
import '../screens/settlement_charge_screen.dart';
import '../screens/account_commission_screen.dart';
import '../screens/change_pin_screen.dart';
import '../screens/adjust_balance_screen.dart';
import '../screens/self_transfer_screen.dart';
import '../utils/constants.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _navigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider) != null;
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';
      final isRegister = state.matchedLocation == '/register';

      if (isSplash) return null;

      if (!isLoggedIn && !isLogin && !isRegister) {
        return '/login';
      }

      if (isLoggedIn && (isLogin || isRegister)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/new-transaction/:type',
        builder: (_, state) {
          final typeStr = state.pathParameters['type'] ?? 'aeps';
          final type = TransactionType.values.firstWhere(
            (e) => e.name == typeStr,
            orElse: () => TransactionType.aeps,
          );
          return NewTransactionScreen(type: type);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (_, __) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/edit-transaction/:id',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          return EditTransactionScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/transaction-detail/:id',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          return TransactionDetailScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/reports',
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/bank-accounts',
        builder: (_, __) => const BankAccountsScreen(),
      ),
      GoRoute(
        path: '/commission-settings',
        builder: (_, __) => const CommissionSettingsScreen(),
      ),
      GoRoute(
        path: '/commission-settings/aeps',
        builder: (_, __) => const AepsCommissionScreen(),
      ),
      GoRoute(
        path: '/commission-settings/distributor',
        builder: (_, __) => const DistributorCommissionScreen(),
      ),
      GoRoute(
        path: '/commission-settings/settlement',
        builder: (_, __) => const SettlementChargeScreen(),
      ),
      GoRoute(
        path: '/commission-settings/account/:id',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          final name = state.extra as String? ?? 'Account';
          return AccountCommissionScreen(accountId: id, accountName: name);
        },
      ),
      GoRoute(
        path: '/ai-settings',
        builder: (_, __) => const AiSettingsScreen(),
      ),
      GoRoute(
        path: '/change-pin',
        builder: (_, __) => const ChangePinScreen(),
      ),
      GoRoute(
        path: '/adjust-balance/:isAdd',
        builder: (_, state) {
          final isAdd = state.pathParameters['isAdd'] == 'true';
          return AdjustBalanceScreen(isAdd: isAdd);
        },
      ),
      GoRoute(
        path: '/self-transfer',
        builder: (_, __) => const SelfTransferScreen(),
      ),
    ],
  );
});
