import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';

class CreatePollSheet extends ConsumerStatefulWidget {
  final String chatId;
  const CreatePollSheet({super.key, required this.chatId});

  @override
  ConsumerState<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<CreatePollSheet> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _isAnonymous = true;
  bool _isMultipleChoice = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 12) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _createPoll() async {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a question and at least 2 options')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('create_poll', params: {
        'p_chat_id': widget.chatId,
        'p_question': question,
        'p_options': options,
        'p_is_anonymous': _isAnonymous,
        'p_is_multiple_choice': _isMultipleChoice,
      });

      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
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
                  'Create Poll',
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
              controller: _questionController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Ask a question...',
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[index],
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Option ${index + 1}',
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          prefixIcon: Icon(
                            Icons.circle_outlined,
                            color: AppColors.textTertiary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error, size: 20),
                        onPressed: () => _removeOption(index),
                      ),
                  ],
                ),
              );
            }),
            if (_optionControllers.length < 12)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add, color: AppColors.primary),
                label: const Text('Add option',
                    style: TextStyle(color: AppColors.primary)),
              ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Anonymous',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('Hide who voted for what',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Allow multiple choices',
                  style: TextStyle(color: AppColors.textPrimary)),
              value: _isMultipleChoice,
              onChanged: (v) => setState(() => _isMultipleChoice = v),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPoll,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create Poll'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
