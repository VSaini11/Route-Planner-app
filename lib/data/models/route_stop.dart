import 'package:cloud_firestore/cloud_firestore.dart';

class StopTask {
  final String title;
  final bool requirePhoto;
  final bool done;
  final String? photoUrl;

  const StopTask({required this.title, this.requirePhoto = false, this.done = false, this.photoUrl});

  factory StopTask.fromMap(Map<String, dynamic> m) => StopTask(
        title: (m['title'] ?? '') as String,
        requirePhoto: m['requirePhoto'] == true,
        done: m['done'] == true,
        photoUrl: m['photoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'requirePhoto': requirePhoto,
        'done': done,
        'photoUrl': photoUrl,
      };
}

class RouteStop {
  final String id;
  final int order;
  final String name;
  final double lat;
  final double lng;
  final double radiusM; // set by admin
  final double target;
  final String notes;
  final String status; // pending | checkedin | done
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final List<StopTask> tasks;

  const RouteStop({
    required this.id,
    required this.order,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.target,
    required this.notes,
    required this.status,
    required this.checkInAt,
    required this.checkOutAt,
    required this.tasks,
  });

  bool get isDone => status == 'done';
  bool get isCheckedIn => status == 'checkedin';

  /// Worked time = check-out minus check-in (live while still checked in).
  Duration? get worked {
    final inAt = checkInAt;
    if (inAt == null) return null;
    return (checkOutAt ?? DateTime.now()).difference(inAt);
  }

  factory RouteStop.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return RouteStop(
      id: d.id,
      order: (m['order'] as num?)?.toInt() ?? 0,
      name: (m['name'] ?? '') as String,
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      radiusM: (m['radiusM'] as num?)?.toDouble() ?? 100,
      target: (m['target'] as num?)?.toDouble() ?? 0,
      notes: (m['notes'] ?? '') as String,
      status: (m['status'] ?? 'pending') as String,
      checkInAt: (m['checkInAt'] as Timestamp?)?.toDate(),
      checkOutAt: (m['checkOutAt'] as Timestamp?)?.toDate(),
      tasks: ((m['tasks'] as List?) ?? const [])
          .map((e) => StopTask.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
