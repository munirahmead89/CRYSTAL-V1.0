import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';

class StatusComposeScreen extends ConsumerStatefulWidget {
  const StatusComposeScreen({super.key});

  @override
  ConsumerState<StatusComposeScreen> createState() => _StatusComposeScreenState();
}

class _StatusComposeScreenState extends ConsumerState<StatusComposeScreen> {
  final _textController = TextEditingController();
  String _selectedBgColor = '#005C4B';
  String _selectedTextColor = '#FFFFFF';
  File? _mediaFile;
  String? _mediaType;

  final _bgColors = ['#005C4B', '#128C7E', '#075E54', '#25D366', '#EA4335', '#F7B928', '#7C4DFF'];
  final _textColors = ['#FFFFFF', '#000000', '#1A1A1A'];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _parseColor(_selectedBgColor),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    onPressed: _pickMedia,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _mediaFile != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_mediaType == 'image')
                          Image.file(_mediaFile!, fit: BoxFit.cover)
                        else
                          const Center(
                            child: Icon(Icons.videocam, color: Colors.white, size: 60),
                          ),
                        if (_textController.text.isNotEmpty)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _textController.text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _parseColor(_selectedTextColor),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: TextField(
                          controller: _textController,
                          textAlign: TextAlign.center,
                          maxLines: 5,
                          style: TextStyle(
                            color: _parseColor(_selectedTextColor),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Type a status',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 24,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
            ),

            // Color picker
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // BG colors
                  ..._bgColors.map((c) => _colorDot(c, () {
                        setState(() => _selectedBgColor = c);
                      })),
                  const SizedBox(width: 16),
                  // Text colors
                  ..._textColors.map((c) => _colorDot(c, () {
                        setState(() => _selectedTextColor = c);
                      })),
                ],
              ),
            ),

            // Send button
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppButton(
                label: 'Send Status',
                icon: Icons.send,
                onPressed: _textController.text.isNotEmpty || _mediaFile != null
                    ? _postStatus
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(String hexColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: _parseColor(hexColor),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(100), width: 2),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _mediaFile = File(image.path);
        _mediaType = 'image';
      });
    }
  }

  Future<void> _postStatus() async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser!.id;

    try {
      String? mediaUrl;
      if (_mediaFile != null) {
        // Upload media
        final ext = _mediaFile!.path.split('.').last;
        final path = '$userId/status-${DateTime.now().millisecondsSinceEpoch}.$ext';
        await client.storage.from('media').upload(path, _mediaFile!);
        mediaUrl = 'media/$path';
      }

      await client.from('statuses').insert({
        'user_id': userId,
        'content': _textController.text.isNotEmpty ? _textController.text : null,
        'media_url': mediaUrl,
        'media_type': _mediaType ?? 'text',
        'background_color': _selectedBgColor,
        'text_color': _selectedTextColor,
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status posted!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
