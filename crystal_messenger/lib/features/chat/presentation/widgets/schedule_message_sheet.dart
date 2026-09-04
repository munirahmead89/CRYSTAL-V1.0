import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';

class ScheduleMessageSheet extends ConsumerStatefulWidget {
  final String chatId;
  final String initialContent;
  final String messageType;
  const ScheduleMessageSheet({
    super.key,
    required this.chatId,
    this.initialContent = '',
    this.messageType = 'text',
  });

  @override
  ConsumerState<ScheduleMessageSheet> createState() => _ScheduleMessageSheetState();
}

class _ScheduleMessageSheetState extends ConsumerState<ScheduleMessageSheet> {
  late TextEditingController _contentController;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;
  bool _showScheduled = false;
  List<Map<String, dynamic>> _scheduledMessages = [];

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _loadScheduledMessages();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadScheduledMessages() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final result = await client.rpc('get_scheduled_messages', params: {
        'p_chat_id': widget.chatId,
      });
      setState(() {
        _scheduledMessages = (result as List?)?.cast<Map<String, dynamic>>() ?? [];
      });
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surfaceBright,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surfaceBright,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _scheduleMessage() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a message')),
      );
      return;
    }

    final scheduledFor = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (scheduledFor.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule time must be in the future')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('schedule_message', params: {
        'p_chat_id': widget.chatId,
        'p_content': content,
        'p_message_type': widget.messageType,
        'p_scheduled_for': scheduledFor.toUtc().toIso8601String(),
      });

      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message scheduled for ${DateFormat('MMM d, h:mm a').format(scheduledFor)}')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelScheduled(String messageId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('cancel_scheduled_message', params: {
        'p_message_id': messageId,
      });
      await _loadScheduledMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled message cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Schedule Message',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _dateTimeButton(
                    label: DateFormat('MMM d, yyyy').format(_selectedDate),
                    icon: Icons.calendar_today,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateTimeButton(
                    label: _selectedTime.format(context),
                    icon: Icons.access_time,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Will send at ${DateFormat('MMM d, h:mm a').format(scheduledDateTime)}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _scheduleMessage,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Schedule Message'),
              ),
            ),
            if (_scheduledMessages.isNotEmpty) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => setState(() => _showScheduled = !_showScheduled),
                child: Row(
                  children: [
                    Text(
                      'Scheduled (${_scheduledMessages.length})',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _showScheduled
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              if (_showScheduled) ...[
                const SizedBox(height: 8),
                ..._scheduledMessages.map((msg) {
                  final scheduledFor = DateTime.tryParse(msg['scheduled_for'] ?? '');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      msg['content'] ?? '',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      scheduledFor != null
                          ? DateFormat('MMM d, h:mm a').format(scheduledFor)
                          : '',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.cancel_outlined,
                          color: AppColors.error, size: 20),
                      onPressed: () => _cancelScheduled(msg['id']),
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _dateTimeButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
