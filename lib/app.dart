import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/admin/admin_home.dart';
import 'features/auth/login_screen.dart';
import 'features/worker/worker_shell.dart';
import 'providers.dart';

import 'features/common/in_app_notification.dart';

class FieldRouteApp extends StatelessWidget {
  const FieldRouteApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: InAppNotificationBanner.navigatorKey,
        title: 'FieldRoute',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      );
}

/// Login, or admin / worker home depending on the role stored in users/{uid}.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const loading = Scaffold(body: Center(child: CircularProgressIndicator()));
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => loading,
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (User? user) {
        if (user == null) return const LoginScreen();
        return ref.watch(profileProvider).when(
              loading: () => loading,
              error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
              data: (p) {
                if (p == null) {
                  return Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Your profile is missing. Ask your admin to add you.',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                              onPressed: () => FirebaseAuth.instance.signOut(),
                              child: const Text('Sign out')),
                        ]),
                      ),
                    ),
                  );
                }
                return p.role == 'admin' ? const AdminHome() : const WorkerShell();
              },
            );
      },
    );
  }
}
