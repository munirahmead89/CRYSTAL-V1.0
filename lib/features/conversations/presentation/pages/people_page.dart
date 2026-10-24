import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../providers/chat_providers.dart';

class PeoplePage extends ConsumerStatefulWidget {
  const PeoplePage({super.key});

  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage> {
  final _search = TextEditingController();
  final _phone = TextEditingController();
  Timer? _debounce;
  bool _adding = false;
  bool _opening = false;

  /// Normalizes a raw phone number to the canonical digits-only form matching
  /// what is stored in the backend (e.g. "923240941091" not "+923240941091").
  /// Uses the same logic as phone_normalizer.canonicalPhoneDigits so lookups
  /// always find the profile regardless of how the user typed the number.
  static String _normalizePhone(String raw) {
    final s = raw.trim()
        .replaceAll(RegExp(r'[\s\-().]'), '')
        .replaceAll(RegExp(r'^\+'), '');
    // Prepend '92' (Crystal's default country code) if the number starts with '0'
    if (s.startsWith('0')) return '92${s.substring(1)}';
    return s;
  }

  static final _validPhone = RegExp(r'^\d{7,15}$');

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(peopleProvider.notifier).search(value);
    });
  }

  /// Opens (or creates then opens) a direct chat with [peer]:
  ///
  /// 1. Reuses an already-cached conversation with the same peer, if one exists.
  /// 2. Otherwise asks the server for a thread (the `get_or_create_direct_conversation`
  ///    RPC is race-safe and unique-index backed, so double-taps can't create
  ///    duplicate rooms) and returns its id.
  /// 3. Mirrors the room into local SQLite/Drift so Chats is consistent offline
  ///    and the new thread is pinned at the top immediately.
  Future<void> _openConversation(UserProfile peer) async {
    if (_opening) return;
    _opening = true;
    try {
      final store = ref.read(localStoreProvider);
      final repo = ref.read(conversationsRepositoryProvider);

      // 1) Existing thread? (cached locally from a previous sync/pass).
      //    Otherwise 2) find-or-create on the server.
      final conversationId =
          await store.findDirectConversationWith(peer.id) ??
          await repo.getOrCreateDirectConversation(peerId: peer.id);
      if (conversationId.isEmpty) {
        throw StateError('No conversation could be found or created');
      }

      // 3) Mirror the conversation into Drift (peer + room) so the thread is
      //    available offline and shows at the top of the chat list.
      await store.upsertProfile(peer);
      await store.upsertConversation(
        ConversationSummary(
          id: conversationId,
          isGroup: false,
          peer: peer,
          peers: [peer],
          displayName: peer.displayName,
        ),
      );
      if (!mounted) return;
      // Full reload (not silent) so the new conversation is immediately pinned
      // at the top of the chat list when the user returns to the home screen.
      ref.read(chatListProvider.notifier).load();
      context.go('/chat/$conversationId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not open chat: $e'),
              backgroundColor: CrystalColors.green,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _addByPhone(String rawPhone) async {
    if (_adding) return;
    final phone = _normalizePhone(rawPhone);
    if (!_validPhone.hasMatch(phone)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Enter a valid phone number with country code (e.g. +1 555 123 4567).',
            ),
            backgroundColor: CrystalColors.green,
          ),
        );
      return;
    }
    setState(() => _adding = true);
    try {
      final profile = await ref.read(peopleProvider.notifier).addByPhone(phone);
      if (!mounted) return;
      if (profile != null && profile.id.isNotEmpty) {
        _openConversation(profile);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No Crystal account for that phone number.'),
            backgroundColor: CrystalColors.green,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _scanQr() async {
    final peer = await context.push<UserProfile>('/scan');
    if (peer == null || !mounted) return;
    await ref.read(localStoreProvider).upsertProfile(peer);
    ref.read(chatListProvider.notifier).load(silent: true);
    await _openConversation(peer);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(peopleProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find people'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR code',
            onPressed: _scanQr,
          ),
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'New group',
            onPressed: () => context.push('/group'),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync contacts',
            onPressed: () => ref.read(peopleProvider.notifier).syncContacts(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Search by name or phone number',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Flexible(
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    onSubmitted: _addByPhone,
                    decoration: const InputDecoration(
                      hintText: 'Add by phone number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: _adding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CrystalColors.black,
                          ),
                        )
                      : const Icon(Icons.person_add_alt),
                  tooltip: 'Add',
                  onPressed: _adding ? null : () => _addByPhone(_phone.text),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: _search.text.trim().isNotEmpty
                  ? () => const Center(child: CircularProgressIndicator())
                  : () => const SizedBox.shrink(),
              error: (e, _) => Center(child: Text('Lookup failed: $e')),
              data: (results) {
                if (_search.text.trim().isEmpty) {
                  return const _SearchHint();
                }
                if (results.isEmpty) return const _NoResults();
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final peer = results[index];
                    return ListTile(
                      leading: UserAvatar(profile: peer, radius: 22),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              peer.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (peer.isVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedBadge(),
                          ],
                        ],
                      ),
                      subtitle: Text(peer.handle),
                      trailing: _opening
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              tooltip: 'Open chat',
                              onPressed: () => _openConversation(peer),
                            ),
                      onTap: () => _openConversation(peer),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 56, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'Search by name or phone — or scan a QR code — sync device contacts',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No people found.'));
  }
}
