import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DbService {
  DbService._internal();

  static final DbService instance = DbService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'paluwagan_pro.db');

    return openDatabase(
      dbPath,
      version: 13, // Increment version for deleted profile support
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedInitialData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _upgradeToV2(db);
        if (oldVersion < 3) await _upgradeToV3(db);
        if (oldVersion < 4) await _upgradeToV4(db);
        if (oldVersion < 5) await _upgradeToV5(db);
        if (oldVersion < 6) await _upgradeToV6(db);
        if (oldVersion < 7) await _upgradeToV7(db);
        if (oldVersion < 8) await _upgradeToV8(db);
        if (oldVersion < 9) await _upgradeToV9(db);
        if (oldVersion < 10) await _upgradeToV10(db);
        if (oldVersion < 11) await _upgradeToV11(db);
        if (oldVersion < 12) await _upgradeToV12(db);
        if (oldVersion < 13) await _upgradeToV13(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        address TEXT NOT NULL,
        age INTEGER NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        id_front_path TEXT NOT NULL,
        id_back_path TEXT NOT NULL,
        profile_picture TEXT,
        bio TEXT,
        phone_number TEXT,
        gcash_name TEXT,
        gcash_number TEXT,
        urcode_path TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');

    // Groups table
    await db.execute('''
      CREATE TABLE groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        total_pot REAL NOT NULL,
        contribution REAL NOT NULL,
        frequency TEXT NOT NULL,
        max_members INTEGER NOT NULL,
        current_members INTEGER NOT NULL,
        next_payout_date TEXT NOT NULL,
        created_by TEXT NOT NULL,
        join_code TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL,
        current_round INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        group_status TEXT DEFAULT "pending",
        FOREIGN KEY (created_by) REFERENCES users (id)
      );
    ''');

    // Group members table
    await db.execute('''
      CREATE TABLE group_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        joined_at TEXT NOT NULL,
        paid_contributions INTEGER NOT NULL,
        received_payouts INTEGER NOT NULL,
        rotation_order INTEGER NOT NULL,
        profile_picture TEXT,
        FOREIGN KEY (group_id) REFERENCES groups (id),
        FOREIGN KEY (user_id) REFERENCES users (id),
        UNIQUE(group_id, user_id)
      );
    ''');

    // Contributions table
    await db.execute('''
      CREATE TABLE contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        amount REAL NOT NULL,
        round INTEGER NOT NULL,
        status TEXT NOT NULL,
        due_date TEXT NOT NULL,
        paid_at TEXT,
        recipient_id TEXT,
        FOREIGN KEY (group_id) REFERENCES groups (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      );
    ''');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        round INTEGER NOT NULL,
        date TEXT NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      );
    ''');

    // Group chat table
    await db.execute('''
      CREATE TABLE group_chat (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      );
    ''');

    // Notifications table
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        group_id INTEGER,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        details TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (group_id) REFERENCES groups (id)
      );
    ''');

    // Payment proofs table (NEW)
    await db.execute('''
      CREATE TABLE payment_proofs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contribution_id INTEGER NOT NULL,
        group_id INTEGER NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        recipient_id TEXT NOT NULL,
        recipient_name TEXT NOT NULL,
        round INTEGER NOT NULL,
        gcash_name TEXT NOT NULL,
        gcash_number TEXT NOT NULL,
        transaction_no TEXT NOT NULL,
        screenshot_path TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL,
        submitted_at TEXT NOT NULL,
        verified_at TEXT,
        verified_by_id TEXT,
        rejection_reason TEXT,
        FOREIGN KEY (contribution_id) REFERENCES contributions (id),
        FOREIGN KEY (group_id) REFERENCES groups (id),
        FOREIGN KEY (sender_id) REFERENCES users (id),
        FOREIGN KEY (recipient_id) REFERENCES users (id)
      );
    ''');

    // Round rotations table (NEW)
    await db.execute('''
      CREATE TABLE round_rotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        round INTEGER NOT NULL,
        payout_date TEXT NOT NULL,
        recipient_id TEXT NOT NULL,
        recipient_name TEXT NOT NULL,
        status TEXT NOT NULL,
        completed_at TEXT,
        total_collected REAL,
        FOREIGN KEY (group_id) REFERENCES groups (id),
        FOREIGN KEY (recipient_id) REFERENCES users (id),
        UNIQUE(group_id, round)
      );
    ''');
  }

  Future<void> _upgradeToV2(Database db) async {
    // Add new columns to users table
    try {
      await db.execute('ALTER TABLE users ADD COLUMN profile_picture TEXT;');
    } catch (e) {
      print('profile_picture column migration note: $e');
    }
    try {
      await db.execute('ALTER TABLE users ADD COLUMN bio TEXT;');
    } catch (e) {
      print('bio column migration note: $e');
    }
    try {
      await db.execute('ALTER TABLE users ADD COLUMN phone_number TEXT;');
    } catch (e) {
      print('phone_number column migration note: $e');
    }
  }

  Future<void> _upgradeToV3(Database db) async {
    // Add notifications table
    try {
      await db.execute('''
        CREATE TABLE notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          type TEXT NOT NULL,
          group_id INTEGER,
          is_read INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          details TEXT,
          FOREIGN KEY (user_id) REFERENCES users (id),
          FOREIGN KEY (group_id) REFERENCES groups (id)
        );
      ''');
    } catch (e) {
      print('notifications table migration note: $e');
    }
  }

  Future<void> _upgradeToV4(Database db) async {
    // Add total_pot column to groups table if it doesn't exist
    try {
      await db.execute(
        'ALTER TABLE groups ADD COLUMN total_pot REAL DEFAULT 0.0;',
      );
    } catch (e) {
      print('total_pot column migration note: $e');
    }
  }

  Future<void> _upgradeToV5(Database db) async {
    // Add missing columns to groups table if they don't exist
    try {
      await db.execute(
        'ALTER TABLE groups ADD COLUMN max_members INTEGER DEFAULT 5;',
      );
    } catch (e) {
      print('max_members column migration note: $e');
    }
    try {
      await db.execute(
        'ALTER TABLE groups ADD COLUMN current_members INTEGER DEFAULT 1;',
      );
    } catch (e) {
      print('current_members column migration note: $e');
    }
    try {
      await db.execute(
        'ALTER TABLE groups ADD COLUMN current_round INTEGER DEFAULT 1;',
      );
    } catch (e) {
      print('current_round column migration note: $e');
    }
  }

  Future<void> _upgradeToV6(Database db) async {
    // Add all remaining missing columns to groups table
    final List<String> columns = [
      'created_by',
      'join_code',
      'status',
      'next_payout_date',
      'contribution',
      'frequency',
      'created_at',
    ];

    for (final column in columns) {
      try {
        late String alterStatement;
        switch (column) {
          case 'created_by':
            alterStatement =
                'ALTER TABLE groups ADD COLUMN created_by INTEGER DEFAULT 0;';
            break;
          case 'join_code':
            alterStatement =
                'ALTER TABLE groups ADD COLUMN join_code TEXT DEFAULT "DEFAULT";';
            break;
          case 'status':
            alterStatement =
                'ALTER TABLE groups ADD COLUMN status TEXT DEFAULT "active";';
            break;
          case 'next_payout_date':
            alterStatement =
                'ALTER TABLE groups ADD COLUMN next_payout_date TEXT DEFAULT "2026-04-13";';
            break;
          case 'contribution':
            alterStatement =
                'ALTER TABLE groups ADD COLUMN contribution REAL DEFAULT 0.0;';
            break;
          case 'frequency':
            alterStatement =
                'ALTER TABLE groups ADD COLUMN frequency TEXT DEFAULT "Monthly";';
            break;
          case 'created_at':
            alterStatement =
                'ALTER TABLE groups ADD COLUMN created_at TEXT DEFAULT "2026-03-13";';
            break;
          default:
            continue;
        }
        await db.execute(alterStatement);
        print('Added $column column to groups table');
      } catch (e) {
        print('$column column migration note: $e');
      }
    }
  }

  Future<void> _upgradeToV7(Database db) async {
    // Add group_status column to groups table
    try {
      await db.execute(
        'ALTER TABLE groups ADD COLUMN group_status TEXT DEFAULT "pending";',
      );
      print('Added group_status column to groups table');
    } catch (e) {
      print('group_status column migration note: $e');
    }

    // Create payment_proofs table
    try {
      await db.execute('''
        CREATE TABLE payment_proofs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contribution_id INTEGER NOT NULL,
          group_id INTEGER NOT NULL,
          sender_id INTEGER NOT NULL,
          sender_name TEXT NOT NULL,
          recipient_id INTEGER NOT NULL,
          recipient_name TEXT NOT NULL,
          round INTEGER NOT NULL,
          gcash_name TEXT NOT NULL,
          gcash_number TEXT NOT NULL,
          transaction_no TEXT NOT NULL,
          screenshot_path TEXT NOT NULL,
          amount REAL NOT NULL,
          status TEXT NOT NULL,
          submitted_at TEXT NOT NULL,
          verified_at TEXT,
          verified_by_id INTEGER,
          rejection_reason TEXT,
          FOREIGN KEY (contribution_id) REFERENCES contributions (id),
          FOREIGN KEY (group_id) REFERENCES groups (id),
          FOREIGN KEY (sender_id) REFERENCES users (id),
          FOREIGN KEY (recipient_id) REFERENCES users (id)
        );
      ''');
      print('Created payment_proofs table');
    } catch (e) {
      print('payment_proofs table migration note: $e');
    }

    // Create round_rotations table
    try {
      await db.execute('''
        CREATE TABLE round_rotations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          group_id INTEGER NOT NULL,
          round INTEGER NOT NULL,
          payout_date TEXT NOT NULL,
          recipient_id INTEGER NOT NULL,
          recipient_name TEXT NOT NULL,
          status TEXT NOT NULL,
          completed_at TEXT,
          total_collected REAL,
          FOREIGN KEY (group_id) REFERENCES groups (id),
          FOREIGN KEY (recipient_id) REFERENCES users (id),
          UNIQUE(group_id, round)
        );
      ''');
      print('Created round_rotations table');
    } catch (e) {
      print('round_rotations table migration note: $e');
    }
  }

  Future<void> _upgradeToV8(Database db) async {
    // Add GCash fields to users table
    try {
      await db.execute('ALTER TABLE users ADD COLUMN gcash_name TEXT;');
      print('Added gcash_name column to users table');
    } catch (e) {
      print('gcash_name column migration note: $e');
    }

    try {
      await db.execute('ALTER TABLE users ADD COLUMN gcash_number TEXT;');
      print('Added gcash_number column to users table');
    } catch (e) {
      print('gcash_number column migration note: $e');
    }

    try {
      await db.execute('ALTER TABLE users ADD COLUMN urcode_path TEXT;');
      print('Added urcode_path column to users table');
    } catch (e) {
      print('urcode_path column migration note: $e');
    }
  }

  Future<void> _upgradeToV9(Database db) async {
    // Remove father_name and mother_name columns by recreating the users table
    try {
      // Check if columns exist before trying to remove them
      final columns = await db.rawQuery("PRAGMA table_info(users)");
      final columnNames = columns.map((col) => col['name'].toString()).toList();

      if (columnNames.contains('father_name') ||
          columnNames.contains('mother_name')) {
        print('Migrating users table to remove old columns...');

        // Create a backup table with old data
        await db.execute('''
          CREATE TABLE users_backup AS 
          SELECT id, full_name, address, age, email, password, 
                 id_front_path, id_back_path, profile_picture, 
                 bio, phone_number, gcash_name, gcash_number, urcode_path, created_at 
          FROM users
        ''');

        // Drop the old users table
        await db.execute('DROP TABLE users');

        // Create new users table with correct schema
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT NOT NULL,
            address TEXT NOT NULL,
            age INTEGER NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            id_front_path TEXT NOT NULL,
            id_back_path TEXT NOT NULL,
            profile_picture TEXT,
            bio TEXT,
            phone_number TEXT,
            gcash_name TEXT,
            gcash_number TEXT,
            urcode_path TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        // Restore data from backup
        await db.execute('''
          INSERT INTO users 
          SELECT id, full_name, address, age, email, password, 
                 id_front_path, id_back_path, profile_picture, 
                 bio, phone_number, gcash_name, gcash_number, urcode_path, created_at 
          FROM users_backup
        ''');

        // Drop backup table
        await db.execute('DROP TABLE users_backup');

        print('Successfully migrated users table');
      }
    } catch (e) {
      print('Error in V9 migration: $e');
    }
  }

  Future<void> _upgradeToV10(Database db) async {
    print('Migrating to version 10: Converting IDs to TEXT');
    // For a real app with existing data, we would:
    // 1. Rename old tables to backup
    // 2. Create new tables with TEXT IDs
    // 3. Copy data while casting IDs to String
    // Since this is a transition phase, we'll recreate the schema for clean start
    // or manually alter if only few tables.
    // For simplicity and safety in this transition, we recreate:
    await db.execute('DROP TABLE IF EXISTS round_rotations');
    await db.execute('DROP TABLE IF EXISTS payment_proofs');
    await db.execute('DROP TABLE IF EXISTS notifications');
    await db.execute('DROP TABLE IF EXISTS group_chat');
    await db.execute('DROP TABLE IF EXISTS transactions');
    await db.execute('DROP TABLE IF EXISTS contributions');
    await db.execute('DROP TABLE IF EXISTS group_members');
    await db.execute('DROP TABLE IF EXISTS groups');
    await db.execute('DROP TABLE IF EXISTS users');
    
    await _createSchema(db);
  }

  Future<void> _upgradeToV11(Database db) async {
    try {
      await db.execute('ALTER TABLE contributions ADD COLUMN recipient_id TEXT;');
      print('Added recipient_id column to contributions table');
    } catch (e) {
      print('recipient_id column migration note: $e');
    }
  }

  Future<void> _upgradeToV12(Database db) async {
    try {
      await db.execute('ALTER TABLE group_members ADD COLUMN profile_picture TEXT;');
      print('Added profile_picture column to group_members table');
    } catch (e) {
      print('profile_picture column migration note: $e');
    }
  }

  Future<void> _upgradeToV13(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE users ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;',
      );
      print('Added is_deleted column to users table');
    } catch (e) {
      print('is_deleted column migration note: $e');
    }
  }

  Future<void> _seedInitialData(Database db) async {
    // We'll add initial data if needed
  }
}
