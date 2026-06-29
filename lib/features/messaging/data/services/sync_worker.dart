import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/message.dart';
import '../../domain/failures/chat_failure.dart';
import '../../domain/repositories/i_chat_repository.dart';
import '../datasources/local_message_datasource.dart';
import '../../../../core/services/connectivity_service.dart';

enum SyncWorkerStatus { idle, syncing, syncFailed }

class SyncWorkerState {
  const SyncWorkerState({
    required this.status,
    required this.pendingCount,
    this.lastFailure,
  });

  final SyncWorkerStatus status;
  final int pendingCount;
  final ChatFailure? lastFailure;

  SyncWorkerState copyWith({
    SyncWorkerStatus? status,
    int? pendingCount,
    ChatFailure? lastFailure,
  }) {
    return SyncWorkerState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastFailure: lastFailure ?? this.lastFailure,
    );
  }
}

class SyncWorker {
  SyncWorker({
    required this.inner,
    required this.localDatasource,
    required this.connectivity,
  }) {
    _init();
  }

  final IChatRepository inner;
  final LocalMessageDatasource localDatasource;
  final ConnectivityService connectivity;

  final _stateController = StreamController<SyncWorkerState>.broadcast();
  StreamSubscription? _connSub;
  bool _isReplaying = false;

  SyncWorkerState _state = const SyncWorkerState(
    status: SyncWorkerStatus.idle,
    pendingCount: 0,
  );

  Stream<SyncWorkerState> get stateStream => _stateController.stream;
  SyncWorkerState get currentState => _state;

  void _updateState(SyncWorkerState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void _init() async {
    // Initial fetch of pending commands
    final pending = await localDatasource.getPendingCommands();
    _updateState(_state.copyWith(pendingCount: pending.length));

    // Listen to network changes to trigger replay
    _connSub = connectivity.isOnline$.listen((isOnline) {
      if (isOnline) {
        _replayQueue();
      }
    });
  }

  Future<void> _replayQueue() async {
    if (_isReplaying) return;
    _isReplaying = true;

    try {
      var pending = await localDatasource.getPendingCommands();
      if (pending.isEmpty) {
        _updateState(_state.copyWith(status: SyncWorkerStatus.idle, pendingCount: 0));
        _isReplaying = false;
        return;
      }

      _updateState(_state.copyWith(status: SyncWorkerStatus.syncing, pendingCount: pending.length));

      for (final cmd in pending) {
        // If device goes offline during replay, pause
        final isOnline = await connectivity.isOnlineNow;
        if (!isOnline) break;

        ChatResult<void>? result;

        try {
          if (cmd.commandType == 'sendMessage') {
            final payload = cmd.payload;
            final message = Message(
              id: payload['id'] as String,
              senderId: payload['senderId'] as String,
              senderName: payload['senderName'] as String,
              content: payload['content'] as String,
              createdAt: DateTime.parse(payload['createdAt'] as String).toUtc(),
              status: MessageStatus.sent,
            );
            result = await inner.sendMessage(cmd.chatId, message);
          } else if (cmd.commandType == 'editMessage') {
            final payload = cmd.payload;
            final messageId = payload['messageId'] as String;
            final newContent = payload['newContent'] as String;
            result = await inner.editMessage(cmd.chatId, messageId, newContent);
          } else if (cmd.commandType == 'markAsRead') {
            result = await inner.markAsRead(cmd.chatId);
          }
        } catch (e) {
          result = ChatFailedResult(MessageSendFailure(e.toString()));
        }

        if (result is ChatSuccess) {
          await localDatasource.markCommandSuccess(cmd.id!);
          // Update status locally to sent
          if (cmd.commandType == 'sendMessage' && cmd.messageId != null) {
            await localDatasource.updateMessageStatus(cmd.messageId!, MessageStatus.sent);
          }
        } else if (result is ChatFailedResult) {
          final failure = result.failure;
          final isPermanent = failure is MessageEditExpiredFailure || failure is PermissionDeniedFailure;

          if (isPermanent || cmd.attemptCount >= 2) {
            // Drop permanently failing commands
            await localDatasource.removeCommand(cmd.id!);
            
            if (cmd.commandType == 'sendMessage' && cmd.messageId != null) {
              await localDatasource.updateMessageStatus(cmd.messageId!, MessageStatus.failed);
            }

            _updateState(_state.copyWith(
              status: SyncWorkerStatus.syncFailed,
              lastFailure: SyncFailedFailure(cmd.commandType, cmd.messageId ?? ''),
            ));
          } else {
            // Log attempt failure and retry later
            await localDatasource.incrementCommandAttempt(cmd.id!, failure.toString());
          }
        }
      }

      final remaining = await localDatasource.getPendingCommands();
      _updateState(_state.copyWith(
        status: remaining.isEmpty ? SyncWorkerStatus.idle : _state.status,
        pendingCount: remaining.length,
      ));
    } catch (e) {
      debugPrint('[SyncWorker] Error during queue replay: $e');
    } finally {
      _isReplaying = false;
    }
  }

  void dispose() {
    _connSub?.cancel();
    _stateController.close();
  }
}
