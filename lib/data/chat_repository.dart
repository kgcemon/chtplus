import '../core/api/api_client.dart';
import '../core/utils/json.dart';
import '../models/engagement.dart';

/// Messages older than the server's retention window disappear on their own,
/// which is why an empty thread is normal rather than an error.
class ChatRepository {
  const ChatRepository(this._api);

  final ApiClient _api;

  Future<List<Conversation>> inbox() async {
    final body = await _api.get('/api/chat/conversations');
    return parseList(body, Conversation.fromJson);
  }

  /// Finds or creates the conversation with [userId]. Fails with
  /// `chat_disabled` when that person has messaging turned off.
  Future<String> startConversation(String userId) async {
    final body = await _api.post('/api/chat/conversations', body: {'userId': userId});
    return body is Map<String, dynamic> ? body.str('conversationId') : '';
  }

  /// Loads a thread. With [after] set, only messages newer than that id come
  /// back, which is what the polling refresh uses.
  Future<ChatThread> messages(String conversationId, {int? after}) async {
    final body = await _api.get(
      '/api/chat/conversations/$conversationId/messages',
      query: {if (after != null) 'after': after},
    );
    return ChatThread.fromJson(body is Map<String, dynamic> ? body : const {});
  }

  Future<ChatMessage> send(String conversationId, String text) async {
    final body = await _api.post(
      '/api/chat/conversations/$conversationId/messages',
      body: {'body': text},
    );
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return ChatMessage.fromJson(map.mapOrNull('message') ?? const {});
  }

  Future<int> unreadCount() async {
    final body = await _api.get('/api/me/chat-unread-count');
    return body is Map<String, dynamic> ? body.intOr('count') : 0;
  }

  Future<({bool chatEnabled, bool noticeSeen})> settings() async {
    final body = await _api.get('/api/me/chat-settings');
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return (
      chatEnabled: map.flag('chatEnabled'),
      noticeSeen: map.flag('chatNoticeSeen'),
    );
  }

  Future<({bool chatEnabled, bool noticeSeen})> updateSettings({
    bool? chatEnabled,
    bool? noticeSeen,
  }) async {
    final body = await _api.patch('/api/me/chat-settings', body: {
      if (chatEnabled != null) 'chatEnabled': chatEnabled,
      if (noticeSeen == true) 'noticeSeen': true,
    });
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    return (
      chatEnabled: map.flag('chatEnabled'),
      noticeSeen: map.flag('chatNoticeSeen'),
    );
  }
}
