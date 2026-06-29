import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../domain/entities/chat.dart';
import '../providers/chat_provider.dart';
import '../widgets/offline_banner.dart';

/// Screen listing all conversation threads.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final authState = ref.watch(authProvider);
    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        body: Center(child: Text('Please log in.')),
      );
    }

    final currentUid = authState.user.id;
    final chatsAsync = ref.watch(chatsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: false,
        actions: <Widget>[
          // Total unread messages badge indicator in app bar
          ref.watch(totalUnreadCountProvider).maybeWhen(
                data: (int count) => count > 0
                    ? Container(
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count unread',
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: chatsAsync.when(
              data: (List<Chat> chats) {
                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: colorScheme.primary.withAlpha(128),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: textTheme.titleMedium?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: chats.length,
                  separatorBuilder: (BuildContext context, int index) => Divider(
                    color: Colors.grey.withAlpha(25),
                    height: 1,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final chat = chats[index];
                    final peerName = _getPeerDisplayName(chat, currentUid);
                    final isTyping = chat.typingUsers.any((String uid) => uid != currentUid);
                    final unreadCount = chat.unreadCounts[currentUid] ?? 0;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withAlpha(38),
                        foregroundColor: colorScheme.primary,
                        radius: 26,
                        child: Text(
                          chat.isGroup
                              ? (chat.title?.isNotEmpty == true ? chat.title![0].toUpperCase() : 'G')
                              : (peerName.isNotEmpty ? peerName[0].toUpperCase() : 'U'),
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              chat.isGroup ? (chat.title ?? 'Unnamed Group') : peerName,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat.lastMessageTime != null)
                            Text(
                              _formatTime(chat.lastMessageTime!),
                              style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                        ],
                      ),
                      subtitle: Row(
                        children: <Widget>[
                          Expanded(
                            child: isTyping
                                ? Text(
                                    'typing...',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.secondary,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : Text(
                                    chat.lastMessageText ?? 'No messages yet',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: unreadCount > 0 ? Colors.white : Colors.grey,
                                      fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        context.go('/chats/room', extra: chat);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stack) => Center(
                child: Text(
                  'Error loading chats: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPeerDisplayName(Chat chat, String currentUid) {
    if (chat.isGroup) return chat.title ?? 'Group Chat';
    final peerId = chat.participants.firstWhere(
      (String p) => p != currentUid,
      orElse: () => '',
    );
    if (peerId == 'john_uid') return 'John Doe';
    if (peerId == 'admin_uid') return 'Admin User';
    return 'User ($peerId)';
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
