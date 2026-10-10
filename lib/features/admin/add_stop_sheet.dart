import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../data/models/new_stop.dart';
import '../../data/models/route_stop.dart';
import 'location_picker_screen.dart';

class AddStopSheet extends StatefulWidget {
  const AddStopSheet({super.key});
  @override
  State<AddStopSheet> createState() => _AddStopSheetState();
}

class _AddStopSheetState extends State<AddStopSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController(text: '0');
  final _tasks = TextEditingController();
  double _radius = 100;
  LatLng? _point;
  String? _error;

  Future<void> _pick() async {
    final r = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: _point, radiusM: _radius)),
    );
    if (r != null) setState(() => _point = r);
  }

  /// One task per line. Start a line with * when a photo is required.
  List<StopTask> _parseTasks() {
    final out = <StopTask>[];
    for (final raw in _tasks.text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final photo = line.startsWith('*');
      final title = photo ? line.substring(1).trim() : line;
      if (title.isNotEmpty) out.add(StopTask(title: title, requirePhoto: photo));
    }
    return out;
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter the client / site name');
      return;
    }
    if (_point == null) {
      setState(() => _error = 'Pick the location coordinates on the map');
      return;
    }
    Navigator.pop(
      context,
      NewStop(
        name: _name.text.trim(),
        lat: _point!.latitude,
        lng: _point!.longitude,
        radiusM: _radius,
        target: double.tryParse(_target.text) ?? 0,
        tasks: _parseTasks(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_location_alt_rounded, color: kPrimary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Add Itinerary Stop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Client or Destination Name',
              prefixIcon: Icon(Icons.business_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _pick,
            icon: Icon(Icons.pin_drop_rounded, size: 20, color: _point == null ? null : kPrimary),
            label: Text(
              _point == null
                  ? 'Pick Location Coordinates on Map'
                  : 'Selected: ${_point!.latitude.toStringAsFixed(4)}, ${_point!.longitude.toStringAsFixed(4)}',
              style: TextStyle(
                fontWeight: _point == null ? FontWeight.w600 : FontWeight.w800,
                color: _point == null ? null : kPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Geofence Check-in Radius', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_radius.round()} m',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _radius,
                  min: 50,
                  max: 500,
                  divisions: 45,
                  activeColor: kPrimary,
                  onChanged: (v) => setState(() => _radius = v),
                ),
                Text(
                  'Automatic check-in / check-out triggers within this boundary radius.',
                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Sales / Target Amount (₹)',
              prefixIcon: Icon(Icons.currency_rupee_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tasks,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Tasks Checklist (one per line)',
              hintText: '*Take storefront photo\n*Collect payment receipt\nDeliver invoice',
              helperText: 'Prefix with * to enforce mandatory photo capture',
              prefixIcon: Icon(Icons.checklist_rounded, size: 20),
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: kRed, size: 16),
                  const SizedBox(width: 6),
                  Text(_error!, style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _save,
              child: const Text('Add Stop to Itinerary',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}
