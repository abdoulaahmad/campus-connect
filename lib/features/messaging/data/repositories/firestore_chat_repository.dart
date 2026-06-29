import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/failures/chat_failure.dart';
import '../../domain/repositories/i_chat_repository.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// Production Firestore repository implementation of [IChatRepository].
///
/// Uses Cloud Firestore native SDK and batching to guarantee consistency.
class FirestoreChatRepository implements IChatRepository {
  FirestoreChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Stream<List<Chat>> streamChats() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      return Stream.value(const <Chat>[]);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  @override
  Stream<List<Message>> streamMessages(String chatId) {
    final currentUid = _auth.currentUser?.uid;
    
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snapshot) {
      final List<Message> messages = snapshot.docs.map((doc) {
        return MessageModel.fromMap(doc.id, doc.data());
      }).toList();

      // Set delivered state in the background for incoming messages
      if (currentUid != null) {
        _markMessagesAsDelivered(chatId, messages, currentUid);
      }

      return messages;
    });
  }

  void _markMessagesAsDelivered(String chatId, List<Message> messages, String currentUid) {
    final WriteBatch batch = _firestore.batch();
    bool hasUpdates = false;

    for (final message in messages) {
      if (message.senderId != currentUid && message.status == MessageStatus.sent) {
        final docRef = _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(message.id);
        batch.update(docRef, <String, dynamic>{'status': MessageStatus.delivered.name});
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      batch.commit().catchError((Object e) {
        debugPrint('[FirestoreChatRepository] Error marking messages as delivered: $e');
      });
    }
  }

  @override
  Future<ChatResult<void>> sendMessage(String chatId, Message message) async {
    try {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid == null) {
        return const ChatFailedResult(PermissionDeniedFailure());
      }

      final chatRef = _firestore.collection('chats').doc(chatId);
      final messageRef = chatRef.collection('messages').doc(message.id);

      await _firestore.runTransaction((transaction) async {
        final chatSnapshot = await transaction.get(chatRef);
        if (!chatSnapshot.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            message: 'Chat room does not exist.',
          );
        }

        final participants = List<String>.from(chatSnapshot.data()?['participants'] as List? ?? <dynamic>[]);
        final unreadCounts = Map<String, dynamic>.from(chatSnapshot.data()?['unread_counts'] as Map? ?? <dynamic, dynamic>{});

        // Increment unread count for other participants
        for (final pId in participants) {
          if (pId != message.senderId) {
            final currentVal = unreadCounts[pId] ?? 0;
            unreadCounts[pId] = (currentVal as int) + 1;
          }
        }

        // 1. Write the message document
        transaction.set(
          messageRef,
          MessageModel(
            id: message.id,
            senderId: message.senderId,
            senderName: message.senderName,
            content: message.content,
            createdAt: message.createdAt,
            status: MessageStatus.sent, // Transition from sending to sent
          ).toMap(),
        );

        // 2. Update the parent chat preview metadata
        transaction.update(chatRef, <String, dynamic>{
          'last_message_text': message.content,
          'last_message_sender_id': message.senderId,
          'last_message_time': Timestamp.fromDate(message.createdAt),
          'updated_at': FieldValue.serverTimestamp(),
          'unread_counts': unreadCounts,
        });
      });

      return const ChatSuccess<void>(null);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const ChatFailedResult(PermissionDeniedFailure());
      }
      return ChatFailedResult(MessageSendFailure(e.message));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  @override
  Future<ChatResult<void>> editMessage(String chatId, String messageId, String newContent) async {
    try {
      final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
      final chatRef = _firestore.collection('chats').doc(chatId);

      await _firestore.runTransaction((transaction) async {
        final messageDoc = await transaction.get(messageRef);
        if (!messageDoc.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            message: 'Message not found.',
          );
        }

        final message = MessageModel.fromMap(messageDoc.id, messageDoc.data()!);
        if (!message.isEditable) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'invalid-argument',
            message: 'Edit window expired.',
          );
        }

        final now = DateTime.now().toUtc();

        // 1. Update the message document
        transaction.update(messageRef, <String, dynamic>{
          'content': newContent,
          'edited_at': Timestamp.fromDate(now),
        });

        // 2. If it was the last message, update the chat preview
        final chatDoc = await transaction.get(chatRef);
        if (chatDoc.exists) {
          final lastSenderId = chatDoc.data()?['last_message_sender_id'] as String?;
          final lastTime = chatDoc.data()?['last_message_time'] as Timestamp?;
          
          if (lastSenderId == message.senderId &&
              lastTime != null &&
              lastTime.toDate().toUtc().isAtSameMomentAs(message.createdAt)) {
            transaction.update(chatRef, <String, dynamic>{
              'last_message_text': newContent,
            });
          }
        }
      });

      return const ChatSuccess<void>(null);
    } on FirebaseException catch (e) {
      if (e.message != null && e.message!.contains('Edit window expired')) {
        return const ChatFailedResult(MessageEditExpiredFailure());
      }
      if (e.code == 'permission-denied') {
        return const ChatFailedResult(PermissionDeniedFailure());
      }
      return ChatFailedResult(MessageSendFailure(e.message));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  @override
  Future<ChatResult<void>> setTyping(String chatId, bool isTyping) async {
    try {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid == null) {
        return const ChatFailedResult(PermissionDeniedFailure());
      }

      final typingRef = _firestore.collection('chats').doc(chatId).collection('typing').doc(currentUid);
      
      await typingRef.set(<String, dynamic>{
        'is_typing': isTyping,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return const ChatSuccess<void>(null);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const ChatFailedResult(PermissionDeniedFailure());
      }
      return ChatFailedResult(MessageSendFailure(e.message));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  @override
  Stream<List<String>> streamTypingUsers(String chatId) {
    final currentUid = _auth.currentUser?.uid;
    
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .where('is_typing', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now().toUtc();
      final List<String> typers = <String>[];
      
      for (final doc in snapshot.docs) {
        final uid = doc.id;
        if (uid == currentUid) continue;

        final data = doc.data();
        final updatedAt = ChatModel.parseTimestamp(data['updated_at']);

        // Stale checks: Typing updates must be within 15 seconds to be considered active
        if (now.difference(updatedAt).inSeconds <= 15) {
          typers.add(uid);
        }
      }
      return typers;
    });
  }

  @override
  Future<ChatResult<void>> markAsRead(String chatId) async {
    try {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid == null) {
        return const ChatFailedResult(PermissionDeniedFailure());
      }

      final batch = _firestore.batch();

      // 1. Update member last_read_at
      final memberRef = _firestore.collection('chats').doc(chatId).collection('members').doc(currentUid);
      batch.set(memberRef, <String, dynamic>{
        'last_read_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Reset unread counts on parent document
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.set(chatRef, <String, dynamic>{
        'unread_counts': <String, dynamic>{
          currentUid: 0,
        }
      }, SetOptions(merge: true));

      await batch.commit();

      // 3. Mark all messages from other users in this chat room as read in the background
      _markIncomingMessagesAsRead(chatId, currentUid);

      return const ChatSuccess<void>(null);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const ChatFailedResult(PermissionDeniedFailure());
      }
      return ChatFailedResult(MessageSendFailure(e.message));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  Future<void> _markIncomingMessagesAsRead(String chatId, String currentUid) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('sender_id', isNotEqualTo: currentUid)
          .get();

      final WriteBatch batch = _firestore.batch();
      bool hasUpdates = false;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        if (status != MessageStatus.read.name) {
          batch.update(doc.reference, <String, dynamic>{'status': MessageStatus.read.name});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[FirestoreChatRepository] Error background-marking messages read: $e');
    }
  }

  @override
  Stream<int> streamTotalUnreadCount() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      return Stream.value(0);
    }

    return streamChats().map((chats) {
      return chats.fold<int>(0, (total, chat) {
        return total + (chat.unreadCounts[currentUid] ?? 0);
      });
    });
  }
}
