import '../core/utils/json.dart';

class Review {
  const Review({
    required this.id,
    required this.rating,
    this.reviewerName,
    this.reviewerUserId,
    this.reviewerBlueBadge = false,
    this.comment,
    this.date,
    this.createdAt,
    this.loveCount = 0,
    this.lovedByMe = false,
    this.replyCount = 0,
    this.targetType,
    this.targetId,
  });

  final int id;
  final int rating;
  final String? reviewerName;
  final String? reviewerUserId;
  final bool reviewerBlueBadge;
  final String? comment;
  final String? date;
  final DateTime? createdAt;
  final int loveCount;
  final bool lovedByMe;
  final int replyCount;
  final String? targetType;
  final String? targetId;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json.intOr('id'),
        rating: json.intOr('rating'),
        reviewerName: json.strOrNull('reviewerName'),
        reviewerUserId: json.strOrNull('reviewerUserId'),
        reviewerBlueBadge: json.flag('reviewerBlueBadge'),
        comment: json.strOrNull('comment'),
        date: json.strOrNull('date'),
        createdAt: json.date('createdAt'),
        loveCount: json.intOr('loveCount'),
        lovedByMe: json.flag('lovedByMe'),
        replyCount: json.intOr('replyCount'),
        targetType: json.strOrNull('targetType'),
        targetId: json.strOrNull('targetId'),
      );

  Review copyWith({int? loveCount, bool? lovedByMe, int? replyCount}) => Review(
        id: id,
        rating: rating,
        reviewerName: reviewerName,
        reviewerUserId: reviewerUserId,
        reviewerBlueBadge: reviewerBlueBadge,
        comment: comment,
        date: date,
        createdAt: createdAt,
        loveCount: loveCount ?? this.loveCount,
        lovedByMe: lovedByMe ?? this.lovedByMe,
        replyCount: replyCount ?? this.replyCount,
        targetType: targetType,
        targetId: targetId,
      );
}

class ReviewReply {
  const ReviewReply({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.userBlueBadge = false,
    this.replyText,
    this.date,
    this.createdAt,
  });

  final int id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final bool userBlueBadge;
  final String? replyText;
  final String? date;
  final DateTime? createdAt;

  factory ReviewReply.fromJson(Map<String, dynamic> json) => ReviewReply(
        id: json.intOr('id'),
        userId: json.str('userId'),
        userName: json.str('userName'),
        userPhotoUrl: json.strOrNull('userPhotoUrl'),
        userBlueBadge: json.flag('userBlueBadge'),
        replyText: json.strOrNull('replyText'),
        date: json.strOrNull('date'),
        createdAt: json.date('createdAt'),
      );
}

class Conversation {
  const Conversation({
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
    this.otherUserBlueBadge = false,
    this.lastMessageAt,
    this.lastMessageBody,
    this.unreadCount = 0,
  });

  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final bool otherUserBlueBadge;
  final DateTime? lastMessageAt;
  final String? lastMessageBody;
  final int unreadCount;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        conversationId: json.str('conversationId'),
        otherUserId: json.str('otherUserId'),
        otherUserName: json.str('otherUserName'),
        otherUserPhotoUrl: json.strOrNull('otherUserPhotoUrl'),
        otherUserBlueBadge: json.flag('otherUserBlueBadge'),
        lastMessageAt: json.date('lastMessageAt'),
        lastMessageBody: json.strOrNull('lastMessageBody'),
        unreadCount: json.intOr('unreadCount'),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    this.createdAt,
    this.pending = false,
  });

  final int id;
  final String senderId;
  final String body;
  final DateTime? createdAt;

  /// True while an optimistic message is still on its way to the server.
  final bool pending;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json.intOr('id'),
        senderId: json.str('senderId'),
        body: json.str('body'),
        createdAt: json.date('createdAt'),
      );
}

class ChatPartner {
  const ChatPartner({
    required this.id,
    required this.name,
    this.photoUrl,
    this.chatEnabled = true,
    this.blueBadge = false,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final bool chatEnabled;
  final bool blueBadge;

  factory ChatPartner.fromJson(Map<String, dynamic> json) => ChatPartner(
        id: json.str('id'),
        name: json.str('name'),
        photoUrl: json.strOrNull('photoUrl'),
        chatEnabled: json.flag('chatEnabled', fallback: true),
        blueBadge: json.flag('blueBadge'),
      );
}

class ChatThread {
  const ChatThread({
    this.otherUser,
    this.messages = const [],
    this.blockedByMe = false,
    this.blockedMe = false,
  });

  final ChatPartner? otherUser;
  final List<ChatMessage> messages;

  /// Either side of a block stops the conversation in both directions.
  final bool blockedByMe;
  final bool blockedMe;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final other = json.mapOrNull('otherUser');
    return ChatThread(
      otherUser: other == null ? null : ChatPartner.fromJson(other),
      messages: json.mapList('messages').map(ChatMessage.fromJson).toList(),
      blockedByMe: json.flag('blockedByMe'),
      blockedMe: json.flag('blockedMe'),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.link,
    this.createdAt,
    this.read = false,
  });

  final int id;
  final String title;
  final String? body;
  final String? link;
  final DateTime? createdAt;
  final bool read;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json.intOr('id'),
        title: json.str('title'),
        body: json.strOrNull('body'),
        link: json.strOrNull('link'),
        createdAt: json.date('createdAt'),
        read: json.flag('read'),
      );

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        link: link,
        createdAt: createdAt,
        read: read ?? this.read,
      );
}

class SavedItem {
  const SavedItem({
    required this.targetType,
    required this.targetId,
    this.title,
    this.subtitle,
  });

  final String targetType;
  final String targetId;
  final String? title;
  final String? subtitle;

  factory SavedItem.fromJson(Map<String, dynamic> json) => SavedItem(
        targetType: json.str('targetType'),
        targetId: json.str('targetId'),
        title: json.strOrNull('title'),
        subtitle: json.strOrNull('subtitle'),
      );

  String get typeLabel {
    switch (targetType) {
      case 'service':
        return 'Service';
      case 'donor':
        return 'Blood donor';
      case 'marketplace_listing':
        return 'Marketplace';
      case 'biodata':
        return 'Matrimony';
      default:
        return targetType;
    }
  }
}
