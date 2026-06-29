import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Allows injecting/overriding a custom or mock database for testing.
  void setDatabaseForTesting(Database db) {
    _database = db;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'campus_connect.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table 1 — cached_chats
    await db.execute('''
      CREATE TABLE cached_chats (
        id                     TEXT PRIMARY KEY,
        title                  TEXT,
        is_group               INTEGER NOT NULL,
        updated_at             INTEGER NOT NULL,
        participants           TEXT NOT NULL,
        last_message_text      TEXT,
        last_message_sender_id TEXT,
        last_message_time      INTEGER,
        unread_counts          TEXT NOT NULL,
        typing_users           TEXT NOT NULL
      )
    ''');

    // Table 2 — cached_messages
    await db.execute('''
      CREATE TABLE cached_messages (
        id          TEXT PRIMARY KEY,
        chat_id     TEXT NOT NULL,
        sender_id   TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        content     TEXT NOT NULL,
        status      TEXT NOT NULL,
        created_at  INTEGER NOT NULL,
        edited_at   INTEGER,
        synced_at   INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_cached_messages_chat_id ON cached_messages(chat_id, created_at DESC)
    ''');

    // Table 3 — sync_queue
    await db.execute('''
      CREATE TABLE sync_queue (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        command_type  TEXT NOT NULL,
        chat_id       TEXT NOT NULL,
        message_id    TEXT,
        payload       TEXT NOT NULL,
        created_at    INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error    TEXT
      )
    ''');

    // Create Map Tables for Sprint 6
    await _createMapTables(db);
    await _seedBuildings(db);

    // Create Admin Tables for Sprint 7
    await _createAdminTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMapTables(db);
      await _seedBuildings(db);
    }
    if (oldVersion < 3) {
      await _createAdminTables(db);
    }
  }

  Future<void> _createAdminTables(Database db) async {
    await db.execute('''
      CREATE TABLE local_users (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        email       TEXT NOT NULL,
        role        TEXT NOT NULL,
        schedule    TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE local_events (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        description TEXT NOT NULL,
        venue       TEXT NOT NULL,
        timestamp   INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE local_announcements (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        content     TEXT NOT NULL,
        timestamp   INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createMapTables(Database db) async {
    await db.execute('''
      CREATE TABLE local_buildings (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        description TEXT NOT NULL,
        category    TEXT NOT NULL,
        center_lat  REAL NOT NULL,
        center_lng  REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE local_building_points (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        building_id TEXT NOT NULL,
        sequence    INTEGER NOT NULL,
        lat         REAL NOT NULL,
        lng         REAL NOT NULL,
        FOREIGN KEY(building_id) REFERENCES local_buildings(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _seedBuildings(Database db) async {
    final countResult = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM local_buildings')
    );
    if (countResult != null && countResult > 0) return;

    final centers = [
      [11.7136, 9.3419, "Senate Building", "Administrative headquarters and Vice Chancellor's office of FUD.", "administration"],
      [11.7145, 9.3430, "FUD Library", "The main university library containing research resources and digital hubs.", "academic"],
      [11.7139, 9.3443, "Convocation Arena", "Open-air square for convocations, events, and speech broadcasts.", "recreation"],
      [11.7154, 9.3413, "Faculty of Science", "Departments of Computer Science, Physics, Chemistry, and Mathematics.", "academic"],
      [11.7163, 9.3399, "Faculty of Agriculture", "FUD agricultural research departments and laboratories.", "academic"],
      [11.7124, 9.3390, "Faculty of Arts and Social Sciences", "Departments of Economics, Sociology, and Political Science.", "academic"],
      [11.7181, 9.3379, "College of Health Sciences", "Academic building for clinical and health sciences departments.", "academic"],
      [11.7111, 9.3406, "General Lecture Theatre", "Main lecture hall for general studies and matriculation ceremonies.", "academic"],
      [11.7120, 9.3440, "Student Center", "Hub for student union services, dining, and shops.", "recreation"],
      [11.7107, 9.3426, "University Clinic", "The primary campus health center and emergency first-aid clinic.", "security"],
      [11.7071, 9.3456, "Main Gate", "The primary northern gate connecting the FUD campus to the main highway.", "security"],
      [11.7194, 9.3363, "Second Gate (Aba)", "Alternative campus access gate located near the agricultural fields.", "security"],
      [11.7091, 9.3373, "Male Hostel Complex", "Undergraduate male student residence halls.", "hostel"],
      [11.7100, 9.3359, "Female Hostel Complex", "Undergraduate female student residence halls.", "hostel"],
      [11.7170, 9.3453, "Sports Complex", "Main campus athletic track, soccer field, and gymnasium.", "recreation"]
    ];

    await db.transaction((txn) async {
      for (int i = 0; i < centers.length; i++) {
        final id = 'B${(i + 1).toString().padLeft(3, '0')}';
        final double centerLat = centers[i][0] as double;
        final double centerLng = centers[i][1] as double;
        final String name = centers[i][2] as String;
        final String desc = centers[i][3] as String;
        final String category = centers[i][4] as String;

        await txn.insert('local_buildings', {
          'id': id,
          'name': name,
          'description': desc,
          'category': category,
          'center_lat': centerLat,
          'center_lng': centerLng,
        });

        // Insert 4 points forming a small polygon around the center
        final List<List<double>> polygonPoints = [
          [centerLat - 0.00015, centerLng - 0.00015],
          [centerLat - 0.00015, centerLng + 0.00015],
          [centerLat + 0.00015, centerLng + 0.00015],
          [centerLat + 0.00015, centerLng - 0.00015],
        ];

        for (int seq = 0; seq < polygonPoints.length; seq++) {
          await txn.insert('local_building_points', {
            'building_id': id,
            'sequence': seq,
            'lat': polygonPoints[seq][0],
            'lng': polygonPoints[seq][1],
          });
        }
      }
    });
  }
}
