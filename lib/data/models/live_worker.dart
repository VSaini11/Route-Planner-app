import 'package:cloud_firestore/cloud_firestore.dart';

class LiveWorker {
  final String uid;
  final String name;
  final double lat;
  final double lng;
  final double accuracy;
  final double heading;
  final double speed;
  final DateTime? updatedAt;

  const LiveWorker({
    required this.uid,
    required this.name,
    required this.lat,
    required this.lng,
    required this.accuracy,
    this.heading = 0,
    this.speed = 0,
    required this.updatedAt,
  });

  bool get isStale =>
      updatedAt == null || DateTime.now().difference(updatedAt!) > const Duration(minutes: 3);

  factory LiveWorker.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return LiveWorker(
      uid: d.id,
      name: (m['name'] ?? 'Worker') as String,
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      accuracy: (m['accuracy'] as num?)?.toDouble() ?? 0,
      heading: (m['heading'] as num?)?.toDouble() ?? 0,
      speed: (m['speed'] as num?)?.toDouble() ?? 0,
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
