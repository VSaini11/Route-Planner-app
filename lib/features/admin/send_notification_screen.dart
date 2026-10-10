import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers.dart';

class SendNotificationScreen extends ConsumerStatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  ConsumerState<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends ConsumerState<SendNotificationScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedWorkerUid; // null means "All Workers"
  bool _sendLater = false;
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay _scheduledTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 15)));
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    DateTime? sendAt;
    if (_sendLater) {
      sendAt = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );

      if (sendAt.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scheduled delivery time must be in the future.'),
            backgroundColor: kAmber,
          ),
        );
        return;
      }
    }

    setState(() => _sending = true);
    try {
      await ref.read(routeRepoProvider).sendCustomNotification(
            toUid: _selectedWorkerUid,
            title: _titleCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            sendAt: sendAt,
          );

      if (!mounted) return;
      _titleCtrl.clear();
      _bodyCtrl.clear();
      setState(() => _sendLater = false);

      final msg = sendAt == null
          ? '✓ Push broadcast notification delivered immediately!'
          : '✓ Notification scheduled for ${DateFormat('EEE, d MMM yyyy • hh:mm a').format(sendAt)}!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: kGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(workersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D2E) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: isDark ? 0.1 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Broadcast Alert Hub',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Transmit instant field alerts or schedule reminders',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            workersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading workers: $e'),
              data: (list) {
                return DropdownButtonFormField<String?>(
                  initialValue: _selectedWorkerUid,
                  decoration: const InputDecoration(
                    labelText: 'Target Recipients',
                    prefixIcon: Icon(Icons.people_alt_outlined, size: 20),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('📢 Broadcast to All Field Workers', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    for (final w in list)
                      DropdownMenuItem<String?>(
                        value: w.uid,
                        child: Text('👤 ${w.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                  ],
                  onChanged: (val) => setState(() => _selectedWorkerUid = val),
                );
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Announcement Title',
                hintText: 'e.g. Schedule Update or Priority Visit',
                prefixIcon: Icon(Icons.title_rounded, size: 20),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message Content',
                hintText: 'Detailed instructions for field staff...',
                prefixIcon: Icon(Icons.message_outlined, size: 20),
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter message content' : null,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D2E) : Colors.white,
                borderRadius: BorderRadius.circular(18),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: kAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.schedule_rounded, size: 18, color: kAmber),
                          ),
                          const SizedBox(width: 10),
                          const Text('Schedule Timed Delivery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        ],
                      ),
                      Switch(
                        value: _sendLater,
                        activeColor: kPrimary,
                        onChanged: (val) => setState(() => _sendLater = val),
                      ),
                    ],
                  ),
                  if (_sendLater) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_month_outlined, size: 16),
                            label: Text(
                              DateFormat('d MMM yyyy').format(_scheduledDate),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _scheduledDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) setState(() => _scheduledDate = d);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_rounded, size: 16),
                            label: Text(
                              _scheduledTime.format(context),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: _scheduledTime,
                              );
                              if (t != null) setState(() => _scheduledTime = t);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Will be dispatched automatically on ${DateFormat('d MMM, yyyy').format(_scheduledDate)} at ${_scheduledTime.format(context)}',
                      style: const TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_sendLater ? Icons.schedule_send_rounded : Icons.send_rounded, color: Colors.white, size: 18),
                label: Text(
                  _sending
                      ? 'Transmitting Broadcast...'
                      : _sendLater
                          ? 'Schedule Transmission'
                          : 'Transmit Push Alert Now',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
