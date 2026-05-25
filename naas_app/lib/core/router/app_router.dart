import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SizedBox()),
    GoRoute(
      path: '/auth',
      builder: (_, __) => const SizedBox(),
      routes: [
        GoRoute(path: 'login', builder: (_, __) => const SizedBox()),
        GoRoute(path: 'register', builder: (_, __) => const SizedBox()),
      ],
    ),
    GoRoute(
      path: '/',
      builder: (_, __) => const SizedBox(),
      routes: [
        GoRoute(path: 'home', builder: (_, __) => const SizedBox()),
        GoRoute(path: 'search', builder: (_, __) => const SizedBox()),
        GoRoute(
          path: 'courses/:id',
          builder: (_, state) => const SizedBox(),
        ),
        GoRoute(path: 'cart', builder: (_, __) => const SizedBox()),
        GoRoute(path: 'wishlist', builder: (_, __) => const SizedBox()),
        GoRoute(path: 'subscriptions', builder: (_, __) => const SizedBox()),
        GoRoute(path: 'wallet', builder: (_, __) => const SizedBox()),
        GoRoute(path: 'notifications', builder: (_, __) => const SizedBox()),
        GoRoute(path: 'profile', builder: (_, __) => const SizedBox()),
        GoRoute(path: 'settings', builder: (_, __) => const SizedBox()),
        GoRoute(
          path: 'teacher',
          builder: (_, __) => const SizedBox(),
          routes: [
            GoRoute(path: 'dashboard', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'apply', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'courses', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'earnings', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'students', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'create-course', builder: (_, __) => const SizedBox()),
            GoRoute(
              path: 'edit-course/:id',
              builder: (_, state) => const SizedBox(),
            ),
          ],
        ),
        GoRoute(
          path: 'admin',
          builder: (_, __) => const SizedBox(),
          routes: [
            GoRoute(path: 'dashboard', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'users', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'teachers', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'commission', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'withdrawals', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'refunds', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'reports', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'transactions', builder: (_, __) => const SizedBox()),
            GoRoute(path: 'admins', builder: (_, __) => const SizedBox()),
          ],
        ),
      ],
    ),
  ],
);
