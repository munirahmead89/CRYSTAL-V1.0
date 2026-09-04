import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../shared/widgets/app_avatar.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calls'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: FutureBuilder(
        future: client
            .from('calls')
            .select('*, caller:profiles!caller_id(full_name, avatar_url)')
            .order('started_at', ascending: false)
            .limit(50),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final calls = (snapshot.data as List?) ?? [];

          if (calls.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_outlined, size: 80, color: AppColors.textTertiary.withAlpha(80)),
                  const SizedBox(height: 16),
                  const Text(
                    'No calls yet',
                    style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your call history will appear here',
                    style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: calls.length,
            itemBuilder: (context, index) {
              final call = calls[index];
              final caller = call['caller'] as Map<String, dynamic>?;
              final callerName = caller?['full_name'] ?? 'Unknown';
              final avatarUrl = caller?['avatar_url'] as String?;
              final callType = call['type'] ?? 'audio';
              final status = call['status'] ?? 'missed';
              final startedAt = call['started_at'] != null
                  ? DateTime.tryParse(call['started_at'])
                  : null;
              final duration = call['duration'] as int?;

              return ListTile(
                leading: AppAvatar(
                  imageUrl: avatarUrl,
                  name: callerName,
                  size: 48,
                ),
                title: Text(
                  callerName,
                  style: TextStyle(
                    color: status == 'missed' ? AppColors.error : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      callType == 'video' ? Icons.videocam : Icons.phone,
                      size: 14,
                      color: status == 'missed' ? AppColors.error : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status == 'missed' ? 'Missed' : status,
                      style: TextStyle(
                        fontSize: 13,
                        color: status == 'missed' ? AppColors.error : AppColors.textTertiary,
                      ),
                    ),
                    if (startedAt != null) ...[
                      const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                      Text(
                        DateFormat('dd/MM HH:mm').format(startedAt),
                        style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    callType == 'video' ? Icons.videocam : Icons.phone,
                    color: AppColors.primary,
                  ),
                  onPressed: () {},
                ),
              );
            },
          );
        },
      ),
    );
  }
}
