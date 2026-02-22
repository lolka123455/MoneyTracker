import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/subscriptions/subscriptions_screen.dart';
import '../screens/subscriptions/add_edit_subscription_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/expenses/add_edit_expense_screen.dart';
import '../screens/budgeting/scope_screen.dart';
import '../screens/statistics/statistics_screen.dart';
import '../screens/tbank/tbank_connect_screen.dart';
import '../screens/tbank/tbank_transactions_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/categories/categories_screen.dart';
import '../screens/shell_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/subscriptions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SubscriptionsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) =>
                    const AddEditSubscriptionScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => AddEditSubscriptionScreen(
                  subscriptionId:
                      int.tryParse(state.pathParameters['id'] ?? ''),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/expenses',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExpensesScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) =>
                    const AddEditExpenseScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => AddEditExpenseScreen(
                  expenseId:
                      int.tryParse(state.pathParameters['id'] ?? ''),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/statistics',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StatisticsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/scope',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ScopeScreen(),
      ),
      GoRoute(
        path: '/tbank/connect',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TBankConnectScreen(),
      ),
      GoRoute(
        path: '/tbank/transactions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TBankTransactionsScreen(),
      ),
      GoRoute(
        path: '/categories',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CategoriesScreen(),
      ),
    ],
  );
});
