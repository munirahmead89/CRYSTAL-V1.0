import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/message_provider.dart';
import '../../data/repositories/media_repository.dart';

class MediaPickerSheet extends ConsumerWidget {
  final String chatId;
  final String? replyToId;
  const MediaPickerSheet({super.key, required this.chatId, this.replyToId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Option(icon: Icons.camera_alt, label: 'Camera', color: Colors.pink, onTap: () => _pick(ImageSource.camera, 'image', context, ref)),
                _Option(icon: Icons.photo, label: 'Gallery', color: Colors.purple, onTap: () => _pick(ImageSource.gallery, 'image', context, ref)),
                _Option(icon: Icons.videocam, label: 'Video', color: Colors.red, onTap: () => _pick(ImageSource.gallery, 'video', context, ref)),
                _Option(icon: Icons.insert_drive_file, label: 'Document', color: Colors.blue, onTap: () => _pickFile(context, ref)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(ImageSource source, String type, BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final XFile? file = type == 'video'
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source, maxWidth: 1920, imageQuality: 80);
    if (file == null) return;
    Navigator.pop(context);
    await _upload(File(file.path), type == 'video' ? 'video' : 'image', ref);
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    Navigator.pop(context);
    await _upload(File(path), 'file', ref, fileName: result.files.first.name);
  }

  Future<void> _upload(File file, String messageType, WidgetRef ref, {String? fileName}) async {
    final repo = ref.read(mediaRepositoryProvider);
    final notifier = ref.read(messageListProvider(chatId).notifier);
    String reference;
    Map<String, dynamic>? metadata;
    if (messageType == 'audio') {
      reference = await repo.uploadVoiceNote(file);
    } else if (messageType == 'file') {
      reference = await repo.uploadFile(file);
      metadata = {'file_name': fileName ?? file.path.split('/').last, 'file_size': await file.length()};
    } else {
      reference = await repo.uploadMedia(file);
    }
    await notifier.sendMessage(content: reference, messageType: messageType, replyToId: replyToId, metadata: metadata);
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Option({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundColor: color.withAlpha(40), child: Icon(icon, color: color)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
