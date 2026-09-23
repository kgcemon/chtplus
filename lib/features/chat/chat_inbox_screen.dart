import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../models/engagement.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';

class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowNotice());
  }

  /// The website shows a one-time notice explaining that messages are kept only
  /// for a limited time; the app does the same.
  Future<void> _maybeShowNotice() async {
    if (Prefs.instance.getBool(PrefKeys.chatNoticeSeen)) return;
    final settings = await ref.read(chatSettingsProvider.future);
    if (settings.noticeSeen) {
      await Prefs.instance.setBool(PrefKeys.chatNoticeSeen, true);
      return;
    }
    if (!mounted) return;

    await AppDialogs.confirm(
      context,
      title: 'About messaging',
      message:
          'Messages on CHT Plus are kept for a limited time and are removed automatically afterwards. '
          'Never share passwords, OTP codes or payment details in chat.',
      confirmLabel: 'Got it',
      cancelLabel: 'Close',
    );
    await Prefs.instance.setBool(PrefKeys.chatNoticeSeen, true);
    try {
      await ref.read(chatRepositoryProvider).updateSettings(noticeSeen: true);
    } on ApiException {
      // Saving the acknowledgement is best-effort.
    }
  }

  Future<void> _toggleChat(bool enabled) async {
    try {
      await ref.read(chatRepositoryProvider).updateSettings(chatEnabled: enabled);
      ref.invalidate(chatSettingsProvider);
      if (mounted) {
        AppSnackbar.success(
          context,
          enabled ? 'Messaging turned on.' : 'Messaging turned off.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(chatInboxProvider);
    final settings = ref.watch(chatSettingsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'toggle' && settings != null) {
                _toggleChat(!settings.chatEnabled);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      settings?.chatEnabled == false
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.do_not_disturb_on_outlined,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      settings?.chatEnabled == false
                          ? 'Turn messaging on'
                          : 'Turn messaging off',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (settings?.chatEnabled == false)
            Container(
              width: double.infinity,
              color: AppColors.amber.withValues(alpha: 0.12),
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
              child: Row(
                children: [
                  const Icon(Icons.do_not_disturb_on_outlined,
                      size: 17, color: Color(0xFF8A5A00)),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Messaging is off. Others cannot start a chat with you.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF6B4600)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _toggleChat(true),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Turn on'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(chatInboxProvider);
                ref.invalidate(chatUnreadCountProvider);
                await ref.read(chatInboxProvider.future);
              },
              child: inbox.when(
                loading: () => const AppLoader(),
                error: (error, _) => ListView(
                  children: [
                    const SizedBox(height: 70),
                    ErrorView(
                      message: '$error',
                      onRetry: () => ref.invalidate(chatInboxProvider),
                    ),
                  ],
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No messages yet',
                          message:
                              'Start a conversation from a seller\'s advert or someone\'s profile and it will appear here.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                    itemBuilder: (context, index) =>
                        _ConversationTile(conversation: items[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = conversation.unreadCount > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Avatar(
        url: conversation.otherUserPhotoUrl,
        name: conversation.otherUserName,
        size: 48,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              conversation.otherUserName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          VerifiedBadge(active: conversation.otherUserBlueBadge, size: 14),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          conversation.lastMessageBody ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: unread ? AppColors.text : AppColors.textSecondary,
            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Fmt.messageStamp(conversation.lastMessageAt),
            style: TextStyle(
              fontSize: 11,
              color: unread ? AppColors.forest : AppColors.textSecondary,
              fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          if (unread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${conversation.unreadCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            const SizedBox(height: 18),
        ],
      ),
      onTap: () async {
        await context.push(
          '/chat/${conversation.conversationId}'
          '?name=${Uri.encodeComponent(conversation.otherUserName)}',
        );
        ref.invalidate(chatInboxProvider);
        ref.invalidate(chatUnreadCountProvider);
      },
    );
  }
}
