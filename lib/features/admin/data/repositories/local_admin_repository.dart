import '../../../../core/database/app_database.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/admin_event.dart';
import '../../domain/entities/admin_announcement.dart';
import '../../domain/failures/admin_failure.dart';
import '../../domain/repositories/i_admin_repository.dart';

class LocalAdminRepository implements IAdminRepository {
  final AppDatabase _dbHelper;

  LocalAdminRepository({required AppDatabase dbHelper}) : _dbHelper = dbHelper;

  @override
  Future<AdminResult<List<User>>> getUsers() async {
    try {
      final db = await _dbHelper.database;
      var results = await db.query('local_users');
      
      if (results.isEmpty) {
        final mockUsers = [
          {'id': 'u1', 'name': 'Abdullahi Abba Ahmad', 'email': 'abdullahi@fud.edu.ng', 'role': 'admin', 'schedule': '{}'},
          {'id': 'u2', 'name': 'Balarabe Bello', 'email': 'balarabe@fud.edu.ng', 'role': 'student', 'schedule': '{}'},
          {'id': 'u3', 'name': 'Fatima Musa', 'email': 'fatima@fud.edu.ng', 'role': 'student', 'schedule': '{}'},
        ];
        for (final u in mockUsers) {
          await db.insert('local_users', u);
        }
        results = await db.query('local_users');
      }

      final users = results.map((row) {
        return User(
          id: row['id'] as String,
          name: row['name'] as String,
          email: row['email'] as String,
          role: row['role'] as String,
        );
      }).toList();
      return AdminSuccess(users);
    } catch (e) {
      return AdminFailed(AdminOperationFailed(e.toString()));
    }
  }

  @override
  Future<AdminResult<void>> updateUserRole(String userId, String role) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'local_users',
        {'role': role},
        where: 'id = ?',
        whereArgs: [userId],
      );
      return const AdminSuccess(null);
    } catch (e) {
      return AdminFailed(AdminOperationFailed(e.toString()));
    }
  }

  @override
  Future<AdminResult<List<AdminEvent>>> getEvents() async {
    try {
      final db = await _dbHelper.database;
      var results = await db.query('local_events', orderBy: 'timestamp DESC');
      
      if (results.isEmpty) {
        // Seed default event
        final now = DateTime.now();
        await db.insert('local_events', {
          'id': 'e1',
          'title': 'FUD Hackathon 2026',
          'description': 'A 48-hour hackathon hosted at the Faculty of Science computing labs.',
          'venue': 'Faculty of Science Lab',
          'timestamp': now.add(const Duration(days: 5)).millisecondsSinceEpoch,
        });
        results = await db.query('local_events', orderBy: 'timestamp DESC');
      }

      final events = results.map((row) {
        return AdminEvent(
          id: row['id'] as String,
          title: row['title'] as String,
          description: row['description'] as String,
          venue: row['venue'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        );
      }).toList();
      return AdminSuccess(events);
    } catch (e) {
      return AdminFailed(AdminOperationFailed(e.toString()));
    }
  }

  @override
  Future<AdminResult<void>> createEvent(AdminEvent event) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('local_events', {
        'id': event.id,
        'title': event.title,
        'description': event.description,
        'venue': event.venue,
        'timestamp': event.timestamp.millisecondsSinceEpoch,
      });
      return const AdminSuccess(null);
    } catch (e) {
      return AdminFailed(AdminOperationFailed(e.toString()));
    }
  }

  @override
  Future<AdminResult<List<AdminAnnouncement>>> getAnnouncements() async {
    try {
      final db = await _dbHelper.database;
      var results = await db.query('local_announcements', orderBy: 'timestamp DESC');
      
      if (results.isEmpty) {
        // Seed default announcement
        final now = DateTime.now();
        await db.insert('local_announcements', {
          'id': 'a1',
          'title': 'Semester Registration Announcement',
          'content': 'Registration for the 2026 academic session closes on Friday. All students are advised to complete their payments.',
          'timestamp': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        });
        results = await db.query('local_announcements', orderBy: 'timestamp DESC');
      }

      final announcements = results.map((row) {
        return AdminAnnouncement(
          id: row['id'] as String,
          title: row['title'] as String,
          content: row['content'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        );
      }).toList();
      return AdminSuccess(announcements);
    } catch (e) {
      return AdminFailed(AdminOperationFailed(e.toString()));
    }
  }

  @override
  Future<AdminResult<void>> createAnnouncement(AdminAnnouncement announcement) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('local_announcements', {
        'id': announcement.id,
        'title': announcement.title,
        'content': announcement.content,
        'timestamp': announcement.timestamp.millisecondsSinceEpoch,
      });
      return const AdminSuccess(null);
    } catch (e) {
      return AdminFailed(AdminOperationFailed(e.toString()));
    }
  }
}
