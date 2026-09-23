import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/common.dart';
import '../../models/engagement.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';

/// One conversation. New messages are picked up by polling with the `after`
/// parameter the API already supports, so only the delta is transferred.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId, this.title});

  final String conversationId;
  final String? title;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<ChatMessage> _messages = [];
  ChatPartner? _partner;
  Timer? _poll;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Polling in the background would waste battery and data for nothing.
    if (state == AppLifecycleState.resumed) {
      _refreshNew();
      _startPolling();
    } else {
      _poll?.cancel();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refreshNew());
  }

  Future<void> _load() async {
    try {
      final thread =
          await ref.read(chatRepositoryProvider).messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages = thread.messages;
        _partner = thread.otherUser;
        _loading = false;
        _error = null;
      });
      _jumpToBottom();
      ref.invalidate(chatUnreadCountProvider);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _refreshNew() async {
    if (_messages.isEmpty) {
      await _load();
      return;
    }
    final lastId = _messages.where((m) => !m.pending).lastOrNull?.id;
    if (lastId == null) return;
    try {
      final thread = await ref
          .read(chatRepositoryProvider)
          .messages(widget.conversationId, after: lastId);
      if (!mounted || thread.messages.isEmpty) return;
      setState(() {
        _messages = [..._messages, ...thread.messages];
        _partner = thread.otherUser ?? _partner;
      });
      _jumpToBottom();
      ref.invalidate(chatUnreadCountProvider);
    } on ApiException {
      // A failed poll is silent; the next tick tries again.
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    final me = ref.read(currentUserProvider);
    if (me == null) return;

    // Show the message immediately, then replace it with the saved one.
    final optimistic = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      senderId: me.id,
      body: text,
      createdAt: DateTime.now(),
      pending: true,
    );
    setState(() {
      _messages = [..._messages, optimistic];
      _sending = true;
    });
    _input.clear();
    _jumpToBottom();

    try {
      final saved =
          await ref.read(chatRepositoryProvider).send(widget.conversationId, text);
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages.where((m) => m.id != optimistic.id),
          saved,
        ];
      });
      ref.invalidate(chatInboxProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _messages = _messages.where((m) => m.id != optimistic.id).toList());
      _input.text = text;
      AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final name = _partner?.name ?? widget.title ?? 'Chat';
    final disabled = _partner != null && !_partner!.chatEnabled;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _partner == null ? null : () => context.push('/u/${_partner!.id}'),
          child: Row(
            children: [
              Avatar(url: _partner?.photoUrl, name: name, size: 34),
              const SizedBox(width: 10),
              Flexible(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    VerifiedBadge(active: _partner?.blueBadge ?? false, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const AppLoader()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _messages.isEmpty
                        ? const EmptyState(
                            icon: Icons.waving_hand_outlined,
                            title: 'Say hello',
                            message:
                                'No messages here yet. Messages are removed automatically after a while.',
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final mine = message.senderId == me?.id;
                              final previous =
                                  index == 0 ? null : _messages[index - 1];
                              final showDay = previous == null ||
                                  !_sameDay(previous.createdAt, message.createdAt);
                              return Column(
                                children: [
                                  if (showDay)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Text(
                                        Fmt.date(message.createdAt),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  _Bubble(message: message, mine: mine),
                                ],
                              );
                            },
                          ),
          ),
          if (disabled)
            Container(
              width: double.infinity,
              color: AppColors.bg,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'This person has turned messaging off, so you cannot reply here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            _Composer(
              controller: _input,
              sending: _sending,
              onSend: _send,
            ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.forest : AppColors.surface,
          border: mine ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.body,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: mine ? Colors.white : AppColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Fmt.time(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: mine ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
                if (message.pending) ...[
                  const SizedBox(width: 4),
                  const SizedBox(
                    width: 9,
                    height: 9,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Write a message…',
                    counterText: '',
                    fillColor: AppColors.bg,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: sending ? null : onSend,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  minimumSize: const Size(46, 46),
                ),
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 19, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _LastOrNull<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
