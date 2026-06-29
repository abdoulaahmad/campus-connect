import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/app.dart';
import 'package:campus_connect/core/providers/core_providers.dart';
import 'package:campus_connect/features/auth/domain/entities/user.dart';
import 'package:campus_connect/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:campus_connect/features/messaging/domain/entities/chat.dart';
import 'package:campus_connect/features/messaging/domain/repositories/i_chat_repository.dart';

// Synchronous stubs to isolate widget smoke test from timers and channels
class StubAuthRepository extends Fake implements IAuthRepository {
  @override
  Future<User?> getCurrentUser() async => null;
}

class StubChatRepository extends Fake implements IChatRepository {
  @override
  Stream<List<Chat>> streamChats() => Stream<List<Chat>>.value(const <Chat>[]);

  @override
  Stream<int> streamTotalUnreadCount() => Stream<int>.value(0);
}

void main() {
  testWidgets('Sprint 1: App renders without errors', (WidgetTester tester) async {
    final stubAuth = StubAuthRepository();
    final stubChat = StubChatRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appReadyProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(stubAuth),
          chatRepositoryProvider.overrideWithValue(stubChat),
        ],
        child: const CampusConnectApp(),
      ),
    );

    // Settle any pending initialization or stream timers from mock repositories
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
