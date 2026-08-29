import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../services/media/media_url_resolver.dart';
import '../../../shared/widgets/app_avatar.dart';

class StatusViewerScreen extends ConsumerStatefulWidget {
  final String statusId;
  const StatusViewerScreen({super.key, required this.statusId});

  @override
  ConsumerState<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends ConsumerState<StatusViewerScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final client = ref.read(supabaseClientProvider);
    final response = await client
        .from('statuses')
        .select('*, user:profiles!user_id(full_name, avatar_url)')
        .eq('id', widget.statusId)
        .maybeSingle();

    if (response != null && mounted) {
      // Record view
      await client.rpc('record_status_view', params: {
        'p_status_id': widget.statusId,
      });

      setState(() {
        _status = response;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_status == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, leading: const BackButton(color: Colors.white)),
        body: const Center(
          child: Text('Status not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final user = _status!['user'] as Map<String, dynamic>?;
    final userName = user?['full_name'] ?? 'Unknown';
    final avatarUrl = user?['avatar_url'] as String?;
    final content = _status!['content'] as String?;
    final mediaUrl = _status!['media_url'] as String?;
    final bgColor = _status!['background_color'] as String? ?? '#005C4B';
    final textColor = _status!['text_color'] as String? ?? '#FFFFFF';
    final mediaType = _status!['media_type'] as String?;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        title: Row(
          children: [
            AppAvatar(imageUrl: avatarUrl, name: userName, size: 36),
            const SizedBox(width: 12),
            Text(userName, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
      body: Center(
        child: mediaType == 'text' || (mediaUrl == null)
            ? Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _parseColor(bgColor),
                ),
                child: Center(
                  child: Text(
                    content ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _parseColor(textColor),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : _MediaStatusView(mediaUrl: mediaUrl, resolver: ref.watch(mediaUrlResolverProvider)),
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class _MediaStatusView extends StatelessWidget {
  final String mediaUrl;
  final MediaUrlResolver resolver;

  const _MediaStatusView({required this.mediaUrl, required this.resolver});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: resolver.resolve(mediaUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(color: Colors.white);
        }
        if (snapshot.hasData) {
          return CachedNetworkImage(
            imageUrl: snapshot.data!,
            fit: BoxFit.contain,
            placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
            errorWidget: (_, __, ___) => const Icon(Icons.error, color: Colors.white),
          );
        }
        return const Icon(Icons.error, color: Colors.white);
      },
    );
  }
}
