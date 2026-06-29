import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/failures/chat_failure.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_status_icon.dart';
import '../widgets/offline_banner.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/services/sync_worker.dart';

/// Screen displaying the active message thread room.
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({required this.chat, super.key});

  final Chat chat;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isMeTyping = false;

  @override
  void initState() {
    super.initState();
    // Mark chat as read on screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatActionsProvider).markAsRead(chatId: widget.chat.id);
    });
  }

  @override
  void dispose() {
    // Reset typing status on exit
    if (_isMeTyping) {
      ref.read(chatActionsProvider).setTyping(chatId: widget.chat.id, isTyping: false);
    }
    _typingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      if (!_isMeTyping) {
        _isMeTyping = true;
        ref.read(chatActionsProvider).setTyping(chatId: widget.chat.id, isTyping: true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _isMeTyping = false);
          ref.read(chatActionsProvider).setTyping(chatId: widget.chat.id, isTyping: false);
        }
      });
    } else {
      if (_isMeTyping) {
        setState(() => _isMeTyping = false);
        ref.read(chatActionsProvider).setTyping(chatId: widget.chat.id, isTyping: false);
      }
      _typingTimer?.cancel();
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    _onTextChanged('');

    final result = await ref.read(chatActionsProvider).sendMessage(
          chatId: widget.chat.id,
          content: text,
        );

    // Scroll to bottom
    _scrollToBottom();

    switch (result) {
      case ChatSuccess():
        break;
      case ChatFailedResult(:final failure):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send: $failure')),
          );
        }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showEditMessageDialog(Message message) {
    final controller = TextEditingController(text: message.content);
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: controller,
            maxLines: null,
            autofocus: true,
            style: textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Enter new content...',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
              onPressed: () async {
                final newContent = controller.text.trim();
                if (newContent.isEmpty || newContent == message.content) {
                  Navigator.of(context).pop();
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(context).pop();

                final result = await ref.read(chatActionsProvider).editMessage(
                      chatId: widget.chat.id,
                      message: message,
                      newContent: newContent,
                    );

                switch (result) {
                  case ChatSuccess():
                    break;
                  case ChatFailedResult(:final failure):
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          failure is MessageEditExpiredFailure
                              ? 'Edit expired! Messages can only be edited within 120 seconds.'
                              : 'Failed to edit message: $failure',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final authState = ref.watch(authProvider);
    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        body: Center(child: Text('Access Denied')),
      );
    }

    final currentUid = authState.user.id;
    final messagesAsync = ref.watch(chatRoomMessagesProvider(widget.chat.id));
    final typingAsync = ref.watch(chatRoomTypingUsersProvider(widget.chat.id));

    // Peer user name check
    final peerName = widget.chat.isGroup
        ? (widget.chat.title ?? 'Group Chat')
        : (widget.chat.participants.firstWhere((p) => p != currentUid, orElse: () => '') == 'john_uid'
            ? 'John Doe'
            : 'Peer User');

    // Auto mark as read on new message receipt
    messagesAsync.whenData((_) {
      ref.read(chatActionsProvider).markAsRead(chatId: widget.chat.id);
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(peerName),
            // Show typing indicator in App Bar for groups, or bottom bubble
            typingAsync.maybeWhen(
              data: (List<String> typers) => typers.isNotEmpty
                  ? Text(
                      'typing...',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.secondary,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          ref.watch(syncWorkerStateProvider).maybeWhen(
                data: (state) => state.status == SyncWorkerStatus.syncing
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const OfflineBanner(),
          // Message list area
          Expanded(
            child: messagesAsync.when(
              data: (List<Message> messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Say hello!'));
                }

                // Push scroll to bottom after layout loads
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: GestureDetector(
                          onLongPress: () {
                            if (isMe && message.isEditable) {
                              _showEditMessageDialog(message);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? colorScheme.primary.withAlpha(230)
                                  : Colors.grey.shade900,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                                bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                              ),
                              border: Border.all(
                                color: isMe
                                    ? colorScheme.primary
                                    : Colors.grey.shade800,
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: <Widget>[
                                // Sender name for group chats
                                if (widget.chat.isGroup && !isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      message.senderName,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                // Content
                                Text(
                                  message.content,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Timestamp & status metadata row
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (message.isEdited)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Text(
                                          '(edited)',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: Colors.grey.shade400,
                                            fontStyle: FontStyle.italic,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      _formatTime(message.createdAt),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade400,
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (isMe) ...<Widget>[
                                      const SizedBox(width: 4),
                                      MessageStatusIcon(status: message.status),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace s) => Center(child: Text('Error loading messages: $e')),
            ),
          ),
          
          // Typing notifications row above keyboard area
          typingAsync.maybeWhen(
            data: (List<String> typers) {
              final peers = typers.where((String uid) => uid != currentUid).toList();
              if (peers.isEmpty) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                alignment: Alignment.centerLeft,
                child: Text(
                  peers.length == 1
                      ? '${peers.first == "john_uid" ? "John Doe" : "Someone"} is typing...'
                      : 'Multiple users are typing...',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Message Input Field Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(76),
              border: const Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onChanged: _onTextChanged,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      style: textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: colorScheme.primary),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
