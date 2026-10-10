import 'package:geolocator/geolocator.dart';

import '../core/geo.dart';
import '../data/models/route_stop.dart';

enum GeofenceType { enter, exit }

class GeofenceEvent {
  final GeofenceType type;
  final RouteStop stop;
  const GeofenceEvent(this.type, this.stop);
}

/// Decides when the worker has really arrived at / left a stop.
///
/// Precision rules (this is what stops GPS jitter from causing false check-ins):
///  * a fix with accuracy worse than [maxAccuracyM] is ignored
///  * ENTER needs [confirmFixes] consecutive fixes inside the admin's radius
///  * EXIT uses a slightly bigger radius (hysteresis) and also needs [confirmFixes] fixes
///  * the same event is never fired twice while the database update is in flight
class GeofenceEngine {
  static const double maxAccuracyM = 100;
  static const int confirmFixes = 1;

  final _inside = <String, int>{};
  final _outside = <String, int>{};
  final _waiting = <String, String>{}; // stopId -> status when the event was fired

  List<GeofenceEvent> evaluate(Position p, List<RouteStop> stops) {
    final events = <GeofenceEvent>[];
    if (p.accuracy > maxAccuracyM) return events;

    for (final s in stops) {
      final waitingFor = _waiting[s.id];
      if (waitingFor != null && waitingFor != s.status) _waiting.remove(s.id);
      if (s.isDone || _waiting.containsKey(s.id)) continue;

      final d = haversineM(p.latitude, p.longitude, s.lat, s.lng);

      if (s.status == 'pending') {
        if (d <= s.radiusM) {
          final n = (_inside[s.id] ?? 0) + 1;
          _inside[s.id] = n;
          if (n >= confirmFixes) {
            _inside[s.id] = 0;
            _waiting[s.id] = s.status;
            events.add(GeofenceEvent(GeofenceType.enter, s));
          }
        } else {
          _inside[s.id] = 0;
        }
      } else if (s.isCheckedIn) {
        final exitRadius = s.radiusM + (s.radiusM * 0.15).clamp(15.0, 60.0).toDouble();
        if (d > exitRadius) {
          final n = (_outside[s.id] ?? 0) + 1;
          _outside[s.id] = n;
          if (n >= confirmFixes) {
            _outside[s.id] = 0;
            _waiting[s.id] = s.status;
            events.add(GeofenceEvent(GeofenceType.exit, s));
          }
        } else {
          _outside[s.id] = 0;
        }
      }
    }
    return events;
  }

  void reset() {
    _inside.clear();
    _outside.clear();
    _waiting.clear();
  }
}
