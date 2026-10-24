import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/network/supabase_providers.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/filter_labels.dart';

/// A single status post shown in the Updates tab (mirrors `public.statuses`
/// plus whether the signed-in user already viewed it).
class StatusItem {
  const StatusItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.kind,
    required this.mediaUrl,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.viewedByMe,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String kind;
  final String? mediaUrl;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool viewedByMe;
}

final statusesProvider = FutureProvider<List<StatusItem>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final me = ref.watch(authStateProvider).user?.id ?? '';
  if (me.isEmpty) return const <StatusItem>[];

  final rows = await client
      .from('statuses')
      .select(
        'id, author_id, kind, media_url, caption, created_at, expires_at, '
        'author:profiles!author_id(display_name, avatar_url), '
        'viewed:status_views!status_id(viewer_id)',
      )
      .gt('expires_at', DateTime.now().toUtc().toIso8601String())
      .order('created_at', ascending: false)
      .limit(100);
  if (rows.isEmpty) return const <StatusItem>[];

  return rows.map<StatusItem>((r) {
    final viewed =
        (r['viewed'] as List?)?.any((v) => (v as Map?)?['viewer_id'] == me) ??
        false;
    final author = (r['author'] as Map?) ?? const <String, dynamic>{};
    return StatusItem(
      id: r['id'] as String,
      authorId: r['author_id'] as String? ?? '',
      authorName: author['display_name'] as String? ?? 'Unknown',
      authorAvatarUrl: author['avatar_url'] as String?,
      kind: r['kind'] as String? ?? 'text',
      mediaUrl: r['media_url'] as String?,
      caption: r['caption'] as String?,
      createdAt:
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      expiresAt:
          DateTime.tryParse(r['expires_at'] as String? ?? '') ?? DateTime.now(),
      viewedByMe: viewed,
    );
  }).toList();
});

enum _UpdateFilter { all, viewed, notViewed }

class UpdatesTab extends ConsumerWidget {
  const UpdatesTab({super.key, this.query = ''});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statusesProvider);
    final me = ref.watch(ownProfileProvider).valueOrNull;

    return _UpdatesScaffold(async: async, query: query, me: me);
  }
}

class _UpdatesScaffold extends ConsumerStatefulWidget {
  const _UpdatesScaffold({
    required this.async,
    required this.query,
    required this.me,
  });

  final AsyncValue<List<StatusItem>> async;
  final String query;
  final UserProfile? me;

  @override
  ConsumerState<_UpdatesScaffold> createState() => _UpdatesScaffoldState();
}

class _UpdatesScaffoldState extends ConsumerState<_UpdatesScaffold> {
  _UpdateFilter _filter = _UpdateFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = widget.async.valueOrNull ?? const <StatusItem>[];
    final q = widget.query.trim().toLowerCase();

    final filtered = statuses.where((s) {
      if (_filter == _UpdateFilter.viewed && !s.viewedByMe) return false;
      if (_filter == _UpdateFilter.notViewed && s.viewedByMe) return false;
      if (q.isNotEmpty &&
          !(s.authorName.toLowerCase().contains(q) ||
              (s.caption ?? '').toLowerCase().contains(q))) {
        return false;
      }
      return true;
    }).toList();

    final mine = statuses.where((s) => s.authorId == widget.me?.id).toList();
    final recent = filtered.where((s) => s.authorId != widget.me?.id).toList();

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: FilterLabels<_UpdateFilter>(
                  options: const [
                    FilterOption(_UpdateFilter.all, 'All'),
                    FilterOption(_UpdateFilter.viewed, 'Viewed'),
                    FilterOption(_UpdateFilter.notViewed, 'Nonviewed'),
                  ],
                  selected: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        if (widget.async.isLoading && statuses.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.async.hasError && statuses.isEmpty)
          // A read failure is not an empty feed. Rendering "No updates yet"
          // for an RLS denial or a broken query hides real outages.
          SliverFillRemaining(
            child: _UpdatesError(
              onRetry: () => ref.invalidate(statusesProvider),
            ),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(child: _EmptyUpdates(hasAny: statuses.isEmpty))
        else ...[
          if (mine.isNotEmpty || widget.me != null)
            SliverToBoxAdapter(
              child: _MyStatus(me: widget.me, mine: mine),
            ),
          if (recent.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Recent updates',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: recent.length,
              itemBuilder: (context, index) => _StatusTile(item: recent[index]),
            ),
          ],
        ],
      ],
    );
  }
}

class _MyStatus extends ConsumerWidget {
  const _MyStatus({required this.me, required this.mine});

  final UserProfile? me;
  final List<StatusItem> mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _compose(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(profile: me, radius: 26),
                if (mine.isNotEmpty)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CrystalColors.green,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My status',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mine.isEmpty
                        ? 'Tap to add a status update'
                        : '${mine.length} update${mine.length == 1 ? '' : 's'} · '
                              '${mine.where((s) => !s.viewedByMe).length} new',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline, color: theme.colorScheme.onSurface),
          ],
        ),
      ),
    );
  }

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add status'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 700,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'What’s new?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Post')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;
    try {
      await ref.read(supabaseClientProvider).rpc('post_status', params: {
        'p_caption': text,
        'p_media_url': null,
        'p_type': 'text',
        'p_background_color': '#075E54',
        'p_expires_at': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
      });
      ref.invalidate(statusesProvider);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not post status: $error')));
    }
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.item});

  final StatusItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faded = item.viewedByMe;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: faded
                  ? theme.colorScheme.outlineVariant
                  : CrystalColors.green,
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: theme.scaffoldBackgroundColor,
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: UserAvatar(
                profile: UserProfile(
                  id: item.authorId,
                  displayName: item.authorName,
                  avatarUrl: item.authorAvatarUrl,
                ),
                radius: 24,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        item.authorName,
        style: TextStyle(
          fontWeight: faded ? FontWeight.normal : FontWeight.bold,
          color: faded ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Text(
        item.caption?.isNotEmpty == true
            ? item.caption!
            : item.kind == 'image'
            ? 'Photo'
            : 'Text update',
        style: TextStyle(fontSize: 13),
      ),
      trailing: Icon(
        Icons.done_all,
        size: 18,
        color: faded ? theme.colorScheme.outlineVariant : CrystalColors.green,
      ),
    );
  }
}

/// Shown when the status feed genuinely could not be read.
///
/// Deliberately distinct from the empty state: "we could not load your updates"
/// and "you have no updates" are different facts.
class _UpdatesError extends StatelessWidget {
  const _UpdatesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              "Couldn't load updates",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyUpdates extends StatelessWidget {
  const _EmptyUpdates({required this.hasAny});

  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            hasAny ? 'No updates match' : 'No updates yet',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Statuses from your contacts appear here.',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
