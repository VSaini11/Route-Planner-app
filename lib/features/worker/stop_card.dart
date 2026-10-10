import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../data/models/route_stop.dart';
import '../../providers.dart';

class StopCard extends ConsumerStatefulWidget {
  final String routeId;
  final RouteStop stop;
  final int number;
  final double? legMeters; // distance from the previous stop
  final Position? position;

  const StopCard({
    super.key,
    required this.routeId,
    required this.stop,
    required this.number,
    required this.legMeters,
    required this.position,
  });

  @override
  ConsumerState<StopCard> createState() => _StopCardState();
}

class _StopCardState extends ConsumerState<StopCard> {
  late bool _expanded = widget.stop.isCheckedIn;
  int? _uploading;
  Timer? _tick;

  RouteStop get s => widget.stop;

  @override
  void initState() {
    super.initState();
    // Refresh the live "Worked" timer while checked in.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && s.isCheckedIn) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(StopCard old) {
    super.didUpdateWidget(old);
    if (!old.stop.isCheckedIn && widget.stop.isCheckedIn) _expanded = true;
  }

  double? get _dist {
    final p = widget.position;
    if (p == null) return null;
    return haversineM(p.latitude, p.longitude, s.lat, s.lng);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _checkIn() async {
    final p = widget.position;
    if (p == null) return;
    await ref.read(routeRepoProvider).checkIn(widget.routeId, s.id, fixTime(p.timestamp),
        lat: p.latitude, lng: p.longitude, accuracy: p.accuracy, auto: false);
    if (mounted) _snack('Checked in at ${s.name}');
  }

  Future<void> _checkOut() async {
    final p = widget.position;
    final worked = await ref.read(routeRepoProvider).checkOut(widget.routeId, s.id, fixTime(p?.timestamp));
    if (mounted) _snack(worked == null ? 'Checked out' : 'Checked out. Worked ${fmtDuration(worked)}');
  }

  Future<void> _capture(int index) async {
    if (!s.isCheckedIn && !s.isDone) {
      _snack('Please check in first before taking photos.');
      return;
    }
    final x = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 720);
    if (x == null) return;
    setState(() => _uploading = index);
    try {
      final repo = ref.read(routeRepoProvider);
      final url = await repo.uploadProof(widget.routeId, s.id, x);
      await repo.setTask(widget.routeId, s.id, index, done: true, photoUrl: url);
      if (mounted) _snack('Photo uploaded successfully!');
    } catch (e) {
      if (mounted) _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _toggle(int index, bool value) async {
    if (!s.isCheckedIn && !s.isDone) {
      _snack('Please check in first.');
      return;
    }
    await ref.read(routeRepoProvider).setTask(widget.routeId, s.id, index, done: value);
  }

  Future<void> _editNotes() async {
    final c = TextEditingController(text: s.notes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Visit notes / deal info'),
        content: TextField(controller: c, maxLines: 5, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) await ref.read(routeRepoProvider).saveNotes(widget.routeId, s.id, c.text.trim());
  }

  Future<void> _navigate() => launchUrl(
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lng}'),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dist = _dist;
    final doneTasks = s.tasks.where((t) => t.done).length;

    final statusColor = s.isDone ? kGreen : (s.isCheckedIn ? kBlue : cs.outline);
    final statusLabel = s.isDone ? 'Done' : (s.isCheckedIn ? 'In progress' : 'Pending');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _chip('Route 1', cs.primaryContainer, cs.onPrimaryContainer),
            const SizedBox(width: 6),
            Text('STOP #${widget.number}',
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 11)),
            const Spacer(),
            _chip(statusLabel, statusColor.withValues(alpha: 0.12), statusColor),
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20),
            ),
          ]),
          const SizedBox(height: 4),
          Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            _chip('${s.radiusM.round()}m radius (${dist == null ? '--' : fmtKm(dist)})',
                cs.surfaceContainerHighest, cs.onSurface,
                icon: Icons.gps_fixed),
          ]),
          const SizedBox(height: 6),
          Text('Target: ₹${s.target.round()}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: _box(cs.surfaceContainerHighest, [
                _iconLine(Icons.local_shipping, 'Drive: ', widget.number == 1 ? 'Start' : 'Next stop'),
                const SizedBox(height: 4),
                _iconLine(Icons.place_outlined, 'Trip: ',
                    widget.legMeters == null ? '--' : fmtKm(widget.legMeters!),
                    valueColor: kGreen, iconColor: kGreen),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _box(kGreen.withValues(alpha: 0.08), [
                _dotLine(kGreen, 'IN: ', fmtTime(s.checkInAt)),
                const SizedBox(height: 4),
                _dotLine(kRed, 'OUT: ', fmtTime(s.checkOutAt)),
                const SizedBox(height: 4),
                _iconLine(Icons.schedule, 'Worked: ',
                    s.worked == null ? '--' : fmtDuration(s.worked!)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          _box(kAmber.withValues(alpha: 0.10), [
            const Row(children: [
              Icon(Icons.edit_note, color: Color(0xFFB45309), size: 16),
              SizedBox(width: 6),
              Text('Visit Notes / Deal Info:',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309), fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Text(s.notes.isEmpty ? '"Scheduled visit"' : s.notes,
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
          ]),
          if (_expanded) ...[
            const SizedBox(height: 12),
            if (s.tasks.isNotEmpty) ...[
              Text('Tasks ($doneTasks/${s.tasks.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              for (var i = 0; i < s.tasks.length; i++) _taskTile(i, s.tasks[i], cs),
              const SizedBox(height: 6),
            ],
            Row(children: [
              Expanded(flex: 4, child: _mainButton()),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _editNotes,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Notes', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _navigate,
                  child: const Icon(Icons.navigation_outlined, size: 18),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _mainButton() {
    if (s.isDone) {
      return FilledButton.icon(
          onPressed: null, icon: const Icon(Icons.check_circle), label: const Text('Completed'));
    }
    if (s.isCheckedIn) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: kRed),
        onPressed: _checkOut,
        icon: const Icon(Icons.logout),
        label: const Text('Check Out'),
      );
    }
    final d = _dist;
    final inside = d != null && d <= s.radiusM;
    return FilledButton.icon(
      onPressed: inside ? _checkIn : null,
      icon: const Icon(Icons.login),
      label: Text(
        inside ? 'Check In' : (d == null ? 'Waiting for GPS…' : '${fmtKm(d)} away'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _taskTile(int i, StopTask t, ColorScheme cs) {
    final busy = _uploading == i;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        if (t.requirePhoto)
          CircleAvatar(
            backgroundColor: t.done ? kGreen.withValues(alpha: 0.15) : cs.primaryContainer,
            child: Icon(Icons.photo_camera, color: t.done ? kGreen : cs.primary),
          ),
        if (t.requirePhoto) const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: t.done ? TextDecoration.lineThrough : null)),
            if (t.requirePhoto)
              Text(t.done ? '✓ Photo proof recorded' : 'Photo required • tap to capture',
                  style: TextStyle(color: t.done ? kGreen : cs.primary, fontSize: 12)),
          ]),
        ),
        if (t.requirePhoto && t.photoUrl != null)
          GestureDetector(
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(12),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: InteractiveViewer(
                          panEnabled: true,
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: _buildImageWidget(t.photoUrl!, fit: BoxFit.contain),
                        ),
                      ),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: _buildImageWidget(t.photoUrl!, fit: BoxFit.cover),
                  ),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(4)),
                    ),
                    child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                  ),
                ],
              ),
            ),
          ),
        if (t.requirePhoto)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: busy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                : FilledButton.tonal(
                    style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
                    onPressed: () => _capture(i),
                    child: Text(t.done ? 'Retake' : 'Capture'),
                  ),
          )
        else
          Checkbox(value: t.done, shape: const CircleBorder(), onChanged: (v) => _toggle(i, v ?? false)),
      ]),
    );
  }

  Widget _chip(String text, Color bg, Color fg, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 3)],
          Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11.5)),
        ]),
      );

  Widget _box(Color bg, List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _iconLine(IconData icon, String label, String value,
          {Color? valueColor, Color? iconColor}) =>
      Row(children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
        Flexible(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: valueColor))),
      ]);

  Widget _dotLine(Color c, String label, String value) => Row(children: [
        Icon(Icons.circle, size: 8, color: c),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ]);

  Widget _buildImageWidget(String url, {required BoxFit fit}) {
    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final b64 = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, size: 24),
          ),
        );
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image, size: 24));
      }
    }
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, size: 24),
      ),
    );
  }
}
