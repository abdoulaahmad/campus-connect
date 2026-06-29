import 'package:flutter/material.dart';
import '../../domain/entities/message.dart';

/// A micro-widget representing a message's delivery and read lifecycle status.
///
/// **Visual mapping:**
/// - `sending` → Single grey tick (semi-transparent)
/// - `sent` → Single clear grey tick
/// - `delivered` → Double grey ticks
/// - `read` → Double blue ticks
/// - `failed` → Red warning error outline icon
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({required this.status, super.key});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return switch (status) {
      MessageStatus.sending => Icon(
          Icons.check,
          color: Colors.grey.withAlpha(128),
          size: 14,
        ),
      MessageStatus.sent => const Icon(
          Icons.check,
          color: Colors.grey,
          size: 14,
        ),
      MessageStatus.delivered => const Icon(
          Icons.done_all,
          color: Colors.grey,
          size: 14,
        ),
      MessageStatus.read => Icon(
          Icons.done_all,
          color: colorScheme.secondary, // Theme secondary is #00B0FF (blue)
          size: 14,
        ),
      MessageStatus.failed => const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 14,
        ),
    };
  }
}
