import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';

class PollResultsWidget extends ConsumerStatefulWidget {
  final String pollId;
  const PollResultsWidget({super.key, required this.pollId});

  @override
  ConsumerState<PollResultsWidget> createState() => _PollResultsWidgetState();
}

class _PollResultsWidgetState extends ConsumerState<PollResultsWidget> {
  Map<String, dynamic>? _results;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final result = await client.rpc('get_poll_results', params: {
        'p_poll_id': widget.pollId,
      });
      setState(() {
        _results = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _vote(String optionId) async {
    try {
      HapticFeedback.lightImpact();
      final client = ref.read(supabaseClientProvider);
      await client.rpc('vote_poll', params: {
        'p_poll_id': widget.pollId,
        'p_option_id': optionId,
      });
      await _loadResults();
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
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_results == null) return const SizedBox.shrink();

    final poll = _results!['poll'] as Map<String, dynamic>;
    final options = (_results!['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalVotes = _results!['total_votes'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll['question'] ?? '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...options.map((opt) {
            final voteCount = opt['vote_count'] as int? ?? 0;
            final percentage = totalVotes > 0 ? (voteCount / totalVotes * 100) : 0.0;
            final hasVoted = opt['has_voted'] as bool? ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _vote(opt['id']),
                child: Container(
                  decoration: BoxDecoration(
                    color: hasVoted ? AppColors.primary.withAlpha(30) : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasVoted ? AppColors.primary : AppColors.border,
                      width: hasVoted ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (percentage > 0)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percentage / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            if (hasVoted)
                              const Icon(Icons.check_circle,
                                  color: AppColors.primary, size: 18)
                            else
                              const Icon(Icons.circle_outlined,
                                  color: AppColors.textTertiary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                opt['text'] ?? '',
                                style: TextStyle(
                                  color: hasVoted
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: hasVoted
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: hasVoted
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
              if (poll['is_anonymous'] == true) ...[
                const SizedBox(width: 8),
                const Icon(Icons.visibility_off, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                const Text('Anonymous',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
