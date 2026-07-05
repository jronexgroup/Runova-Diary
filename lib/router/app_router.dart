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
import '../utils/constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(authProvider) != null;

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
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
        path: '/reports',
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
  );
});

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
