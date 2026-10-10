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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dist = _dist;
    final doneTasks = s.tasks.where((t) => t.done).length;

    final statusColor = s.isDone ? kGreen : (s.isCheckedIn ? kPrimary : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)));
    final statusBg = s.isDone
        ? kGreen.withValues(alpha: 0.15)
        : (s.isCheckedIn ? kPrimary.withValues(alpha: 0.15) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)));
    final statusLabel = s.isDone ? 'COMPLETED' : (s.isCheckedIn ? 'IN PROGRESS' : 'PENDING');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: s.isCheckedIn
              ? kPrimary.withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: s.isCheckedIn ? 1.5 : 1,
        ),
        boxShadow: [
          if (s.isCheckedIn)
            BoxShadow(
              color: kPrimary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary.withValues(alpha: 0.15), kAccent.withValues(alpha: 0.15)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'STOP #${widget.number}',
                style: const TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 22,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            s.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(
                '${s.radiusM.round()}m radius (${dist == null ? '--' : fmtKm(dist)})',
                isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                icon: Icons.gps_fixed_rounded,
              ),
              const SizedBox(width: 8),
              _chip(
                'Target: ₹${s.target.round()}',
                kAmber.withValues(alpha: 0.12),
                const Color(0xFFD97706),
                icon: Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: _box(
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                [
                  _iconLine(Icons.near_me_outlined, 'Transit', widget.number == 1 ? 'Start point' : 'Next stop'),
                  const SizedBox(height: 6),
                  _iconLine(
                    Icons.route_outlined,
                    'Distance',
                    widget.legMeters == null ? '--' : fmtKm(widget.legMeters!),
                    valueColor: kPrimary,
                    iconColor: kPrimary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _box(
                kGreen.withValues(alpha: isDark ? 0.08 : 0.06),
                [
                  _dotLine(kGreen, 'IN', fmtTime(s.checkInAt)),
                  const SizedBox(height: 4),
                  _dotLine(kRed, 'OUT', fmtTime(s.checkOutAt)),
                  const SizedBox(height: 4),
                  _iconLine(Icons.timer_outlined, 'Worked',
                      s.worked == null ? '--' : fmtDuration(s.worked!)),
                ],
              ),
            ),
          ]),
          if (s.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _box(
              kAmber.withValues(alpha: isDark ? 0.12 : 0.08),
              [
                const Row(children: [
                  Icon(Icons.notes_rounded, color: Color(0xFFD97706), size: 15),
                  SizedBox(width: 6),
                  Text('Visit Brief / Instructions:',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD97706), fontSize: 11.5)),
                ]),
                const SizedBox(height: 4),
                Text(s.notes,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    )),
              ],
            ),
          ],
          if (_expanded) ...[
            const SizedBox(height: 14),
            if (s.tasks.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Checklist Tasks ($doneTasks/${s.tasks.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  if (doneTasks == s.tasks.length && s.tasks.isNotEmpty)
                    const Text('All completed ✓',
                        style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 11.5)),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < s.tasks.length; i++) _taskTile(i, s.tasks[i], cs),
              const SizedBox(height: 8),
            ],
            Row(children: [
              Expanded(flex: 5, child: _mainButton()),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: _editNotes,
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Notes', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  tooltip: 'Google Maps Navigation',
                  onPressed: _navigate,
                  icon: const Icon(Icons.navigation_rounded, color: kPrimary, size: 20),
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
        style: FilledButton.styleFrom(backgroundColor: kGreen.withValues(alpha: 0.15)),
        onPressed: null,
        icon: const Icon(Icons.check_circle_rounded, color: kGreen),
        label: const Text('Completed', style: TextStyle(color: kGreen, fontWeight: FontWeight.w800)),
      );
    }
    if (s.isCheckedIn) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: kRed),
        onPressed: _checkOut,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Check Out'),
      );
    }
    final d = _dist;
    final inside = d != null && d <= s.radiusM;
    return FilledButton.icon(
      onPressed: inside ? _checkIn : null,
      icon: const Icon(Icons.login_rounded),
      label: Text(
        inside ? 'Check In Now' : (d == null ? 'Acquiring GPS…' : '${fmtKm(d)} away'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _taskTile(int i, StopTask t, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busy = _uploading == i;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(children: [
        if (t.requirePhoto)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.done ? kGreen.withValues(alpha: 0.15) : kPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.photo_camera_rounded, color: t.done ? kGreen : kPrimary, size: 20),
          ),
        if (t.requirePhoto) const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    decoration: t.done ? TextDecoration.lineThrough : null)),
            if (t.requirePhoto)
              Text(t.done ? '✓ Verified photo recorded' : 'Photo verification required',
                  style: TextStyle(color: t.done ? kGreen : kPrimary, fontSize: 11.5, fontWeight: FontWeight.w600)),
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
                        borderRadius: BorderRadius.circular(20),
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
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
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
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => _capture(i),
                    child: Text(t.done ? 'Retake' : 'Capture', style: const TextStyle(fontSize: 12)),
                  ),
          )
        else
          Checkbox(
            value: t.done,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            activeColor: kPrimary,
            onChanged: (v) => _toggle(i, v ?? false),
          ),
      ]),
    );
  }

  Widget _chip(String text, Color bg, Color fg, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11.5)),
        ]),
      );

  Widget _box(Color bg, List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _iconLine(IconData icon, String label, String value,
          {Color? valueColor, Color? iconColor}) =>
      Row(children: [
        Icon(icon, size: 14, color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(width: 4),
        Flexible(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: valueColor))),
      ]);

  Widget _dotLine(Color c, String label, String value) => Row(children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11.5)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11.5)),
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
