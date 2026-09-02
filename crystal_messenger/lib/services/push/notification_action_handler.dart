import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  Logger.info('NotificationAction', 'Background action triggered: ${notificationResponse.actionId}');
  
  if (notificationResponse.actionId == 'reply') {
    final text = notificationResponse.input;
    final chatId = notificationResponse.payload;
    if (text != null && text.isNotEmpty && chatId != null) {
      await _sendReplyBackground(chatId, text);
    }
  } else if (notificationResponse.actionId == 'mark_read') {
    final chatId = notificationResponse.payload;
    if (chatId != null) {
      await _markAsReadBackground(chatId);
    }
  }
}

Future<void> _sendReplyBackground(String chatId, String content) async {
  try {
    await Supabase.initialize(
      url: ApiConstants.supabaseUrl,
      publishableKey: ApiConstants.supabaseAnonKey,
    );
    
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    await client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': user.id,
      'content': content,
      'message_type': 'text',
      'created_at': DateTime.now().toIso8601String(),
    });
    Logger.info('NotificationAction', 'Reply sent from background');
  } catch (e) {
    Logger.error('NotificationAction', 'Failed to send reply', e);
  }
}

Future<void> _markAsReadBackground(String chatId) async {
  try {
    await Supabase.initialize(
      url: ApiConstants.supabaseUrl,
      publishableKey: ApiConstants.supabaseAnonKey,
    );
    
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    await client.from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('chat_id', chatId)
        .isFilter('read_at', null)
        .neq('sender_id', user.id);
    
    Logger.info('NotificationAction', 'Marked as read from background');
  } catch (e) {
    Logger.error('NotificationAction', 'Failed to mark as read', e);
  }
}
