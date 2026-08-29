import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../shared/widgets/app_avatar.dart';

class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Updates'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textSecondary),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.surfaceBright,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings', child: Text('Status privacy')),
            ],
          ),
        ],
      ),
      body: FutureBuilder(
        future: client
            .from('statuses')
            .select('*, user:profiles!user_id(full_name, avatar_url)')
            .gt('expires_at', DateTime.now().toIso8601String())
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          final statuses = (snapshot.data as List?) ?? [];

          return ListView(
            children: [
              // My Status
              ListTile(
                leading: Stack(
                  children: [
                    const AppAvatar(
                      name: 'Me',
                      size: 52,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                title: const Text(
                  'My Status',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Tap to add status update',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
                onTap: () => context.push('/status/compose'),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Recent updates',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Other statuses
              if (statuses.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No recent updates from your contacts',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  ),
                )
              else
                ...statuses.map((status) {
                  final user = status['user'] as Map<String, dynamic>?;
                  final name = user?['full_name'] ?? 'Unknown';
                  final avatarUrl = user?['avatar_url'] as String?;
                  final createdAt = status['created_at'] != null
                      ? DateTime.tryParse(status['created_at'])
                      : null;

                  return ListTile(
                    leading: AppAvatar(
                      imageUrl: avatarUrl,
                      name: name,
                      size: 52,
                      hasStory: true,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      createdAt != null ? DateFormat('HH:mm').format(createdAt) : '',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () => context.push('/status/${status['id']}'),
                  );
                }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/status/compose'),
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
