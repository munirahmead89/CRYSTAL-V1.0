import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';

part 'reactions_provider.freezed.dart';

@freezed
class ReactionGroup with _$ReactionGroup {
  const factory ReactionGroup({
    required String emoji,
    required int count,
    @Default(false) bool reactedByMe,
  }) = _ReactionGroup;
}

@freezed
class ReactionsState with _$ReactionsState {
  const factory ReactionsState({
    @Default([]) List<ReactionGroup> groups,
    @Default(false) bool isLoading,
  }) = _ReactionsState;
}

class ReactionsNotifier extends StateNotifier<ReactionsState> {
  final Ref _ref;
  final String messageId;

  ReactionsNotifier(this._ref, this.messageId)
      : super(const ReactionsState()) {
    load();
  }

  Future<void> load() async {
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser!.id;
    try {
      final rows = await client
          .from('message_reactions')
          .select('emoji, user_id')
          .eq('message_id', messageId);
      final Map<String, int> counts = {};
      final Set<String> mine = {};
      for (final r in rows) {
        final emoji = r['emoji'] as String;
        counts[emoji] = (counts[emoji] ?? 0) + 1;
        if (r['user_id'] == userId) mine.add(emoji);
      }
      final groups = counts.entries
          .map((e) => ReactionGroup(
                emoji: e.key,
                count: e.value,
                reactedByMe: mine.contains(e.key),
              ))
          .toList();
      state = state.copyWith(groups: groups, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggle(String emoji) async {
    await _ref.read(supabaseClientProvider).rpc('toggle_reaction',
        params: {'p_message_id': messageId, 'p_emoji': emoji});
    await load();
  }
}

final reactionsProvider = StateNotifierProvider.family<ReactionsNotifier,
    ReactionsState, String>((ref, messageId) => ReactionsNotifier(ref, messageId));
