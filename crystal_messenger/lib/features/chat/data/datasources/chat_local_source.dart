import '../../../../database/app_database.dart';

class ChatLocalSource {
  final AppDatabase _database;

  ChatLocalSource(this._database);

  Future<List<Map<String, dynamic>>> getAllChats() async {
    final chats = await _database.getAllChats();
    return chats.map((c) => {
      'id': c.id,
      'type': c.type,
      'name': c.name,
      'avatar_url': c.avatarUrl,
      'last_message_content': c.lastMessageContent,
      'last_message_at': c.lastMessageAt?.toIso8601String(),
      'unread_count': c.unreadCount,
    }).toList();
  }

  Future<void> upsertChat(Map<String, dynamic> chat) async {
    await _database.upsertChat(ChatsTableCompanion.insert(
      id: chat['id'],
      type: chat['type'] ?? 'direct',
      name: Value(chat['name']),
      avatarUrl: Value(chat['avatar_url']),
      lastMessageContent: Value(chat['last_message_content']),
      lastMessageAt: chat['last_message_at'] != null
          ? Value(DateTime.parse(chat['last_message_at']))
          : const Value.absent(),
      unreadCount: Value(chat['unread_count'] ?? 0),
    ));
  }

  Future<void> deleteChat(String id) => _database.deleteChat(id);

  Future<void> clearChatMessages(String chatId) =>
      _database.clearChatMessages(chatId);
}
