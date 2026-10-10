import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers.dart';
import '../../services/tracking.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final user = FirebaseAuth.instance.currentUser;
    final tracking = ref.watch(trackingProvider);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: cs.primaryContainer,
            child: Text(
                (profile != null && profile.name.isNotEmpty ? profile.name[0] : '?').toUpperCase(),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile?.name ?? '',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(user?.email ?? ''),
              Text('Role: ${profile?.role ?? ''}', style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tracking', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              Text(tracking.active ? 'On: your route is being tracked' : 'Off'),
              if (tracking.position != null)
                Text('GPS accuracy: ±${tracking.position!.accuracy.round()} m'),
              if (!kIsWeb)
                FutureBuilder<PermissionStatus>(
                  future: Permission.locationAlways.status,
                  builder: (_, s) => Text(
                      'Background location: ${s.data?.isGranted == true ? 'allowed' : 'not allowed'}'),
                ),
              if (!kIsWeb) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('Open app settings'),
                  onPressed: openAppSettings,
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: cs.error),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          onPressed: () async {
            await ref.read(trackingProvider.notifier).stop();
            await FirebaseAuth.instance.signOut();
          },
        ),
      ],
    );
  }
}
