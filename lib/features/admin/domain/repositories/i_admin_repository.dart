import '../../../auth/domain/entities/user.dart';
import '../entities/admin_event.dart';
import '../entities/admin_announcement.dart';
import '../failures/admin_failure.dart';

abstract class IAdminRepository {
  Future<AdminResult<List<User>>> getUsers();
  Future<AdminResult<void>> updateUserRole(String userId, String role);
  
  Future<AdminResult<List<AdminEvent>>> getEvents();
  Future<AdminResult<void>> createEvent(AdminEvent event);
  
  Future<AdminResult<List<AdminAnnouncement>>> getAnnouncements();
  Future<AdminResult<void>> createAnnouncement(AdminAnnouncement announcement);
}
