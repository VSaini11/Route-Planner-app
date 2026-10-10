import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

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
            content: Text('Scheduled time must be in the future.'),
            backgroundColor: Colors.orange,
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
          ? 'Push notification queued and sent immediately!'
          : 'Notification scheduled for ${DateFormat('EEE, d MMM yyyy • hh:mm a').format(sendAt)}!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(workersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.campaign_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          'Broadcast Push Notification',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Send custom announcements, alerts, or instructions directly to your workers\' phone lock screens.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
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
                    labelText: 'Target Audience',
                    prefixIcon: Icon(Icons.people_alt_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('📢 All Workers (Broadcast)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    for (final w in list)
                      DropdownMenuItem<String?>(
                        value: w.uid,
                        child: Text('👤 ${w.name}'),
                      ),
                  ],
                  onChanged: (val) => setState(() => _selectedWorkerUid = val),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Notification Title',
                hintText: 'e.g. Urgent Meeting / Route Update',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message Body',
                hintText: 'Type your message details here...',
                prefixIcon: Icon(Icons.message_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter message content' : null,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.schedule, size: 20),
                            SizedBox(width: 8),
                            Text('Schedule Delivery Time', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Switch(
                          value: _sendLater,
                          onChanged: (val) => setState(() => _sendLater = val),
                        ),
                      ],
                    ),
                    if (_sendLater) ...[
                      const Divider(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: Text(
                                DateFormat('d MMM yyyy').format(_scheduledDate),
                                style: const TextStyle(fontSize: 13),
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
                              icon: const Icon(Icons.access_time, size: 18),
                              label: Text(
                                _scheduledTime.format(context),
                                style: const TextStyle(fontSize: 13),
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
                      const SizedBox(height: 4),
                      Text(
                        'Will be delivered at ${DateFormat('d MMM, yyyy').format(_scheduledDate)} at ${_scheduledTime.format(context)}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_sendLater ? Icons.schedule_send_rounded : Icons.send_rounded),
              label: Text(
                _sending
                    ? 'Processing...'
                    : _sendLater
                        ? 'Schedule Notification'
                        : 'Send Push Notification Now',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
