import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  int _id = 100;

  static const _plans = AndroidNotificationChannel(
    'plans',
    'Route plans',
    description: 'New route assigned',
    importance: Importance.high,
  );
  static const _visits = AndroidNotificationChannel(
    'visits',
    'Check-in and check-out',
    description: 'Arrival and departure at client sites',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (kIsWeb) return; // push + local notifications are mobile-only here

    await FirebaseMessaging.instance.requestPermission();
    await _local.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    final android =
        _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_plans);
    await android?.createNotificationChannel(_visits);

    // Real-time Firestore notification stream for workers (works without Cloud Functions on Spark plan)
    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u == null) return;
      final startTime = DateTime.now().subtract(const Duration(minutes: 1));
      FirebaseFirestore.instance
          .collection('notifyQueue')
          .where('toUid', isEqualTo: u.uid)
          .snapshots()
          .listen((snap) {
        for (final doc in snap.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final d = doc.doc.data();
            if (d == null) continue;
            final sendAt = (d['sendAt'] as Timestamp?)?.toDate();
            final time = (d['time'] as Timestamp?)?.toDate() ?? DateTime.now();

            // If scheduled in the future, don't show yet until due
            if (sendAt != null && sendAt.isAfter(DateTime.now())) continue;

            // Only show recent notifications
            if (time.isAfter(startTime)) {
              showLocal(
                (d['title'] ?? 'New notification') as String,
                (d['body'] ?? '') as String,
                channel: _plans,
              );
            }
          }
        }
      });
    });
  }

  Future<void> syncToken() async {
    if (kIsWeb) return;
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(u.uid, token);
    } catch (_) {}
  }

  Future<void> _saveToken(String uid, String token) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .set({'fcmToken': token}, SetOptions(merge: true));

  /// Local notification, e.g. "Checked in at Vegas Mall".
  Future<void> showLocal(String title, String body, {AndroidNotificationChannel? channel}) async {
    if (kIsWeb) return;
    final ch = channel ?? _visits;
    await _local.show(
      _id++,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(ch.id, ch.name,
            channelDescription: ch.description,
            importance: Importance.high,
            priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
