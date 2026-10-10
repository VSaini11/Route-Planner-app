import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

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
      setState(() => _error = 'Pick the location on the map');
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Add stop', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Client / site name')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.map_outlined),
            label: Text(_point == null
                ? 'Pick location on map'
                : '${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}'),
          ),
          const SizedBox(height: 12),
          Text('Check-in radius: ${_radius.round()} m',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: _radius,
            min: 50,
            max: 500,
            divisions: 45,
            label: '${_radius.round()} m',
            onChanged: (v) => setState(() => _radius = v),
          ),
          const Text(
            'The worker is checked in automatically when inside this circle and checked '
            'out when they leave it. Use 100 m or more for GPS accuracy indoors.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target (₹)')),
          const SizedBox(height: 12),
          TextField(
            controller: _tasks,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Tasks (one per line)',
              helperText: 'Start a line with * if a photo is required.\nExample: *Capture display photo',
              helperMaxLines: 3,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Add to route')),
        ]),
      ),
    );
  }
}
