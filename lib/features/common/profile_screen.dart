import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initial = (profile != null && profile.name.isNotEmpty ? profile.name[0] : '?').toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withValues(alpha: isDark ? 0.1 : 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(profile?.name ?? 'User Profile',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (profile?.role ?? 'worker').toUpperCase(),
                    style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D2E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (tracking.active ? kGreen : Colors.grey).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.sensors_rounded,
                    color: tracking.active ? kGreen : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Telemetry & GPS Status',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow('Real-time Tracking', tracking.active ? 'ACTIVE (Broadcasting)' : 'STANDBY (Idle)',
                valColor: tracking.active ? kGreen : Colors.grey),
            const SizedBox(height: 8),
            if (tracking.position != null) ...[
              _infoRow('GPS Precision', '±${tracking.position!.accuracy.round()} meters', valColor: kPrimary),
              const SizedBox(height: 8),
            ],
            if (!kIsWeb)
              FutureBuilder<PermissionStatus>(
                future: Permission.locationAlways.status,
                builder: (_, s) => _infoRow(
                  'Background Location',
                  s.data?.isGranted == true ? 'Authorized ✓' : 'Limited',
                  valColor: s.data?.isGranted == true ? kGreen : kAmber,
                ),
              ),
            if (!kIsWeb) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                label: const Text('Configure Device Permissions', style: TextStyle(fontSize: 13)),
                onPressed: openAppSettings,
              ),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: kRed,
            side: BorderSide(color: kRed.withValues(alpha: 0.4)),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text('Sign Out from Workspace', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          onPressed: () async {
            await ref.read(trackingProvider.notifier).stop();
            await FirebaseAuth.instance.signOut();
          },
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, {Color? valColor}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: valColor)),
        ],
      );
}
