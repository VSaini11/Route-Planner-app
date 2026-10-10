import 'package:cloud_firestore/cloud_firestore.dart';

class RoutePlan {
  final String id;
  final String workerId;
  final String workerName;
  final String date; // yyyy-MM-dd

  const RoutePlan({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.date,
  });

  factory RoutePlan.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return RoutePlan(
      id: d.id,
      workerId: (m['workerId'] ?? '') as String,
      workerName: (m['workerName'] ?? '') as String,
      date: (m['date'] ?? '') as String,
    );
  }
}
